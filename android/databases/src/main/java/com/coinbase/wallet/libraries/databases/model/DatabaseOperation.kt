package com.coinbase.wallet.libraries.databases.model

/**
 * Represents a database operation
 */
enum class DatabaseOperation {
    /**
     * Read only operation
     */
    READ,

    /**
     * Write only operation
     */
    WRITE
}
