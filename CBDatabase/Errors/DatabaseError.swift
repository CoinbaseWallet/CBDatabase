// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// Represents Database Errors
public enum DatabaseError: Error {
    /// Error thrown when db unable to store model
    case unableToStoreModelObject

    /// Error thrown when database context is not found
    case unableToFindDatabaseContext

    /// Error thrown when an invalid model is encountered during observation
    case unableToObserveModel

    /// Error thrown whenever an add/update/query operation is fired when DB is in `destroyed` state
    case databaseDestroyed

    /// Thrown when managed object model cannot be created during DB setup
    case unableToCreateManagedObjectModel

    /// Thrown when database setup fails
    case unableToSetupDatabase
}
