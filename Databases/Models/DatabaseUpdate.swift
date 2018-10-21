// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import Foundation

/// Represents a db update observed in `Database`
struct DatabaseUpdate<T> {
    /// Inserted models
    let insertedObjects: [T]

    /// Updated models
    let updatedObjects: [T]

    /// Deleted models
    let deletedObjects: [T]

    /// Refreshed models
    let refreshedObjects: [T]
}
