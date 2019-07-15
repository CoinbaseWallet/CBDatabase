package com.coinbase.wallet.libraries.databases

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseModelObject

@Entity(tableName = "MockUsers")
data class MockUser(
    @PrimaryKey override var id: String,
    var username: String
) : DatabaseModelObject

@Entity(tableName = "TestCurrency")
data class TestCurrency(
    var code: String,
    var name: String
) : DatabaseModelObject {
    @PrimaryKey
    override var id: String = code
}
