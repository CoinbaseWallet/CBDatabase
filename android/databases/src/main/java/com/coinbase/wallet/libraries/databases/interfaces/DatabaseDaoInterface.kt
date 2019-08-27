package com.coinbase.wallet.libraries.databases.interfaces

import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Update
import androidx.room.RawQuery
import androidx.room.Transaction
import androidx.room.Delete
import androidx.sqlite.db.SupportSQLiteQuery
import io.reactivex.Completable
import io.reactivex.Single

/**
 * DAO interface used as a common DAO interface in Database object
 */
interface DatabaseDaoInterface<T> {
    /**
     * Adds new models to the database.
     *
     * @param models The models to add to the database.
     *
     * @return A Completable indicating whether the operation completed
     */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    fun add(model: List<T>): Completable

    /**
     * Adds new models or update if existing records are found.
     *
     * @param models The models to add to the database.
     *
     * @return A Completable indicating whether the operation completed
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun addOrUpdate(model: List<T>): Completable

    /**
     * Updates the objects in the datastore
     *
     * @param models The objects to update in the database
     *
     * @return A Completable indicating whether the operation completed
     */
    @Update
    fun update(model: List<T>): Completable

    /**
     * Fetches objects from the data store using given raw SQL
     *
     * @param query SQL query used to fetch the data
     * @param args Argument passed to fill placeholders in the query above
     *
     * @return A Single wrapping the items returned by the fetch.
     */
    @RawQuery
    @Transaction
    fun fetch(query: SupportSQLiteQuery): Single<List<T>>

    /**
     * Deletes the object from the data store.
     *
     * @param model The identifier of the object to be deleted.
     *
     * @return A Completable indicating whether the operation completed
     */
    @Delete
    fun delete(model: T): Completable

    /**
     * Deletes the objects from the data store
     *
     * @param models The models to be deleted
     *
     * @return A Completable indicating whether the operation completed
     */
    @Delete
    fun delete(models: List<T>): Completable
}
