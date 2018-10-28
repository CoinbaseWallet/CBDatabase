// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData

extension NSManagedObject {
    /// Converts model object to NSManagedObject
    func modelObject<T: DatabaseModelObject>() throws -> T {
        let encoded = self.encoded()
        let decoder = DatabaseDecoder(dictionary: encoded)

        return try decoder.decode(as: T.self)
    }

    // MARK: - Private helpers

    private func encoded() -> [String: Any] {
        let entity = self.entity
        var dictionary = [String: Any]()

        entity.attributesByName.forEach { attribute in
            let key = attribute.key

            guard let value = self.value(forKey: key) else { return }

            if attribute.value.attributeType == .booleanAttributeType, let value = value as? NSNumber {
                dictionary[key] = value.boolValue
                return
            } else if let wrapper = value as? DBDataTypeWrapper {
                dictionary[key] = wrapper.asModel.map { $0 }
                return
            }

            dictionary[key] = value
        }

        return dictionary
    }
}
