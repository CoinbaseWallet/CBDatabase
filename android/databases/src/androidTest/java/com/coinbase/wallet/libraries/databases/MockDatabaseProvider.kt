package com.coinbase.wallet.libraries.databases

import androidx.room.Dao
import androidx.room.Database
import com.coinbase.wallet.libraries.databases.db.RoomDatabaseProvider
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseDaoInterface

@Database(entities = [MockUser::class, TestCurrency::class, TestWallet::class], version = 1)
abstract class MockDatabaseProvider : RoomDatabaseProvider() {
    // List of DAO for given model

    abstract fun getMockUserDao(): MockUserDatabaseDaoInterface
    abstract fun getTestCurrencyDao(): TestCurrencyDatabaseDaoInterface
    abstract fun getTestWalletDao(): TestWalletDatabaseDaoInterface

    // Maps a model -> DAO interface

    override fun modelMappings(): Map<Class<*>, DatabaseDaoInterface<*>> {
        return mapOf(
            MockUser::class.java to getMockUserDao(),
            TestCurrency::class.java to getTestCurrencyDao(),
            TestWallet::class.java to getTestWalletDao()
        )
    }

    // Default DAO declaration

    @Dao
    interface TestCurrencyDatabaseDaoInterface : DatabaseDaoInterface<TestCurrency>

    @Dao
    interface MockUserDatabaseDaoInterface : DatabaseDaoInterface<MockUser>

    @Dao
    interface TestWalletDatabaseDaoInterface : DatabaseDaoInterface<TestWallet>
}
