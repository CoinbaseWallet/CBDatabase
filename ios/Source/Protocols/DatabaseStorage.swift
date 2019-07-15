// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import CoreData
import RxSwift

/// Represents database storage type
protocol DatabaseStorage {
    /// CoreData's managed object context
    var context: NSManagedObjectContext { get }

    /// Perform database operation in private concurrent queue.
    ///
    /// - Parameters:
    ///     - operation: Indicate the type of operation to execute
    ///     - work: closure called when performing a database operation
    ///
    /// - Returns: Single wrapping model(s) involved in the db operation
    func perform<T>(operation: DatabaseOperation, work: @escaping ((NSManagedObjectContext) throws -> T)) -> Single<T>

    /// Delete sqlite file and marks it as destroyed. All read/write operations will fail
    func destroy()

    /// Delete the current database sqlite file.
    func reset() throws
}
