// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

final class DatabaseKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    private let dictionary: [String: Any]

    var codingPath: [CodingKey] = []
    var allKeys: [Key] = []

    init(dictionary: [String: Any]) {
        self.dictionary = dictionary
    }

    func contains(_ key: Key) -> Bool {
        return dictionary[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        return dictionary[key.stringValue] == nil
    }

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        guard let value = dictionary[key.stringValue] as? Bool else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        guard let value = dictionary[key.stringValue] as? String else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        guard let value = dictionary[key.stringValue] as? Double else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        guard let value = dictionary[key.stringValue] as? Float else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        guard let value = dictionary[key.stringValue] as? Int else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let value = dictionary[key.stringValue] as? Int8 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let value = dictionary[key.stringValue] as? Int16 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let value = dictionary[key.stringValue] as? Int32 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let value = dictionary[key.stringValue] as? Int64 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        guard let value = dictionary[key.stringValue] as? UInt else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let value = dictionary[key.stringValue] as? UInt8 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let value = dictionary[key.stringValue] as? UInt16 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let value = dictionary[key.stringValue] as? UInt32 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let value = dictionary[key.stringValue] as? UInt64 else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
        guard let value = dictionary[key.stringValue] as? T else {
            throw DatabaseDecoderError.unableToDecodeModelProperty
        }

        return value
    }

    func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type,
        forKey _: Key
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }

    func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }

    func superDecoder() throws -> Decoder {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }

    func superDecoder(forKey _: Key) throws -> Decoder {
        throw DatabaseDecoderError.decoderFunctionNotImplemented
    }
}
