package com.coinbase.wallet.libraries.databases.converters

import androidx.room.TypeConverter
import java.math.BigDecimal

/**
 * Database converter for BigDecimal
 */
class BigDecimalConverter {
    @TypeConverter
    fun fromString(value: String?): BigDecimal? {
        return if (value.isNullOrEmpty()) null else BigDecimal(value)
    }

    @TypeConverter
    fun toString(value: BigDecimal?): String? {
        return value?.toString()
    }
}
