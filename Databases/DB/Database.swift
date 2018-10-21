// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData
import RxSwift
import RxCocoa

public final class Database {
    private let concurrentDispatchQueueScheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
    private let disposeBag = DisposeBag()
    private let storage: DatabaseStorage
    private var transformers = [String: DatabaseTransformable.Type]()

    public init(type: DatabaseStorageType = .sqlite(nil), modelURL: URL, storeName: String = "DataStore") {
        storage = DatabaseStorage(storage: type, modelURL: modelURL, storeName: storeName)
    }

    /// Adds a new model to the database.
    ///
    /// - Parameter object: The model to add to the database.
    ///
    /// - Returns: A Single wrapping an optional model indicating whether the add succeeded.
    public func add<T: DatabaseModelObject>(_ model: T) -> Single<T?> {
        return add([model]).map { $0?.first }
    }

    /// Adds new models to the database.
    ///
    /// - Parameter objects: The models to add to the database.
    ///
    /// - Returns: A Single wrapping an optional list of models indicating whether the add succeeded.
    public func add<T: DatabaseModelObject>(_ models: [T]) -> Single<[T]?> {
        return storage
            .perform(operation: .write) { context -> [T] in
                for model in models {
                    let managedObject = try T.new(with: context)
                    model.configure(with: managedObject, transformers: self.transformers)
                }

                return models
            }
            .catchErrorJustReturn(nil)
    }

    /// Adds or update model.
    ///
    /// - Parameter objects: The model to add to the database.
    ///
    /// - Returns: A Single wrapping an optional  model indicating whether the add/update succeeded.
    public func addOrUpdate<T: DatabaseModelObject>(_ model: T) -> Single<T?> {
        return addOrUpdate([model]).map { $0?.first }
    }

    /// Adds or update models.
    ///
    /// - Parameter objects: The models to add to the database.
    ///
    /// - Returns: A Single wrapping an optional list of models indicating whether the add/update succeeded.
    public func addOrUpdate<T: DatabaseModelObject>(_ models: [T]) -> Single<[T]?> {
        return storage
            .perform(operation: .write) { context -> [T] in
                // check if model exists in database
                let ids = models.map { $0.id }
                let predicate = NSPredicate(format: "id in %@", ids)
                let managedObjectMap: [String: NSManagedObject] = try context
                    .fetch(entityName: T.entityName, predicate: predicate)
                    .reduce(into: [:]) { dict, managedObject in
                        guard let id = managedObject.value(forKey: "id") as? String else { return }
                        dict[id] = managedObject
                    }

                // insert or update accordingly
                try models.forEach { model in
                    let managedObject: NSManagedObject
                    if let object = managedObjectMap[model.id] {
                        managedObject = object
                    } else {
                        managedObject = try T.new(with: context)
                    }

                    model.configure(with: managedObject, transformers: self.transformers)
                }

                return models
            }
            .catchErrorJustReturn(nil)
    }

    /// Updates the object in the data store.
    ///
    /// - Parameter object: The object to update in the database.
    ///
    /// - Returns: A Single representing whether the update succeeded. Succeeds is false if the object is not already
    ///     in the database.
    public func update<T: DatabaseModelObject>(_ object: T) -> Single<T?> {
        return storage
            .perform(operation: .write) { context -> T? in
                if let managedObject = try context.fetch(T.self, identifier: object.id) {
                    object.configure(with: managedObject, transformers: self.transformers)
                    return object
                }

                return nil
            }
            .catchErrorJustReturn(nil)
    }

    /// Fetches objects from the data store.
    ///
    /// - Parameters:
    ///     - predicate: A predicate filtering the results of the fetch. If none is passed in all items of type T are
    ///         returned.
    ///     - sortDescriptors: Sort descriptors inidicating the order the items are reutrn in.
    ///
    /// - Returns: A Single wrapping the items returned by the fetch.
    public func fetch<T: DatabaseModelObject>(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = []
    ) -> Single<[T]> {
        return storage.perform(operation: .read) { context -> [T] in
            let items = try context.fetch(
                entityName: T.entityName,
                predicate: predicate,
                sortDescriptors: sortDescriptors
            )

            let modelItems: [T] = try items.map { try $0.modelObject(transformers: self.transformers) }

            return modelItems
        }
    }

    /// Counts total objects from the data store.
    ///
    /// - Parameters:
    ///     - predicate: A predicate filtering the results of the fetch. If none pased, all items are counted
    ///
    /// - Returns: A Single wrapping the items returned by the fetch.
    public func count<T: DatabaseModelObject>(for _: T.Type, predicate: NSPredicate? = nil) -> Single<Int> {
        return storage.perform(operation: .read) { context -> Int in
            try context.count(entityName: T.entityName, predicate: predicate)
        }
    }

    /// Fetches a single object from the data store.
    ///
    /// - Parameters:
    ///     - predicate: A predicate filtering the results of the fetch.
    ///
    /// - Returns: A Single wrapping the items returned by the fetch.
    public func fetchOne<T: DatabaseModelObject>(predicate: NSPredicate?) -> Single<T?> {
        return storage.perform(operation: .read) { context -> T? in
            let items = try context.fetch(entityName: T.entityName, predicate: predicate, sortDescriptors: [])
            guard let item = items.first else { return nil }
            return try item.modelObject(transformers: self.transformers)
        }
    }

