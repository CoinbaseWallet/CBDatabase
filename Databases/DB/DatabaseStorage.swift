// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData
import RxSwift

/// Database storage
final class DatabaseStorage {
    private let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
    private let multiReadSingleWriteQueue = DispatchQueue(
        label: "com.wallet.databases.multiWriteSingleReadQueue",
        qos: .userInitiated
    )

    /// CoreData's managed object context
    let context: NSManagedObjectContext

    init(storage: DatabaseStorageType, modelURL: URL, storeName: String) {
        context = DatabaseStorage.createManagedObjectContext(for: storage, modelURL: modelURL, storeName: storeName)
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

    // MARK: Private helpers

    private static func createManagedObjectContext(
        for storage: DatabaseStorageType,
        modelURL: URL,
        storeName: String
    ) -> NSManagedObjectContext {
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("Unable to setup database") }

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let storeType: String
        let storeURL: URL?
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        switch storage {
        case .memory:
            storeType = NSInMemoryStoreType
            storeURL = nil
        case let .sqlite(url):
            storeType = NSSQLiteStoreType

            if let url = url {
                storeURL = url
            } else if let docURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).last {
                if !FileManager.default.fileExists(atPath: docURL.absoluteString) {
                    try? FileManager.default.createDirectory(
                        at: docURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
                storeURL = docURL.appendingPathComponent("\(storeName).sqlite")
            } else {
                fatalError("Unable to setup database")
            }
        }

        do {
            managedObjectContext.persistentStoreCoordinator = psc
            try psc.addPersistentStore(ofType: storeType, configurationName: nil, at: storeURL, options: options)
        } catch let err {
            fatalError("Error setting up database: \(err)")
        }

        return managedObjectContext
    }
}
