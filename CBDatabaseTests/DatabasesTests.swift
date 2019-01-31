// Copyright (c) 2017-2019 Coinbase Inc. See LICENSE

import BigInt
@testable import CBDatabase
import RxBlocking
import XCTest

let unitTestsTimeout: TimeInterval = 3

class DatabasesTests: XCTestCase {
    let dbURL = Bundle(for: DatabasesTests.self).url(forResource: "TestDatabase", withExtension: "momd")!

    func testEmptyCount() throws {
        let database = Database(type: .memory, modelURL: dbURL)
        let count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertEqual(0, count)
    }

    func testCountWithRecords() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        var count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertEqual(0, count)

        let currencies = [
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()
        count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertEqual(currencies.count, count)
    }

    func testDataTypeWrapper() throws {
        let database = Database(type: .sqlite(nil), modelURL: dbURL)
        let expectedWallet = TestWallet(id: UUID().uuidString, name: "wallet 1", balance: BigInt(420))

        _ = try database.add(expectedWallet).toBlocking(timeout: unitTestsTimeout).single()

        let predicate = NSPredicate(format: "id == [c] %@", expectedWallet.id)
        let actualWallet: TestWallet? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualWallet)
        XCTAssertEqual(expectedWallet.id, actualWallet?.id)
        XCTAssertEqual(expectedWallet.name, actualWallet?.name)
        XCTAssertEqual(expectedWallet.balance, actualWallet?.balance)

        let expectedWallet2 = TestWallet(id: expectedWallet.id, name: "wallet 1", balance: BigInt(120))
        _ = try database.addOrUpdate(expectedWallet2).toBlocking(timeout: unitTestsTimeout).single()

        let actualWallet2: TestWallet? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualWallet2)
        XCTAssertEqual(expectedWallet2.id, actualWallet2?.id)
        XCTAssertEqual(expectedWallet2.name, actualWallet2?.name)
        XCTAssertEqual(expectedWallet2.balance, actualWallet2?.balance)
    }

    func testAdvancedModel() throws {
        let database = Database(type: .sqlite(nil), modelURL: dbURL)
        let expectedValue = TestAdvancedModel(customIdField: UUID().uuidString)

        _ = try database.add(expectedValue).toBlocking(timeout: unitTestsTimeout).single()

        let predicate = NSPredicate(format: "customIdField == [c] %@", expectedValue.id)
        let actualValue: TestAdvancedModel? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualValue)
        XCTAssertEqual(expectedValue.id, actualValue?.id)

        let expectedValue2 = TestAdvancedModel(customIdField: expectedValue.id)
        _ = try database.addOrUpdate(expectedValue2).toBlocking(timeout: unitTestsTimeout).single()

        let actualValue2: TestAdvancedModel? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualValue2)
        XCTAssertEqual(expectedValue2.id, actualValue2?.id)
    }

    func testFetchLimit() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        let currencies = [
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()

        let result: [TestCurrency] = try database.fetch(fetchLimit: 1)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertEqual(1, result.count)
    }

    func testFetchOffset() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        let currencies = [
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()

        let sortDescriptors = [NSSortDescriptor(key: "code", ascending: true)]

        let result: [TestCurrency] = try database.fetch(sortDescriptors: sortDescriptors, fetchLimit: 1)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        let offsetResult: [TestCurrency] = try database.fetch(
            sortDescriptors: sortDescriptors,
            fetchOffset: 1,
            fetchLimit: 1
        )
        .toBlocking(timeout: unitTestsTimeout)
        .single()

        XCTAssertEqual("ATC", result.first?.code)
        XCTAssertEqual("HTC", offsetResult.first?.code)
    }

    func testFetchOne() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        let currencies = [
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()

        var sortDescriptors = [NSSortDescriptor(key: "code", ascending: false)]
        var result: TestCurrency? = try database.fetchOne(sortDescriptors: sortDescriptors)
            .toBlocking(timeout: unitTestsTimeout)
            .single()
        XCTAssertEqual("JTC", result?.code)

        sortDescriptors = [NSSortDescriptor(key: "code", ascending: true)]
        result = try database.fetchOne(sortDescriptors: sortDescriptors)
            .toBlocking(timeout: unitTestsTimeout)
            .single()
        XCTAssertEqual("ATC", result?.code)
    }

    func testDestroy() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        _ = try database.addOrUpdate(TestCurrency(code: "HTC", name: "HISHCOIN"))
            .toBlocking(timeout: unitTestsTimeout).single()

        let sortDescriptors = [NSSortDescriptor(key: "code", ascending: false)]
        let result: TestCurrency? = try database.fetchOne(sortDescriptors: sortDescriptors)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertEqual("HTC", result?.code)

        let result2: TestCurrency? = try database.addOrUpdate(TestCurrency(code: "HTC", name: "HISHCOIN2"))
            .toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertEqual("HISHCOIN2", result2?.name)

        database.destroy()

        let result3: TestCurrency? = try database.addOrUpdate(TestCurrency(code: "HTC", name: "HISHCOIN3"))
            .toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertNil(result3)
    }

    func testBatchUpdate() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        let currencies = [
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()

        let updatedCurrencies = [
            TestCurrency(code: "ATC", name: "ANDREWCOIN2"),
            TestCurrency(code: "HTC", name: "HISHCOIN2"),
            TestCurrency(code: "JTC", name: "JOHNNYCOIN2"),
        ]

        _ = try database.update(updatedCurrencies).toBlocking(timeout: unitTestsTimeout).single()

        let fetchedCurrencies: [TestCurrency] = try database.fetch(
            sortDescriptors: [NSSortDescriptor(key: "code", ascending: true)]
        )
        .toBlocking(timeout: unitTestsTimeout)
        .single()

        XCTAssertEqual(updatedCurrencies, fetchedCurrencies)
    }
}

struct TestCurrency: DatabaseModelObject {
    let id: String
    let code: String
    let name: String
    var hashValue: Int {
        return id.hashValue
    }

    init(code: String, name: String) {
        self.code = code
        self.name = name
        id = code.lowercased()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .code)
        let name = try container.decode(String.self, forKey: .name)
        self.init(code: code, name: name)
    }

    public static func == (lhs: TestCurrency, rhs: TestCurrency) -> Bool {
        return lhs.id == rhs.id
    }
}

struct TestWallet: DatabaseModelObject {
    let id: String
    let name: String?
    let balance: BigInt
}

struct TestAdvancedModel: DatabaseModelObject {
    static let entityName = "AdvancedModelCoreData"
    static let idColumnName = "customIdField"

    var id: String { return customIdField }
    let customIdField: String
}
