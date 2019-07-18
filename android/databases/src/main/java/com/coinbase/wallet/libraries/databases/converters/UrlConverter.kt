package com.coinbase.wallet.libraries.databases.converters

import androidx.room.TypeConverter
import java.net.URL

/**
 * Database converter for URL
 */
class UrlConverter {
    @TypeConverter
    fun fromString(value: String?): URL? {
        return if (value.isNullOrEmpty()) null else URL(value)
    }

    @TypeConverter
    fun toString(value: URL?): String? {
        return value?.toString()
    }
}
