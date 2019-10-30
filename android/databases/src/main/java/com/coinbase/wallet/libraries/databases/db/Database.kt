package com.coinbase.wallet.libraries.databases.db

import androidx.sqlite.db.SimpleSQLiteQuery
import com.coinbase.wallet.core.extensions.Strings
import com.coinbase.wallet.core.extensions.empty
import com.coinbase.wallet.core.util.Optional
import com.coinbase.wallet.core.util.toOptional
import com.coinbase.wallet.libraries.databases.exceptions.DatabaseException
import com.coinbase.wallet.libraries.databases.interfaces.DatabaseModelObject
import com.coinbase.wallet.libraries.databases.model.DatabaseOperation
import com.coinbase.wallet.libraries.databases.model.DiskOptions
import com.coinbase.wallet.libraries.databases.model.MemoryOptions
import io.reactivex.Observable
import io.reactivex.Single

class Database<R : RoomDatabaseProvider> private constructor() {
    /**
     * Manages the data underlying storage.
     */
    @PublishedApi
    internal lateinit var storage: Storage<R>
        private set

    constructor(disk: DiskOptions<R>) : this() {
        storage = Storage(disk)
    }

    constructor(memory: MemoryOptions<R>) : this() {
        storage = Storage(memory)
    }

    /**
     * Adds a new model to the database.
     *
     * @param model The model to add to the database.
     *
     * @return A Single wrapping an optional model indicating whether the add succeeded.
     */
    inline fun <reified T : DatabaseModelObject> add(
        model: T
    ): Single<Optional<T>> = add(listOf(model)).map { it.value?.firstOrNull().toOptional() }

    /**
     * Adds new models to the database.
     *
     * @param models The models to add to the database.
     *
     * @return A Single wrapping an optional list of models indicating whether the add succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> add(
        models: List<T>
    ): Single<Optional<List<T>>> = storage
        .perform<T, Optional<List<T>>>(DatabaseOperation.WRITE) { dao ->
            dao.add(models)

            models.toOptional()
        }
        .doAfterSuccess { models.forEach { storage.notifyObservers(it.toOptional()) } }

    /**
     * Adds a new model or update if an existing record is found.
     *
     * @param model The model to add to the database.
     *
     * @return A Single wrapping an optional model indicating whether the add/update succeeded.
     */
    inline fun <reified T : DatabaseModelObject> addOrUpdate(
        model: T
    ): Single<Optional<T>> = addOrUpdate(listOf(model)).map { it.value?.firstOrNull().toOptional() }

    /**
     * Adds new models or update if existing records are found.
     *
     * @param models The models to add to the database.
     *
     * @return A Single wrapping an optional list of models indicating whether the add/update succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> addOrUpdate(
        models: List<T>
    ): Single<Optional<List<T>>> = storage
        .perform<T, Optional<List<T>>>(DatabaseOperation.WRITE) { dao ->
            dao.addOrUpdate(models)

            models.toOptional()
        }
        .doAfterSuccess { models.forEach { storage.notifyObservers(it.toOptional()) } }

    /**
     * Updates the object in the data store.
     *
     * @param model The object to update in the database.
     *
     * @return A Single representing whether the update succeeded. Succeeds is false if the object is not already
     *     in the database.
     */
    inline fun <reified T : DatabaseModelObject> update(
        model: T
    ): Single<Optional<T>> = update(listOf(model)).map { it.value?.firstOrNull().toOptional() }

