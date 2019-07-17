// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import CoreData
import RxSwift

final class CoreDataMemoryStorage: DatabaseStorage {
    private let options: MemoryDatabaseOptions
    private let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
    private let multiReadSingleWriteQueue = DispatchQueue(
        label: "CBDatabase.MemoryStorage.multiWriteSingleReadQueue",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// CoreData's managed object context
    private(set) var context: NSManagedObjectContext

    /// Determine whether the database has been manually destroyed and should not be used anymore
    private(set) var isDestroyed: Bool = false

    init(options: MemoryDatabaseOptions) throws {
        self.options = options
        context = try CoreDataMemoryStorage.createManagedObjectContext(options: options)
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

    /// Delete sqlite file and marks it as destroyed. All read/write operations will fail
    func destroy() {
        multiReadSingleWriteQueue.sync(flags: .barrier) {
            if self.isDestroyed {
                return
            }

            self.isDestroyed = true
        }
    }

    /// Delete the current database sqlite file.
    func reset() throws {
        try multiReadSingleWriteQueue.sync(flags: .barrier) {
            if self.isDestroyed {
                return
            }

            self.context = try CoreDataMemoryStorage.createManagedObjectContext(options: self.options)
        }
    }

    // MARK: Private helpers

    private static func createManagedObjectContext(options: MemoryDatabaseOptions) throws -> NSManagedObjectContext {
        guard
            let momURL = options.dataModelBundle.url(forResource: options.dbSchemaName, withExtension: "momd"),
            let mom = NSManagedObjectModel(contentsOf: momURL)
        else {
            throw DatabaseError.unableToSetupDatabase
        }

        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.persistentStoreCoordinator = psc

        try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: options)

        return managedObjectContext
    }
}
