package com.coinbase.wallet.libraries.databases.model

import android.content.Context

/**
 * Options for Room sqlite database
 *
 * @property context Android context used to create room db
 * @property providerClazz Room-specific database provider
 * @property dbName Name of the database
 */
data class DiskOptions<T>(val context: Context, val providerClazz: Class<T>, val dbName: String)
