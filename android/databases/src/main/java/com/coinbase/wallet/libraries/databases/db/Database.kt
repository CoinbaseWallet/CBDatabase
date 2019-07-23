package com.coinbase.wallet.libraries.databases.db

import androidx.room.Room
import androidx.sqlite.db.SimpleSQLiteQuery
import com.coinbase.wallet.core.util.Optional
import com.coinbase.wallet.core.util.toOptional
import com.coinbase.wallet.libraries.databases.exceptions.DatabaseException
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseDaoInterface
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseModelObject
import com.coinbase.wallet.libraries.databases.model.DiskOptions
import com.coinbase.wallet.libraries.databases.model.MemoryOptions
import io.reactivex.Observable
import io.reactivex.Single
import io.reactivex.schedulers.Schedulers
import io.reactivex.subjects.PublishSubject
import java.util.concurrent.ConcurrentHashMap

class Database<T : RoomDatabaseProvider>() {
    private lateinit var provider: RoomDatabaseProvider

    constructor(disk: DiskOptions<T>) : this() {
        val builder = Room.databaseBuilder(disk.context, disk.providerClazz, disk.dbName)

        disk.migrations.forEach { builder.addMigrations(it) }

        if (disk.destructiveFallback) {
            builder.fallbackToDestructiveMigration()
        }

        provider = builder.build()
        modelDaos = provider.modelMappings()
    }

    constructor(memory: MemoryOptions<T>) : this() {
        provider = Room.inMemoryDatabaseBuilder(memory.context, memory.providerClazz).build()
        modelDaos = provider.modelMappings()
    }

    /**
     * Mapping of database models to Dao. Exposed for inline functions below.
     */
    lateinit var modelDaos: Map<Class<*>, DatabaseDaoInterface<*>>
        private set

    /**
     * Mapping of class to Observer. Exposed for inline functions below
     */
    val observers = ConcurrentHashMap<Class<*>, PublishSubject<*>>()

    /**
     * Adds a new model to the database.
     *
     * @param model The model to add to the database.
     *
     * @return A Single wrapping an optional model indicating whether the add succeeded.
     */
    inline fun <reified T : DatabaseModelObject> add(model: T): Single<Optional<T>> {
        return add(listOf(model)).map { it.toNullable()?.firstOrNull().toOptional() }
    }

    /**
     * Adds new models to the database.
     *
     * @param models The models to add to the database.
     *
     * @return A Single wrapping an optional list of models indicating whether the add succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> add(models: List<T>): Single<Optional<List<T>>> {
        val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
            ?: return Single.error(DatabaseException.MissingDao(T::class.java))

        return dao.add(models)
            .toSingleDefault(models.toOptional())
            .onErrorReturn { null.toOptional() }
            .doAfterSuccess { records ->
                records.toNullable()?.forEach { notifyObservers(it.toOptional()) }
            }
    }

    /**
     * Adds a new model or update if an existing record is found.
     *
     * @param model The model to add to the database.
     *
     * @return A Single wrapping an optional model indicating whether the add/update succeeded.
     */
    inline fun <reified T : DatabaseModelObject> addOrUpdate(model: T): Single<Optional<T>> {
        return addOrUpdate(listOf(model)).map { it.toNullable()?.firstOrNull().toOptional() }
    }

    /**
     * Adds new models or update if existing records are found.
     *
     * @param models The models to add to the database.
     *
     * @return A Single wrapping an optional list of models indicating whether the add/update succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> addOrUpdate(models: List<T>): Single<Optional<List<T>>> {
        val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
            ?: return Single.error(DatabaseException.MissingDao(T::class.java))

        return dao.addOrUpdate(models)
            .toSingleDefault(models.toOptional())
            .onErrorReturn { null.toOptional() }
            .doAfterSuccess { records ->
                records.toNullable()?.forEach { notifyObservers(it.toOptional()) }
            }
    }

    /**
     * Updates the object in the data store.
     *
     * @param model The object to update in the database.
     *
     * @return A Single representing whether the update succeeded. Succeeds is false if the object is not already
     *     in the database.
     */
    inline fun <reified T : DatabaseModelObject> update(model: T): Single<Optional<T>> {
        return update(listOf(model)).map { it.toNullable()?.firstOrNull().toOptional() }
    }

