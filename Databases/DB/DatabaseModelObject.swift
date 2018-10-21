// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData

/// Structs that conform to the DatabaseModelObject protocol can be stored in the database.
///
/// # How to add a new model to the database:
///     1. Add a new entity to the Database.xcdatamodeld file.
///         - Add only attributes which can be encoded by JSONSerialization.
///         - Ensure Codegen is set to Manual/None and the class name field is left empty.
///     2. Create a new struct that conforms to DatabaseModelObject.
///         - Add the entity's attributes as ivars.
///         - If the entity name differs from the name of the struct, be sure to override entityName.
protocol DatabaseModelObject: Codable, Hashable {
    var id: String { get }
}

extension DatabaseModelObject {
    /// The entity name of the managed object. By default this returns the same name of the struct.
    static var entityName: String {
        return String(describing: Self.self)
    }

    /// Create a new managed object.
    ///
    /// - Parameter context: The context in which to insert the managed object.
    /// - Returns: The new managedObject.
    /// - Throws: An error will be thrown if the new managed object can't be initialized in the database.
    static func new(with context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let entity = NSEntityDescription.entity(forEntityName: self.entityName, in: context) else {
            throw DatabaseError.unableToStoreModelObject
        }

        return NSManagedObject(entity: entity, insertInto: context)
    }

    /// Configures the managed object. This method will set the values of the managed object to
    /// match those of the struct.
    ///
    /// - Parameter context: The managed object to configure.
    func configure(with managedObject: NSManagedObject, transformers: [String: DatabaseTransformable.Type]) {
        assert(managedObject.entity.name == Self.entityName)
        guard
            managedObject.objectID.isTemporaryID || hasChange(from: managedObject, transformers: transformers)
        else { return }

        let mirror = Mirror(reflecting: self)

        for case let (key?, value) in mirror.children {
            let typeKey = "\(Mirror(reflecting: value).subjectType)"
            var value = (value as AnyObject) is NSNull ? nil : value
            if let transformedValue = transformers[typeKey]?.toDatabase(value: value) {
                value = transformedValue
            }

            managedObject.setValue(value, forKey: key)
        }
    }

    /// - Returns: A fetch request for all objects of this type.
    static func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest(entityName: Self.entityName)
    }

    /// - Returns: A fetch request for an object with the given identifier.
    static func fetchRequest<T>(identifier: String) -> NSFetchRequest<T> {
        let fetchRequest: NSFetchRequest<T> = Self.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == [c] %@", identifier)
        return fetchRequest
    }

    /// - Returns: A fetch request for this object.
    func fetchRequest<T>() -> NSFetchRequest<T> {
        return Self.fetchRequest(identifier: id)
    }

    // MARK: - Private

    private func hasChange(
        from managedObject: NSManagedObject,
        transformers: [String: DatabaseTransformable.Type]
    ) -> Bool {
        guard let model: Self = try? managedObject.modelObject(transformers: transformers) else { return true }

        let modelMirrorChildren = Mirror(reflecting: model).children.asDictionary
        let selfMirrorChildren = Mirror(reflecting: self).children.asDictionary

        guard modelMirrorChildren.count == selfMirrorChildren.count else { return true }

        for key in selfMirrorChildren.keys {
            let selfValue = selfMirrorChildren[key]
            let modelValue = modelMirrorChildren[key]
            if areEqual(lhs: selfValue, rhs: modelValue, transformers: transformers) != true {
                return true
            }
        }

        return false
    }

    private func areEqual(lhs: Any?, rhs: Any?, transformers: [String: DatabaseTransformable.Type]) -> Bool? {
        let lhsType = type(of: lhs)
        let rhsType = type(of: rhs)

        if lhsType != rhsType {
            return false
        }

        func isEqual<T: Equatable>(type _: T.Type, a: Any?, b: Any?) -> Bool? {
            guard let a = a as? T, let b = b as? T else { return nil }

            return a == b
        }

        switch lhs {
        case nil:
            return rhs == nil
        case is Int, is Int?:
            return isEqual(type: Int.self, a: lhs, b: rhs)
        case is UInt, is UInt?:
            return isEqual(type: UInt.self, a: lhs, b: rhs)
        case is Int8, is Int8?:
            return isEqual(type: Int8.self, a: lhs, b: rhs)
        case is UInt8, is UInt8?:
            return isEqual(type: UInt8.self, a: lhs, b: rhs)
        case is Int16, is Int16?:
            return isEqual(type: Int16.self, a: lhs, b: rhs)
        case is UInt16, is UInt16?:
            return isEqual(type: UInt16.self, a: lhs, b: rhs)
        case is Int32, is Int32?:
            return isEqual(type: Int32.self, a: lhs, b: rhs)
        case is UInt32, is UInt32?:
            return isEqual(type: UInt32.self, a: lhs, b: rhs)
        case is Int64, is Int64?:
            return isEqual(type: Int64.self, a: lhs, b: rhs)
        case is UInt64, is UInt64?:
            return isEqual(type: UInt64.self, a: lhs, b: rhs)
        case is Decimal, is Decimal?:
            return isEqual(type: Decimal.self, a: lhs, b: rhs)
        case is Double, is Double?:
            return isEqual(type: Double.self, a: lhs, b: rhs)
        case is Float, is Float?:
            return isEqual(type: Float.self, a: lhs, b: rhs)
        case is String, is String?:
            return isEqual(type: String.self, a: lhs, b: rhs)
        case is Bool, is Bool?:
            return isEqual(type: Bool.self, a: lhs, b: rhs)
        case is Date, is Date?:
            return isEqual(type: Date.self, a: lhs, b: rhs)
        case is Data, is Data?:
            return isEqual(type: Data.self, a: lhs, b: rhs)
        case is UUID, is UUID?:
            return isEqual(type: UUID.self, a: lhs, b: rhs)
        case is URL, is URL?:
            return isEqual(type: URL.self, a: lhs, b: rhs)
        default:
            // Compare Transformable types
            if let lhs = lhs, let rhs = rhs {
                let lhsKeyType = "\(Mirror(reflecting: lhs).subjectType)"
                let rhsKeyType = "\(Mirror(reflecting: rhs).subjectType)"

                if lhsKeyType == rhsKeyType, let transformer = transformers[lhsKeyType] {
                    return transformer.areDatabaseEntriesEqual(lhs: lhs, rhs: rhs)
                }
            }

            assertionFailure("Unsupported CoreData type \(lhsType)")
            return nil
        }
    }
}
