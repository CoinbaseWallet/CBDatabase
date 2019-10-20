package com.coinbase.wallet.libraries.databases.converters

import androidx.room.TypeConverter
import java.util.Date

/**
 * Converts [Date] instances to and from [Long] for disk persistence.
 */
class DateConverter {

    @TypeConverter
    fun toDate(timestamp: Long?): Date? {
        return if (timestamp == null) null else Date(timestamp)
    }

    @TypeConverter
    fun toTimestamp(date: Date?): Long? {
        return date?.time
    }
}
