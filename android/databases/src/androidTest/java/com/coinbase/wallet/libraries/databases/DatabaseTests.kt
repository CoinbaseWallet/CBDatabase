package com.coinbase.wallet.libraries.databases

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.coinbase.wallet.core.util.Optional
import com.coinbase.wallet.libraries.databases.db.Database
import com.coinbase.wallet.libraries.databases.model.DiskOptions
import com.coinbase.wallet.libraries.databases.model.MemoryOptions
import io.reactivex.Single
import io.reactivex.rxkotlin.Singles
import io.reactivex.schedulers.Schedulers
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.util.concurrent.CountDownLatch

@RunWith(AndroidJUnit4::class)
class DatabaseTests {
    @Test
    fun testEmptyCount() {
        val database = createMemoryDatabase()
        val count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(0, count)
    }

    @Test
    fun testCountWithRecords() {
        val database = createMemoryDatabase()

        var count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(0, count)

        val currencies = listOf(
            TestCurrency(code = "JTC", name = "JOHNNYCOIN"),
            TestCurrency(code = "ATC", name = "ANDREWCOIN"),
            TestCurrency(code = "HTC", name = "HISHCOIN")
        )

        database.add(currencies).blockingGet()
        count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(currencies.size, count)
    }

    @Test
    fun testAddUpdateAndFetchOne() {
        val database = createMemoryDatabase()

        var count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(0, count)

        val currencies = listOf(
            TestCurrency(code = "JTC", name = "JOHNNYCOIN"),
            TestCurrency(code = "ATC", name = "ANDREWCOIN"),
            TestCurrency(code = "HTC", name = "HISHCOIN")
        )

        database.addOrUpdate(currencies).blockingGet()
        val rs: Single<Optional<TestCurrency>> = database.fetchOne("SELECT * FROM TestCurrency WHERE code = ?", "ATC")
        val atcCoin = rs.blockingGet()
        Assert.assertEquals("ATC", atcCoin.toNullable()?.code)
        Assert.assertEquals("ANDREWCOIN", atcCoin.toNullable()?.name)
    }

    @Test
    fun testAddUpdateAndFetchMany() {
        val database = createMemoryDatabase()

        var count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(0, count)

        val currencies = listOf(
            TestCurrency(code = "JTC", name = "JOHNNYCOIN"),
            TestCurrency(code = "ATC", name = "ANDREWCOIN"),
            TestCurrency(code = "HTC", name = "HISHCOIN")
        ).sortedBy { it.code }

        database.addOrUpdate(currencies).blockingGet()
        val rs: Single<List<TestCurrency>> = database.fetch(
            "SELECT * FROM TestCurrency WHERE code ORDER BY code"
        )

        val actualCurrencies = rs.blockingGet()

        for (i in 0 until actualCurrencies.size) {
            val expected = currencies[i]
            val actual = actualCurrencies[i]
            Assert.assertEquals(expected.code, actual.code)
            Assert.assertEquals(expected.name, actual.name)
        }
    }

    @Test
    fun addSameRecordMultipleTimes() {
        val database = createMemoryDatabase()
        val record = TestCurrency(code = "JTC", name = "JOHNNYCOIN")

        database.add(record).blockingGet()

        var count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(1, count)

        database.addOrUpdate(record).blockingGet()
        count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(1, count)
    }

    @Test
    fun testDatabase() {
        val database = createMemoryDatabase()
        val expected = MockUser(id = "1", username = "hish")
        val expected2 = MockUser(id = "2", username = "aya")
        val latch = CountDownLatch(1)

        Schedulers.io().scheduleDirect {
            Singles.zip(database.addOrUpdate(expected), database.addOrUpdate(expected2))
                .flatMap {
                    val fetchSingle = database.fetchOne<MockUser>("SELECT * FROM MockUsers where id = ?", "1")
                    val countSingle = database.count("SELECT COUNT(*) FROM MockUsers")

                    return@flatMap Singles.zip(fetchSingle, countSingle)
                }
                .flatMap { (result, count) ->
                    val deleteSingle = database.delete(expected)

                    return@flatMap Singles.zip(Single.just(result), Single.just(count), deleteSingle)
                }
                .flatMap { (result, _, wasDeleted) ->
                    val countSingle = database.count("SELECT COUNT(*) FROM MockUsers")
                    return@flatMap Singles.zip(Single.just(result), countSingle, Single.just(wasDeleted))
                }
                .subscribe({ (result, count, wasDeleted) ->
                    println("hish: $result with count $count")
                    Assert.assertEquals(1, count)
                    Assert.assertEquals(expected.id, result.toNullable()?.id)
                    Assert.assertEquals(expected.username, result.toNullable()?.username)
                    latch.countDown()
                }, {
                    println("hish: error $it")
                    latch.countDown()
                })
        }

        latch.await()
    }