    /// Deletes the object from the data store.
    ///
    /// - Parameters:
    ///     - type: The type of the object to be deleted.
    ///     - identifier: The identifier of the object to be deleted.
    ///
    /// - Returns: A Single wrapping a boolean indicating whether the delete succeeded.
    public func delete<T: DatabaseModelObject>(_ type: T.Type, identifier: String) -> Single<Bool> {
        return storage.perform(operation: .write) { context -> Bool in
            try context.delete(type, identifier: identifier)
        }
        .catchErrorJustReturn(false)
    }

    /// Deletes all objects of the given type.
    ///
    /// - Parameter type: The type of the objects to be deleted.
    /// - Returns: A Single wrapping a boolean indicating whether the delete succeeded.
    public func deleteAll<T: DatabaseModelObject>(of type: T.Type) -> Single<Bool> {
        return storage.perform(operation: .write) { context -> Bool in
            try context.deleteAll(type)
            return true
        }
        .catchErrorJustReturn(false)
    }

    /// Observe for a given model
    ///
    /// - Parameters:
    ///     - modelType: Filter observer by model type
    ///     - id:        Filter observer by model ID
    ///
    /// - Returns: Single wrapping the updated model or an error is thrown
    public func observe<T: DatabaseModelObject>(for _: T.Type, id: String) -> Observable<T> {
        return NotificationCenter.default.rx.notification(.NSManagedObjectContextDidSave)
            .observeOn(concurrentDispatchQueueScheduler)
            .map { notification -> T? in
                guard let userInfo = notification.userInfo else { return nil }
                let operations = [NSRefreshedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSInsertedObjectsKey]

                for operation in operations {
                    guard let objects = userInfo[operation] as? Set<NSManagedObject> else { continue }
                    return try objects.first {
                        $0.entity.name == T.entityName && ($0.value(forKey: "id") as? String) == id
                    }?.modelObject(transformers: self.transformers)
                }

                return nil
            }
            .filter { $0 != nil }
            .map { model -> T in
                assert(model != nil)
                guard let model = model else { throw DatabaseError.unableToObserveModel }
                return model
            }
    }

    /// Observe for a given model type
    ///
    /// - Parameters:
    ///     - modelType: Filter observer by model type
    ///
    /// - Returns: Single wrapping the updated model or an error is thrown
    public func observe<T: DatabaseModelObject>(for _: T.Type) -> Observable<DatabaseUpdate<T>> {
        return NotificationCenter.default.rx.notification(.NSManagedObjectContextDidSave)
            .observeOn(concurrentDispatchQueueScheduler)
            .map { notification -> DatabaseUpdate<T>? in
                guard
                    let userInfo = notification.userInfo,
                    let managedObjectContext = notification.object as? NSManagedObjectContext,
                    managedObjectContext === self.storage.context
                else {
                    return nil
                }

                let insertedObjectsSet = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
                let updatedObjectsSet = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
                let deletedObjectsSet = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
                let refreshedObjectsSet = userInfo[NSRefreshedObjectsKey] as? Set<NSManagedObject> ?? []

                let insertedObjects: [T] = try insertedObjectsSet
                    .filter { $0.entity.name == T.entityName }
                    .compactMap { try $0.modelObject(transformers: self.transformers) }

                let updatedObjects: [T] = try updatedObjectsSet
                    .filter { $0.entity.name == T.entityName }
                    .compactMap { try $0.modelObject(transformers: self.transformers) }

                let deletedObjects: [T] = try deletedObjectsSet
                    .filter { $0.entity.name == T.entityName }
                    .compactMap { try $0.modelObject(transformers: self.transformers) }

                let refreshedObjects: [T] = try refreshedObjectsSet
                    .filter { $0.entity.name == T.entityName }
                    .compactMap { try $0.modelObject(transformers: self.transformers) }

                if insertedObjects.isEmpty &&
                    updatedObjects.isEmpty &&
                    deletedObjects.isEmpty &&
                    refreshedObjects.isEmpty {
                    return nil
                }

                let update = DatabaseUpdate<T>(
                    insertedObjects: insertedObjects,
                    updatedObjects: updatedObjects,
                    deletedObjects: deletedObjects,
                    refreshedObjects: refreshedObjects
                )

                let pieces = [
                    "\(insertedObjects.count) insert(s)",
                    "\(updatedObjects.count) update(s)",
                    "\(deletedObjects.count) delete(s)",
                    "\(refreshedObjects.count) refresh(s)",
                ]

                print("[databases]: [\(T.entityName)] \(pieces.joined(separator: ", "))")

                return update
            }
            .filter { $0 != nil }
            .map { update -> DatabaseUpdate<T> in
                assert(update != nil)
                guard let update = update else { throw DatabaseError.unableToObserveModel }
                return update
            }
    }

    /// Register custom transformers
    ///
    /// - Parameters:
    ///     - transformer: DatabaseTransformer used to serialize/unserialize custom classes
    public func registerTransformer<T: DatabaseTransformable>(for transfomer: T.Type) {
        let key = "\(transfomer)"


        assert(transformers[key] == nil, "\(key) is already registered")

        transformers[key] = T.self

        let optionalType = "\(Mirror(reflecting: T?.self).subjectType)"
        if let optionalKey = optionalType.split(separator: ".").first {
            transformers[String(optionalKey)] = T.self
        }

    }
}
