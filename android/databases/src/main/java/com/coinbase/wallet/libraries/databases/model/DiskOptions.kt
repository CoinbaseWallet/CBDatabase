package com.coinbase.wallet.libraries.databases.model

import android.content.Context
import androidx.room.migration.Migration

/**
 * Options for Room sqlite database
 *
 * @property context Android context used to create room db
 * @property providerClazz Room-specific database provider
 * @property dbName Name of the database
 * @property migrations list of migrations to include
 * @property destructiveFallback If true and a migration is missing, the database will be whipped
 */
data class DiskOptions<T>(
    val context: Context,
    val providerClazz: Class<T>,
    val dbName: String,
    val migrations: List<Migration> = emptyList(),
    val destructiveFallback: Boolean = false
)
