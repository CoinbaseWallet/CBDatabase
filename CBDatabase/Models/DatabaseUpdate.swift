// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// Represents a db update observed in `Database`
public struct DatabaseUpdate<T> {
    /// Inserted models
    public let insertedObjects: [T]

    /// Updated models
    public let updatedObjects: [T]

    /// Deleted models
    public let deletedObjects: [T]

    /// Refreshed models
    public let refreshedObjects: [T]
}
