// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import CoreData
import os.log
import RxSwift

final class CoreDataDiskStorage: DatabaseStorage {
    private static var docURL: URL? = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
    }()

    private let options: DiskDatabaseOptions
    private let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
    private let multiReadSingleWriteQueue = DispatchQueue(
        label: "CBDatabase.DiskStorage.multiWriteSingleReadQueue",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// CoreData's managed object context
    private(set) var context: NSManagedObjectContext

    /// Determine whether the database has been manually destroyed and should not be used anymore
    private(set) var isDestroyed: Bool = false

    init(options: DiskDatabaseOptions) throws {
        self.options = options
        context = try CoreDataDiskStorage.createManagedObjectContext(options: options)
    }

    /// Perform database operation in private concurrent queue.
    ///
    /// - Parameters:
    ///     - operation: Indicate the type of operation to execute
    ///     - work: closure called when performing a database operation
    ///
    /// - Returns: Single wrapping model(s) involved in the db operation
    func perform<T>(operation: DatabaseOperation, work: @escaping ((NSManagedObjectContext) throws -> T)) -> Single<T> {
        return Single.create { [weak self] single in
            guard let strongSelf = self, let context = self?.context else {
                single(.error(DatabaseError.unableToFindDatabaseContext))
                return Disposables.create()
            }

            let work = {
                context.performAndWait {
                    if strongSelf.isDestroyed {
                        return single(.error(DatabaseError.databaseDestroyed))
                    }

                    do {
                        let result = try work(context)
                        context.saveChangesIfNeeded()
                        single(.success(result))
                    } catch {
                        single(.error(error))
                    }
                }
            }

            switch operation {
            case .read:
                strongSelf.multiReadSingleWriteQueue.sync(execute: work)
            case .write:
                strongSelf.multiReadSingleWriteQueue.sync(flags: .barrier, execute: work)
            }

            return Disposables.create()
        }
        .subscribeOn(scheduler)
    }

    /// Delete sqlite file and mark it as destroyed. All read/write operations will fail
    func destroy() {
        multiReadSingleWriteQueue.sync(flags: .barrier) {
            if self.isDestroyed {
                return
            }

            self.isDestroyed = true
            self.deleteDatabaseFromDisk()
        }
    }

    /// Delete the current database sqlite file.
    func reset() throws {
        try multiReadSingleWriteQueue.sync(flags: .barrier) {
            if self.isDestroyed {
                return
            }

            self.deleteDatabaseFromDisk()
            self.context = try CoreDataDiskStorage.createManagedObjectContext(options: self.options)
        }
    }

    // MARK: Private helpers

    private func deleteDatabaseFromDisk() {
        let storeFile = "\(options.dbStorageFilename).sqlite"
        let storeSHMFile = "\(storeFile)-shm"
        let storeWALFile = "\(storeFile)-wal"
        let currentMigrationVersionFilename = options.currentMigrationVersionFilename

        [storeFile, storeSHMFile, storeWALFile, currentMigrationVersionFilename].forEach { filename in
            guard
                let fileURL = CoreDataDiskStorage.docURL?.appendingPathComponent(filename),
                FileManager.default.fileExists(atPath: fileURL.path)
            else { return }

            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func createManagedObjectContext(options: DiskDatabaseOptions) throws -> NSManagedObjectContext {
        guard let docURL = CoreDataDiskStorage.docURL else { throw DatabaseError.unableToSetupDatabase }

        if !FileManager.default.fileExists(atPath: docURL.absoluteString) {
            try FileManager.default.createDirectory(
                at: docURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let storeURL = docURL.appendingPathComponent("\(options.dbStorageFilename).sqlite")
        var previousManagedObjectModel: NSManagedObjectModel?
        let currentMigrationFilename = options.currentMigrationVersionFilename
        let currentVersion = currentMigrationVersion(filename: currentMigrationFilename)
        let managedObjectModels: [(String, NSManagedObjectModel)] = try options.versions.compactMap { version in
            let resource = "\(options.dbSchemaName).momd/\(version)"

            guard
                let versionURL = options.dataModelBundle.url(forResource: resource, withExtension: "mom"),
                let managedObjectModel = NSManagedObjectModel(contentsOf: versionURL)
            else {
                throw DatabaseError.unableToCreateManagedObjectModel
            }

            return (version, managedObjectModel)
        }

        let startIndex = managedObjectModels.firstIndex(where: { $0.0 == currentVersion }) ?? 0
        try managedObjectModels[startIndex...].forEach { versionName, mom1 in
            let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL
            )

            if
                let aMetadata = metadata,
                !mom1.isConfiguration(withName: nil, compatibleWithStoreMetadata: aMetadata),
                let mom0 = previousManagedObjectModel {
                let bundle = options.dataModelBundle
                try migrate(from: mom0, to: mom1, storeURL: storeURL, bundle: bundle)
            } else {
                try setup(managedObjectModel: mom1, storeURL: storeURL)
            }

            try setCurrentMigrationVersion(versionName, filename: currentMigrationFilename)
            previousManagedObjectModel = mom1
        }

        guard let recentManagedObjectModels = managedObjectModels.last?.1 else {
            throw DatabaseError.unableToSetupDatabase
        }

        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        let psc = try setup(managedObjectModel: recentManagedObjectModels, storeURL: storeURL)

        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.persistentStoreCoordinator = psc

        return managedObjectContext
    }

    private static func currentMigrationVersion(filename: String) -> String? {
        guard
            let fileURL = docURL?.appendingPathComponent(filename),
            FileManager.default.fileExists(atPath: fileURL.path),
            let version = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return nil }

        return version
    }

    private static func setCurrentMigrationVersion(_ versionName: String?, filename: String) throws {
        guard let fileURL = docURL?.appendingPathComponent(filename) else { throw DatabaseError.unableToSetupDatabase }

        if let version = versionName {
            return try version.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        try FileManager.default.removeItem(at: fileURL)
    }

    @discardableResult
    private static func setup(
        managedObjectModel: NSManagedObjectModel, storeURL: URL
    ) throws -> NSPersistentStoreCoordinator {
        let psc = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        try psc.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )

        return psc
    }

    @discardableResult
    private static func migrate(
        from source: NSManagedObjectModel,
        to destination: NSManagedObjectModel,
        storeURL: URL,
        bundle: Bundle
    ) throws -> NSPersistentStoreCoordinator {
        let manager = NSMigrationManager(sourceModel: source, destinationModel: destination)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let destStoreURL = tempDir.appendingPathComponent("\(UUID().uuidString).sqlite")
        let mapping = try NSMappingModel(from: [bundle], forSourceModel: source, destinationModel: destination) ??
            NSMappingModel.inferredMappingModel(forSourceModel: source, destinationModel: destination)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { _ = try? FileManager.default.removeItem(at: tempDir) }

        // run migrations
        try autoreleasepool {
            try manager.migrateStore(
                from: storeURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mapping,
                toDestinationURL: destStoreURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )
        }

        // Replace source store
        let psc = NSPersistentStoreCoordinator(managedObjectModel: destination)
        try psc.replacePersistentStore(
            at: storeURL,
            destinationOptions: nil,
            withPersistentStoreFrom: destStoreURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )

        return psc
    }
}
