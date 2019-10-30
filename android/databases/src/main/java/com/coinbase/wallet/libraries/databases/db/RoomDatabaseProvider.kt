package com.coinbase.wallet.libraries.databases.db

import androidx.room.RoomDatabase
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseDaoInterface

/**
 * Provider used to configure and create a room database.
 */
abstract class RoomDatabaseProvider : RoomDatabase() {
    /**
     * Maps models to default DAO interfaces
     */
    abstract fun modelMappings(): Map<Class<*>, DatabaseDaoInterface<*>>

    fun update(query: String, args: Array<*>) {
        if (args.isEmpty()) {
            openHelper.writableDatabase.execSQL(query)
        } else {
            openHelper.writableDatabase.execSQL(query, args)
        }
    }
}