    /**
     * Updates the objects in the datastore
     *
     * @param models The objects to update in the database
     *
     * @return A Single representing whether the update succeeded. Succeeds is false if the object is not already
     *         in the database.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> update(models: List<T>): Single<Optional<List<T>>> {
        val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
            ?: return Single.error(DatabaseException.MissingDao(T::class.java))

        return dao.update(models)
            .toSingleDefault(models.toOptional())
            .onErrorReturn { null.toOptional() }
            .doAfterSuccess { records ->
                records.toNullable()?.forEach { notifyObservers(it.toOptional()) }
            }
    }

    /**
     * Fetches objects from the data store using given SQL
     *
     * @param query SQL query used to fetch the data
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the items returned by the fetch.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> fetch(query: String, vararg args: Any): Single<List<T>> {
        val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
            ?: return Single.error(DatabaseException.MissingDao(T::class.java))

        return dao.fetch(SimpleSQLiteQuery(query, args))
    }

    /**
     * Fetches a single model from the data store using given SQL
     *
     * @param query SQL query used to fetch the data
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the item returned by the fetch.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> fetchOne(query: String, vararg args: Any): Single<Optional<T>> {
        return this.fetch<T>(query, *args).map { it.firstOrNull().toOptional() }
    }

    /**
     * Counts total stored objects for a given class
     *
     * @param query SQL query used to filter count
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the total number of records found
     */
    @Suppress("UNCHECKED_CAST")
    fun count(query: String, vararg args: Any): Single<Int> {
        return Single
            .create<Int> { emitter ->
                val cursor = provider.query(SimpleSQLiteQuery(query, args))
                if (cursor.count == 0) {
                    emitter.onSuccess(0)
                } else {
                    cursor.moveToNext()
                    emitter.onSuccess(cursor.getInt(0))
                }
            }
            .subscribeOn(Schedulers.io())
    }

    /**
     * Deletes the object from the data store.
     *
     * @param model The identifier of the object to be deleted.
     *
     * @return A Single wrapping a boolean indicating whether the delete succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> delete(model: T): Single<Boolean> {
        val dao = modelDaos[T::class.java] as? DatabaseDaoInterface<T>
            ?: return Single.error(DatabaseException.MissingDao(T::class.java))

        return dao.delete(model)
            .toSingleDefault(true)
            .onErrorReturn { false }
            .doAfterSuccess { notifyObservers(model.toOptional()) }
    }

    /**
     * Observe for a given model type
     *
     * @param clazz: Filter observer by model type
     *
     * @return Single wrapping the updated model or an error is thrown
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> observe(clazz: Class<T>): Observable<T> {
        val subject: PublishSubject<T> = synchronized(this) {
            val existingSubject = observers[clazz] as? PublishSubject<T>
            if (existingSubject != null) {
                return@synchronized existingSubject
            }

            val subject = PublishSubject.create<T>()
            observers[clazz] = subject

            return@synchronized subject
        }

        return subject.hide()
    }

    /**
     * Observe for a given model
     *
     * @param clazz Filter observer by model type
     * @param id Filter observer by model ID
     *
     * @return Single wrapping the updated model or an error is thrown
     */
    inline fun <reified T : DatabaseModelObject> observe(clazz: Class<T>, id: String): Observable<T> {
        return observe(clazz).filter { it.id == id }
    }

    /**
     * Notifies the observers of any changes. This is exposed due to inline function visibility restriction
     *
     * @param record A db record published to observers
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> notifyObservers(record: Optional<T>) {
        val element = record.toNullable() ?: return
        val subject: PublishSubject<T> = synchronized(this) {
            var subject = observers[T::class.java] as? PublishSubject<T>

            if (subject == null) {
                subject = PublishSubject.create()
                observers[T::class.java] = subject
            }

            return@synchronized subject
        }

        subject.onNext(element)
    }
}