    @Test
    fun testObservable() {
        val database = createMemoryDatabase()
        val expected = MockUser(id = "12", username = "helloworld")
        var actual: MockUser? = null
        val latch = CountDownLatch(1)

        database.observe(MockUser::class.java, id = "12")
            .subscribe({
                println("hish: observed $it")
                actual = it
                latch.countDown()
            }, {
                println("hish: error $it")
                latch.countDown()
            })

        database.addOrUpdate(expected).subscribe()

        latch.await()
        Assert.assertEquals(expected.id, actual?.id)
        Assert.assertEquals(expected.username, actual?.username)
    }

    @Test
    fun testBuildSQLQuery() {
        val database = createMemoryDatabase()

        val query = "SELECT * FROM Address WHERE blockchain = ? AND currencyCode = ? AND address in (?)"
        val args = arrayOf("foo", "bar", listOf("0xab"))
        val expectedArgs = arrayOf(args[0], args[1], (args[2] as List<String>)[0])
        val args2 = arrayOf("foo", "bar", listOf("0xab", "0xbc"))

        database.buildSQLQuery(query, *args).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(query, resultQuery)
            Assert.assertArrayEquals(expectedArgs, resultArgs)
        }

        val expectedQuery2 = "SELECT * FROM Address WHERE blockchain = ? AND currencyCode = ? AND address in (?,?)"
        val expectedArgs2 = arrayOf(args2[0], args2[1], (args2[2] as List<String>)[0], (args2[2] as List<String>)[1])

