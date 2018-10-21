// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import Foundation

/// Represents type of database storage
public enum DatabaseStorageType {
    /// Store data into local disk. URL used to specify file location. A default will be set if no value is supplied
    case sqlite(URL?)

    /// Store data in memory
    case memory
}
