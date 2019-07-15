// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import Foundation

/// Options for Coredata memory database
public struct MemoryDatabaseOptions {
    /// Name of the xcdatamodeld file to use
    public let dbSchemaName: String

    /// Bundle used to lookup xcdatamodeld file
    public let dataModelBundle: Bundle

    public init(dbSchemaName: String, dataModelBundle: Bundle) {
        self.dbSchemaName = dbSchemaName
        self.dataModelBundle = dataModelBundle
    }
}