        database.buildSQLQuery(query, *args2).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(expectedQuery2, resultQuery)
            Assert.assertArrayEquals(expectedArgs2, resultArgs)
        }

        val queryMiddle = "SELECT * FROM Address WHERE blockchain = ? AND address in (?) AND currencyCode = ?"

        val argsMiddle = arrayOf("foo", listOf("0xab", "0xcd"), "bar")
        val expectedArgsMiddle = arrayOf(
            argsMiddle[0],
            (argsMiddle[1] as List<String>)[0],
            (argsMiddle[1] as List<String>)[1],
            argsMiddle[2]
        )
        val expectedQueryMiddle = "SELECT * FROM Address WHERE blockchain = ? AND address in (?,?) AND currencyCode = ?"

        database.buildSQLQuery(queryMiddle, *argsMiddle).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(expectedQueryMiddle, resultQuery)
            Assert.assertArrayEquals(expectedArgsMiddle, resultArgs)
        }

        val queryFirst = "SELECT * FROM Address WHERE address in (?) AND blockchain = ? AND currencyCode = ?"

        val argsFirst = arrayOf(listOf("0xab", "0xcd"), "foo", "bar")
        val expectedArgsFirst = arrayOf(
            (argsFirst[0] as List<String>)[0],
            (argsFirst[0] as List<String>)[1],
            argsFirst[1],
            argsFirst[2]
        )
        val expectedQueryFirst = "SELECT * FROM Address WHERE address in (?,?) AND blockchain = ? AND currencyCode = ?"

        database.buildSQLQuery(queryFirst, *argsFirst).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(expectedQueryFirst, resultQuery)
            Assert.assertArrayEquals(expectedArgsFirst, resultArgs)
        }

        val queryWithMultipleLists = "SELECT * FROM Transaction WHERE txHash IN (?) OR txHash IN (?)"
        val expectedQueryWithMultipleLists = "SELECT * FROM Transaction WHERE txHash IN (?,?) OR txHash IN (?,?,?)"
        val args4 = arrayOf(listOf("0x1", "0x2"), listOf("0x3", "0x4", "0x5"))
        database.buildSQLQuery(queryWithMultipleLists, *args4).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(expectedQueryWithMultipleLists, resultQuery)
            Assert.assertArrayEquals(args4.toList().flatten().toTypedArray(), resultArgs)
        }
    }

    @Test
    fun testBuildSQLQueryNoList() {
        val database = createMemoryDatabase()
        val query = "SELECT * FROM Address WHERE blockchain = ? AND currencyCode = ? AND address in (?)"
        val args3 = arrayOf("foo", "bar", "0xab")
        database.buildSQLQuery(query, *args3).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(query, resultQuery)
            Assert.assertArrayEquals(args3, resultArgs)
        }

        val noArgsQuery = "SELECT * FROM Wallet order by currencyCode"

        database.buildSQLQuery(noArgsQuery).let { (resultQuery, resultArgs) ->
            Assert.assertEquals(noArgsQuery, resultQuery)
            Assert.assertEquals(0, resultArgs.size)
        }
    }

    @Test
    fun testDiskDBReset() {
        val database = createDiskDatabase()
        val record = TestCurrency(code = "JTC", name = "JOHNNYCOIN")
        val record2 = TestCurrency(code = "HTC", name = "HISHCOIN")
        val currencies = listOf(record, record2)

        database.add(currencies).blockingGet()

        var count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(currencies.size, count)

        database.reset()

        count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(0, count)

        val fetched = database.fetchOne<TestCurrency>("SELECT * FROM TestCurrency where code = ? LIMIT 1", "HTC")
            .blockingGet()

        Assert.assertNull(fetched.value)
    }

    @Test
    fun testDiskDBDestroy() {
        val database = createDiskDatabase()
        val record = TestCurrency(code = "JTC", name = "JOHNNYCOIN")
        val record2 = TestCurrency(code = "HTC", name = "HISHCOIN")
        val currencies = listOf(record, record2)

        database.add(currencies).blockingGet()

        val count = database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
        Assert.assertEquals(currencies.size, count)

        database.destroy()

        try {
            database.count("SELECT COUNT(*) FROM TestCurrency").blockingGet()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }

        try {
            database.fetchOne<TestCurrency>("SELECT * FROM TestCurrency where code = ? LIMIT 1", "HTC").blockingGet()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }

        try {
            database.fetch<TestCurrency>("SELECT * FROM TestCurrency where code = ?", "HTC").blockingGet()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }

        try {
            database.delete(record).blockingGet()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }

        try {
            database.addOrUpdate(currencies).blockingGet()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }

        try {
            database.observe(TestCurrency::class.java).blockingFirst()
            Assert.fail("Should thrown an exception")
        } catch (e: Throwable) {
            print("threw $e")
        }
    }

    @Test
    fun testDBUpdateQuery() {
        val database = createDiskDatabase()
        val record = TestWallet(address = "asdf", isActive = true, blockchain = "BTC", network = "testnet")
        val record2 = TestWallet(address = "asdf", isActive = false, blockchain = "BTC", network = "mainnet")
        val wallets = listOf(record, record2)
        val expectedWallets = listOf(record2.copy(isActive = true))
        val observed = mutableListOf<TestWallet>()
        var observedUpdate = false
        val latch = CountDownLatch(1)
        val updateLatch = CountDownLatch(1)

        database.add(wallets).blockingGet()

        database.observe(TestWallet::class.java)
            .subscribe({
                observed.add(it)
                latch.countDown()
            }, {
                latch.countDown()
            })

        database.observeBatchUpdate(TestWallet::class.java)
            .subscribe({
                observedUpdate = true
                updateLatch.countDown()
            }, {
                updateLatch.countDown()
            })

        val result = database.update<TestWallet>(
            "UPDATE TestWallet SET isActive = CASE network = ? WHEN 1 THEN 1 ELSE 0 END WHERE blockchain = ?",
            "SELECT * FROM TestWallet WHERE network = ? AND blockchain = ?",
            "mainnet",
            "BTC"
        ).blockingGet()

        latch.await()
        updateLatch.await()

        Assert.assertEquals(result, expectedWallets)
        Assert.assertEquals(observed, expectedWallets)
        Assert.assertTrue(observedUpdate)
    }

    private fun createDiskDatabase(): Database<MockDatabaseProvider> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val dbName = UUID.randomUUID().toString()
        val diskOptions = DiskOptions(context, MockDatabaseProvider::class.java, dbName)
        val database = Database(disk = diskOptions)

        return database
    }

    private fun createMemoryDatabase(): Database<MockDatabaseProvider> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val memoryOptions = MemoryOptions(context, MockDatabaseProvider::class.java)
        val database = Database(memory = memoryOptions)

        return database
    }
}
