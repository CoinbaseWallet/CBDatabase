package com.coinbase.wallet.libraries.databases.exceptions

import java.lang.Exception

/**
 * Represents exceptions thrown by module
 */
class DatabaseException(val msg: String) : Exception(msg) {
    /**
     * Thrown if unable to find DAO for provided model
     */
    class MissingDao(clazz: Class<*>) : Exception("Unable to find DAO for $clazz")
}
