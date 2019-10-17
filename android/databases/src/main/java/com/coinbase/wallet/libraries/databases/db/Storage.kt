package com.coinbase.wallet.libraries.databases.db

import androidx.room.Room
import androidx.sqlite.db.SimpleSQLiteQuery
import com.coinbase.wallet.core.util.Optional
import com.coinbase.wallet.libraries.databases.exceptions.DatabaseException
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseDaoInterface
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseModelObject
import com.coinbase.wallet.libraries.databases.interfaces.StorageOptions
import com.coinbase.wallet.libraries.databases.model.DatabaseOperation
import com.coinbase.wallet.libraries.databases.model.DiskOptions
import com.coinbase.wallet.libraries.databases.model.MemoryOptions
import io.reactivex.Observable
import io.reactivex.Scheduler
import io.reactivex.Single
import io.reactivex.schedulers.Schedulers
import io.reactivex.subjects.PublishSubject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.Lock
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 *  Room sqlitedb storage handler
 *
 *  @property modelDaos Mapping of database models to Dao.
 */
@PublishedApi
internal class Storage<P : RoomDatabaseProvider> private constructor() {
    private lateinit var options: StorageOptions
    private lateinit var provider: RoomDatabaseProvider

    /**
     * Mapping of class to Observer.
     */
    val observers = ConcurrentHashMap<Class<*>, PublishSubject<*>>()

    /**
     * Mapping of database models to Dao.
     */
    lateinit var modelDaos: Map<Class<*>, DatabaseDaoInterface<*>>
        private set

    /**
     * Read/Write lock for accessing the database.
     */
    val multiReadSingleWriteLock = ReentrantReadWriteLock()

    /**
     * Io scheduler used by database.
     */
    val scheduler: Scheduler by lazy { Schedulers.io() }

    /**
     * Determine whether db was destroyed.
     */
    var isDestroyed = false
        private set

    constructor(disk: DiskOptions<P>) : this() {
        val builder = Room.databaseBuilder(disk.context, disk.providerClazz, disk.dbName)

        disk.migrations.forEach { builder.addMigrations(it) }

        if (disk.destructiveFallback) {
            builder.fallbackToDestructiveMigration()
        }

        provider = builder.build()
        modelDaos = provider.modelMappings()
        options = disk
    }

    constructor(memory: MemoryOptions<P>) : this() {
        provider = Room.inMemoryDatabaseBuilder(memory.context, memory.providerClazz).build()
        modelDaos = provider.modelMappings()
        options = memory
    }

    /**
     * Perform database operation within the read/write lock
     *
     * @param operation Indicate the type of operation to execute
     * @param work closure called when performing a database operation
     *
     * @return Single wrapping model(s) involved in the db operation
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T, reified R> perform(
        operation: DatabaseOperation,
        crossinline work: (dao: DatabaseDaoInterface<T>) -> R
    ): Single<R> = Single
        .create<R> { emitter ->
            val lock: Lock = when (operation) {
                DatabaseOperation.READ -> multiReadSingleWriteLock.readLock()
                DatabaseOperation.WRITE -> multiReadSingleWriteLock.writeLock()
            }

            val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
                ?: return@create emitter.onError(DatabaseException.MissingDao(T::class.java))

            lock.lock()

            if (isDestroyed) {
                lock.unlock()
                return@create emitter.onError(DatabaseException.DatabaseDestroyed)
            }

            try {
                val result = work(dao) as? R ?: throw IllegalArgumentException("Invalid result")
                emitter.onSuccess(result)
            } catch (err: Throwable) {
                emitter.onError(err)
            } finally {
                lock.unlock()
            }
        }
        .subscribeOn(scheduler)
        .observeOn(scheduler)

    /**
     * Counts total stored objects for a given class
     *
     * @param query SQL query used to filter count
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the total number of records found
     */
    @Suppress("UNCHECKED_CAST")
    fun count(
        query: String,
        vararg args: Any
    ): Single<Int> = Single
        .create<Int> { emitter ->
            multiReadSingleWriteLock.read {
                if (isDestroyed) {
                    return@read emitter.onError(DatabaseException.DatabaseDestroyed)
                }

                try {
                    val cursor = provider.query(SimpleSQLiteQuery(query, args))
                    val result = if (cursor.count == 0) {
                        0
                    } else {
                        cursor.moveToNext()
                        cursor.getInt(0)
                    }

                    emitter.onSuccess(result)
                } catch (err: Throwable) {
                    emitter.onError(err)
                }
            }
        }
        .subscribeOn(scheduler)
        .observeOn(scheduler)

    /**
     * Observe for a given model type
     *
     * @param clazz: Filter observer by model type
     *
     * @return Single wrapping the updated model or an error is thrown
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> observe(
        clazz: Class<T>
    ): Observable<T> = multiReadSingleWriteLock.read {
        if (isDestroyed) {
            return@read Observable.error(DatabaseException.DatabaseDestroyed)
        }

        getOrCreateSubject(clazz).hide()
    }

    /**
     * Notifies the observers of any changes.
     *
     * @param record A db record published to observers
     */
    inline fun <reified T : DatabaseModelObject> notifyObservers(record: Optional<T>) {
        val (subject, isDestroyed, element) = multiReadSingleWriteLock.read {
            val element = record.toNullable() ?: return
            val subject = getOrCreateSubject(T::class.java)

            Triple(subject, this.isDestroyed, element)
        }

        if (isDestroyed) {
            subject.onError(DatabaseException.DatabaseDestroyed)
        } else {
            subject.onNext(element)
        }
    }

    /**
     * Get or create subject for given class type
     *
     * @param clazz: Generic type for the subject
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> getOrCreateSubject(
        clazz: Class<T>
    ): PublishSubject<T> = synchronized(this) {
        var subject = observers[T::class.java] as? PublishSubject<T>

        if (subject == null) {
            subject = PublishSubject.create()
            observers[T::class.java] = subject
            subject
        } else {
            subject
        }
    }

    /**
     * Delete sqlite file and marks it as destroyed. All read/write operations will fail
     */
    fun destroy() = multiReadSingleWriteLock.write {
        if (!isDestroyed) {
            isDestroyed = true
            reset()
        }
    }

    /**
     * Delete the current database sqlite file.
     */
    @Suppress("UNCHECKED_CAST")
    fun reset() = multiReadSingleWriteLock.write {
        provider.beginTransaction()

        try {
            provider.clearAllTables()
            provider.setTransactionSuccessful()
        } finally {
            provider.endTransaction()
        }

        (options as? DiskOptions<P>)?.let { disk ->
            // Force a wal checkpoint which would transfer all transactions from the WAL file into the original DB.
            // This step is just a precaution to make sure no data is left in the original DB file.
            provider.query(SimpleSQLiteQuery("pragma wal_checkpoint(full)"))

            // delete db files on file
            disk.context.deleteDatabase(disk.dbName)
        }
    }
}
