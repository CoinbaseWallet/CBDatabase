package com.coinbase.wallet.libraries.databases.converters

import androidx.room.TypeConverter
import java.math.BigInteger

/**
 * Database converter for BigInteger
 */
class BigIntegerConverter {
    @TypeConverter
    fun fromString(value: String?): BigInteger? {
        return if (value.isNullOrEmpty()) null else BigInteger(value)
    }

    @TypeConverter
    fun toString(value: BigInteger?): String? {
        return value?.toString()
    }
}