    /**
     * Updates the objects in the datastore
     *
     * @param models The objects to update in the database
     *
     * @return A Single representing whether the update succeeded. Succeeds is false if the object is not already
     *         in the database.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> update(
        models: List<T>
    ): Single<Optional<List<T>>> = storage
        .perform<T, Optional<List<T>>>(DatabaseOperation.WRITE) { dao ->
            dao.update(models)

            models.toOptional()
        }
        .doAfterSuccess { models.forEach { storage.notifyObservers(it.toOptional()) } }

    /**
     * Fetches objects from the data store using given SQL
     *
     * @param query SQL query used to fetch the data
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the items returned by the fetch.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> update(
        updateQuery: String,
        fetchQuery: String,
        vararg args: Any
    ): Single<List<T>> = storage
        .perform<T, List<T>>(DatabaseOperation.WRITE) { dao ->
            buildSQLQuery(updateQuery, *args).let { (newQuery, newArgs) ->
                storage.provider.runInTransaction {
                    storage.provider.update(newQuery, newArgs)
                }
            }
            val foo = buildSQLQuery(fetchQuery, *args).let { (newQuery, newArgs) ->
                if (newArgs.isEmpty()) {
                    dao.fetch(SimpleSQLiteQuery(newQuery))
                } else {
                    dao.fetch(SimpleSQLiteQuery(newQuery, newArgs))
                }
            }
            foo
        }
        .doAfterSuccess { models -> models.forEach { storage.notifyObservers(it.toOptional()) } }

    /**
     * Fetches objects from the data store using given SQL
     *
     * @param query SQL query used to fetch the data
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the items returned by the fetch.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> fetch(
        query: String,
        vararg args: Any
    ): Single<List<T>> = storage
        .perform<T, List<T>>(DatabaseOperation.READ) { dao ->
            buildSQLQuery(query, *args).let { (newQuery, newArgs) ->
                if (newArgs.isEmpty()) {
                    dao.fetch(SimpleSQLiteQuery(newQuery))
                } else {
                    dao.fetch(SimpleSQLiteQuery(newQuery, newArgs))
                }
            }
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
    inline fun <reified T : DatabaseModelObject> fetchOne(
        query: String,
        vararg args: Any
    ): Single<Optional<T>> = fetch<T>(query, *args)
        .map { records ->
            if (records.count() > 1) {
                throw DatabaseException.MultipleRowsFetched
            }

            records.firstOrNull().toOptional()
        }

    /**
     * Deletes the object from the data store.
     *
     * @param model The identifier of the object to be deleted.
     *
     * @return A Single wrapping a boolean indicating whether the delete succeeded.
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> delete(
        model: T
    ): Single<Boolean> = storage
        .perform<T, Boolean>(DatabaseOperation.WRITE) { dao ->
            try {
                dao.delete(model)
                true
            } catch (e: Throwable) {
                false
            }
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
    fun count(query: String, vararg args: Any): Single<Int> = storage.count(query, *args)

    /**
     * Observe for a given model type
     *
     * @param clazz: Filter observer by model type
     *
     * @return Single wrapping the updated model or an error is thrown
     */
    @Suppress("UNCHECKED_CAST")
    inline fun <reified T : DatabaseModelObject> observe(clazz: Class<T>): Observable<T> = storage.observe(clazz)

    /**
     * Observe for a given model
     *
     * @param clazz Filter observer by model type
     * @param id Filter observer by model ID
     *
     * @return Single wrapping the updated model or an error is thrown
     */
    inline fun <reified T : DatabaseModelObject> observe(
        clazz: Class<T>,
        id: String
    ): Observable<T> = observe(clazz).filter { it.id == id }

    /**
     * Delete sqlite file and marks it as destroyed. All read/write operations will fail
     */
    fun destroy() = storage.destroy()

    /**
     * Delete the current database sqlite file.
     */
    fun reset() = storage.reset()

    // Private/Internal helpers

    @Suppress("UNCHECKED_CAST")
    @PublishedApi
    internal fun buildSQLQuery(query: String, vararg args: Any): Pair<String, Array<*>> {
        if (args.isEmpty() || query.count { it == '?' } != args.size) return Pair(query, args)

        val flatArgs = mutableListOf<Any>()
        val newQuery = query.split("?")
            .mapIndexed { index, str ->
                val arg = args.getOrNull(index)
                val argList = arg as? Collection<Any> ?: arg?.let { listOf(it) } ?: emptyList()
                val placeholders = argList.joinToString(",") { "?" }

                flatArgs.addAll(argList)
                str + placeholders
            }
            .joinToString(separator = Strings.empty)

        return Pair(newQuery, flatArgs.toTypedArray())
    }
}
