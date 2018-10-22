// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import Foundation

/// Represents Database Errors
public enum DatabaseError: Error {
    /// Error thrown when db unable to store model
    case unableToStoreModelObject

    /// Error thrown when database context is not found
    case unableToFindDatabaseContext

    /// Error thrown when an invalid model is encountered during observation
    case unableToObserveModel
}
