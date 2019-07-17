// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import CoreData

/// Options for Coredata sqlite database
public struct DiskDatabaseOptions {
    /// Name of the xcdatamodeld file to use
    public let dbSchemaName: String

    /// Name of file where actual data will be stored
    public let dbStorageFilename: String

    /// Ordered list of xcdatamodel names. Primarily used to run progressive migrations. The last version in the
    /// list will be used as the final xcdatamodel.
    public let versions: [String]

    /// Bundle used to lookup xcdatamodeld file
    public let dataModelBundle: Bundle

    /// Filename where last executed version id is stored
    let currentMigrationVersionFilename: String

    public init(
        dbSchemaName: String,
        dbStorageFilename: String = "DataStore",
        versions: [String],
        dataModelBundle: Bundle
    ) throws {
        if versions.isEmpty {
            throw DatabaseError.missingManagedObjectModel
        }

        self.dbSchemaName = dbSchemaName
        self.dbStorageFilename = dbStorageFilename
        self.versions = versions
        self.dataModelBundle = dataModelBundle
        currentMigrationVersionFilename = "\(dbStorageFilename).migration"
    }
}
