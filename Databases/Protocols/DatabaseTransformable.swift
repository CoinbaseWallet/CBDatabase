// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import Foundation

/// CoreData requires `NSObject` for `Transformable` data type option. This protocol can be used to register
/// custom transformers
public protocol DatabaseTransformable {
    static func toDatabase(value: Any?) -> Any?
    static func fromDatabase(value: Any?) -> Any?

    static func areDatabaseEntriesEqual(lhs: Any?, rhs: Any?) -> Bool
}
