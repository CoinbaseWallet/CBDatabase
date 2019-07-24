package com.coinbase.wallet.libraries.databases

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.coinbase.wallet.libraries.databases.db.Database
import com.coinbase.wallet.libraries.databases.model.MemoryOptions
import com.coinbase.wallet.core.util.Optional
import io.reactivex.Single
import io.reactivex.schedulers.Schedulers
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import io.reactivex.rxkotlin.Singles

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

        database.add(record).blockingGet()
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

    private fun createMemoryDatabase(): Database<MockDatabaseProvider> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val memoryOptions = MemoryOptions(context, MockDatabaseProvider::class.java)
        val database = Database(memory = memoryOptions)

        return database
    }
}
