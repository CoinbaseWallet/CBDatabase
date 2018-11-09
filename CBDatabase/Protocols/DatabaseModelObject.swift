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
public protocol DatabaseModelObject: Codable, Hashable {
    /// The entity name of the managed object. By default this returns the same name of the struct.
    static var entityName: String { get }
    
    /// Column that uniquely represents this object in CoreData. Used to find the object for things like `addOrUpdate`.
    /// Defaults to "id"
    static var idColumnName: String { get }

    /// Unique string that represents this object
    var id: String { get }
}

extension DatabaseModelObject {
    static var idColumnName: String {
        return "id"
    }
    
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
    func configure(with managedObject: NSManagedObject) {
        assert(managedObject.entity.name == Self.entityName)
        guard
            managedObject.objectID.isTemporaryID || hasChange(from: managedObject)
        else { return }

        let mirror = Mirror(reflecting: self)

        for case let (key?, rawValue) in mirror.children {
            let adjustedValue = (rawValue as AnyObject) is NSNull ? nil : rawValue

            guard let value = adjustedValue else {
                managedObject.setValue(nil, forKey: key)
                continue
            }

            if let attributes = managedObject.entity.attributesByName[key],
                let attributeValueClassName = attributes.attributeValueClassName,
                let attributeValueClass = NSClassFromString(attributeValueClassName) as? DBDataTypeWrapper.Type {
                let wrappedValue = attributeValueClass.self.init(model: value)
                managedObject.setValue(wrappedValue, forKey: key)
                continue
            }

            managedObject.setValue(value, forKey: key)
        }
    }

    /// - Returns: A fetch request for all objects of this type.
    static func fetchRequest<T>() -> NSFetchRequest<T> {
        return NSFetchRequest(entityName: Self.entityName)
    }

    /// - Returns: A fetch request for an object with the given identifier.
    static func fetchRequest<T>(id: String) -> NSFetchRequest<T> {
        let fetchRequest: NSFetchRequest<T> = Self.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == [c] %@", Self.idColumnName, id)
        return fetchRequest
    }

    /// - Returns: A fetch request for this object.
    func fetchRequest<T>() -> NSFetchRequest<T> {
        return Self.fetchRequest(id: id)
    }

    // MARK: - Private

    private func hasChange(from managedObject: NSManagedObject) -> Bool {
        guard let model: Self = try? managedObject.modelObject() else { return true }

        let modelMirrorChildren = Mirror(reflecting: model).children.asDictionary
        let selfMirrorChildren = Mirror(reflecting: self).children.asDictionary

        guard modelMirrorChildren.count == selfMirrorChildren.count else { return true }

        for key in selfMirrorChildren.keys {
            let selfValue = selfMirrorChildren[key]
            let modelValue = modelMirrorChildren[key]
            let entityAttribute = managedObject.entity.attributesByName[key]
            let areValuesEqual = areEqual(lhs: selfValue, rhs: modelValue, entityAttribute: entityAttribute) == true

            if !areValuesEqual { return true }
        }

        return false
    }

    private func areEqual(lhs: Any?, rhs: Any?, entityAttribute: NSAttributeDescription?) -> Bool? {
        let lhsType = type(of: lhs)
        let rhsType = type(of: rhs)

        func isEqual<T: Equatable>(type _: T.Type, a: Any?, b: Any?) -> Bool? {
            guard let a = a as? T, let b = b as? T else { return nil }
            return a == b
        }

        // Check if we're comparing the same data type
        if lhsType != rhsType {
            return false
        }

        // Check nulls
        if lhs == nil && rhs == nil {
            return true
        }

        // Check if the property conforms to `DBDataTypeEquality`. If so, compare using protocol.
        guard let lhs = lhs, let rhs = rhs else { return false }

        if let lhsEquality = lhs as? DBDataTypeEquality, let rhsEquality = rhs as? DBDataTypeEquality {
            return lhsEquality.isEqual(to: rhsEquality)
        }

        // Check if the property conforms to `DBDataTypeWrapper`. If so, compare the internal model.
        guard
            let attributeValueClassName = entityAttribute?.attributeValueClassName,
            let attributeValueClass = NSClassFromString(attributeValueClassName) as? DBDataTypeWrapper.Type
        else {
            assertionFailure(
                """

                *******************************************************************************************
                Unsupported data type [\(lhsType)]. Create a class that conforms `DBDataTypeWrapper` or
                conform to DBDataTypeEquality if new type already subclasses `NSObject`
                *******************************************************************************************

                """
            )

            return false
        }

        if let lhsWrapper = attributeValueClass.self.init(model: lhs),
            let rhsWrapper = attributeValueClass.self.init(model: rhs) {
            return lhsWrapper.isEqual(to: rhsWrapper)
        }

        return false
    }
}
