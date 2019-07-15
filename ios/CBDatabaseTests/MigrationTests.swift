// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

@testable import CBDatabase
import CoreData
import RxBlocking
import RxSwift
import XCTest

class MigrationTests: XCTestCase {
    func testMigrationToVersionTwo() throws {
        let predicate = NSPredicate(format: "name = %@", "hish")
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Person")
        var diskOptions = try DiskDatabaseOptions(
            dbSchemaName: "ProgressiveMigrationDB",
            dbStorageFilename: "progressivedb",
            versions: ["ProgressiveMigrationDB", "v2db"],
            dataModelBundle: Bundle(for: DatabasesTests.self)
        )

        fetchRequest.predicate = predicate

        // clear current database (if one exists)
        let docURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
        guard
            let sqliteURL = docURL?.appendingPathComponent("\(diskOptions.dbStorageFilename).sqlite"),
            let sqliteShmFile = docURL?.appendingPathComponent("\(diskOptions.dbStorageFilename).sqlite-shm"),
            let sqliteWalFile = docURL?.appendingPathComponent("\(diskOptions.dbStorageFilename).sqlite-wal")
        else {
            return XCTFail("missing storeURL \(diskOptions)")
        }

        [sqliteURL, sqliteShmFile, sqliteWalFile].forEach { try? FileManager.default.removeItem(at: $0) }

        // copy over database initialized db @ v1 model
        let bundle = Bundle(for: MigrationTests.self)
        guard
            let sqliteOldFile = bundle.url(forResource: "progressivedb", withExtension: "sqlite"),
            let sqliteOldShmFile = bundle.url(forResource: "progressivedb", withExtension: "sqlite-shm"),
            let sqliteOldWalFile = bundle.url(forResource: "progressivedb", withExtension: "sqlite-wal")
        else {
            return XCTFail("missing progressivedb file")
        }

        do {
            try FileManager.default.copyItem(at: sqliteOldFile, to: sqliteURL)
            try FileManager.default.copyItem(at: sqliteOldShmFile, to: sqliteShmFile)
            try FileManager.default.copyItem(at: sqliteOldWalFile, to: sqliteWalFile)
        } catch {
            print("error \(error)")
            XCTFail("Unable to copy over legacy db \(error)")
        }

        // progress to v2
        var database = try Database(disk: diskOptions)
        var count = try database.count(for: Person.self).toBlocking(timeout: unitTestsTimeout).single()
        var storedObjects = try database.storage.context.fetch(fetchRequest)

        guard
            let personV2 = storedObjects.first, storedObjects.count == 1,
            let createdAtV2 = personV2.value(forKey: "createdAt") as? Date,
            let nameV2 = personV2.value(forKey: "name") as? String,
            let ageV2 = personV2.value(forKey: "age") as? Int
        else {
            return XCTFail("Unable to migrate to v2")
        }

        XCTAssertTrue(Calendar.current.isDateInToday(createdAtV2))
        XCTAssertEqual(nameV2, "hish")
        XCTAssertEqual(ageV2, 37)

        // progress to v3
        diskOptions = try DiskDatabaseOptions(
            dbSchemaName: "ProgressiveMigrationDB",
            dbStorageFilename: "progressivedb",
            versions: ["ProgressiveMigrationDB", "v2db", "v3db"],
            dataModelBundle: Bundle(for: DatabasesTests.self)
        )

        database = try Database(disk: diskOptions)
        storedObjects = try database.storage.context.fetch(fetchRequest)

        guard
            let personV3 = storedObjects.first, storedObjects.count == 1,
            let createdAtV3 = personV3.value(forKey: "createdAt") as? Date,
            let nameV3 = personV3.value(forKey: "name") as? String,
            let ageV3 = personV3.value(forKey: "age") as? String
        else {
            return XCTFail("Unable to migrate to v3")
        }

        XCTAssertTrue(Calendar.current.isDateInToday(createdAtV3))
        XCTAssertEqual(nameV3, "hish")
        XCTAssertEqual(ageV3, "37")

        // progress to v4
        diskOptions = try DiskDatabaseOptions(
            dbSchemaName: "ProgressiveMigrationDB",
            dbStorageFilename: "progressivedb",
            versions: ["ProgressiveMigrationDB", "v2db", "v3db", "v4db"],
            dataModelBundle: Bundle(for: DatabasesTests.self)
        )

        database = try Database(disk: diskOptions)
        count = try database.count(for: Person.self).toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertTrue(count == 1)

        var person: Person? = try database.fetchOne(predicate: predicate).toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertNotNil(person)

        XCTAssertEqual(person?.name, "hish")
        XCTAssertEqual(person?.age, "37")

        guard let aPerson = person else { return XCTFail("cannot find person") }

        XCTAssertTrue(Calendar.current.isDateInToday(aPerson.createdAt))

        let updatedAt = Date()
        let updatedPerson = Person(
            id: aPerson.id,
            name: aPerson.name,
            age: aPerson.age,
            createdAt: aPerson.createdAt,
            updatedAt: updatedAt
        )

        _ = try database.addOrUpdate(updatedPerson).toBlocking(timeout: unitTestsTimeout).single()

        person = try database.fetchOne(predicate: predicate).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertNotNil(person)

        XCTAssertEqual(person?.name, "hish")
        XCTAssertEqual(person?.age, "37")
        XCTAssertEqual(person?.updatedAt, updatedAt)
    }
}

struct Person: DatabaseModelObject {
    let id: String
    let name: String
    let age: String
    let createdAt: Date
    let updatedAt: Date?

    init(id: String = UUID().uuidString, name: String, age: String, createdAt: Date, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

class ProgressiveMigrationV1toV2PersonPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in _: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard source.entity.name == "Person" else { return }

        let destinationContext = manager.destinationContext

        if
            let id = source.primitiveValue(forKey: "id") as? String,
            let name = source.primitiveValue(forKey: "name") as? String,
            let age = source.primitiveValue(forKey: "age") as? Int {
            let destination = NSEntityDescription.insertNewObject(forEntityName: "Person", into: destinationContext)

            destination.setValue(name, forKey: "name")
            destination.setValue(age, forKey: "age")
            destination.setValue(Date(), forKey: "createdAt")
            destination.setValue(id, forKey: "id")
        }
    }
}

class ProgressiveMigrationV2toV3PersonPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in _: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard source.entity.name == "Person" else { return }

        let destinationContext = manager.destinationContext

        if
            let id = source.primitiveValue(forKey: "id") as? String,
            let name = source.primitiveValue(forKey: "name") as? String,
            let age = source.primitiveValue(forKey: "age") as? Int,
            let date = source.primitiveValue(forKey: "createdAt") as? Date {
            let destination = NSEntityDescription.insertNewObject(forEntityName: "Person", into: destinationContext)

            destination.setValue(name, forKey: "name")
            destination.setValue(String(age), forKey: "age")
            destination.setValue(date, forKey: "createdAt")
            destination.setValue(id, forKey: "id")
        }
    }
}
