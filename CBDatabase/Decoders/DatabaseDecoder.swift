// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData

final class DatabaseDecoder: Decoder {
    private let dictionary: [String: Any]

    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(dictionary: [String: Any]) {
        self.dictionary = dictionary
    }

    func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return KeyedDecodingContainer(DatabaseKeyedDecodingContainer(dictionary: dictionary))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }

    func decode<T: Decodable>(as type: T.Type) throws -> T {
        return try type.init(from: self)
    }
}
