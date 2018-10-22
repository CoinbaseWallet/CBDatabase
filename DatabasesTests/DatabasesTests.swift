// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import RxBlocking
@testable import CBDatabase
import XCTest

let unitTestsTimeout: TimeInterval = 3

class DatabasesTests: XCTestCase {
    func testEmptyCount() throws {
        let url = Bundle(for: DatabasesTests.self).url(forResource: "TestDatabase", withExtension: "momd")!
        let database = Database(type: .memory, modelURL: url)

        let count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertEqual(0, count)
    }

    func testCountWithRecords() throws {
        let url = Bundle(for: DatabasesTests.self).url(forResource: "TestDatabase", withExtension: "momd")!
        let database = Database(type: .memory, modelURL: url)

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
