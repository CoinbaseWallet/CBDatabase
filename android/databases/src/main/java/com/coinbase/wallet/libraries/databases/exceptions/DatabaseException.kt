package com.coinbase.wallet.libraries.databases.exceptions

import java.lang.Exception

/**
 * Represents exceptions thrown by module
 */
sealed class DatabaseException(msg: String) : Exception(msg) {
    /**
     * Thrown if unable to find DAO for provided model
     */
    class MissingDao(clazz: Class<*>) : DatabaseException("Unable to find DAO for $clazz")

    /**
     * Error thrown whenever an add/update/query operation is fired when DB is in `destroyed` state
     */
    object DatabaseDestroyed : DatabaseException("Database was destroyed")

    /**
     * Error thrown whenever fetchOne returns more than one row
     */
    object MultipleRowsFetched : DatabaseException("Mutliple rows fetched")
}
