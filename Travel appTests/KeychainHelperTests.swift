import XCTest
@testable import Travel_app

final class KeychainHelperTests: XCTestCase {
    private let testKey = "test_keychain_helper_key"

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndReadString() {
        let saved = KeychainHelper.save(key: testKey, string: "hello")
        XCTAssertTrue(saved)
        let result = KeychainHelper.readString(key: testKey)
        XCTAssertEqual(result, "hello")
    }

    func testReadNonexistentKey() {
        let result = KeychainHelper.readString(key: "nonexistent_key_12345")
        XCTAssertNil(result)
    }

    func testDeleteKey() {
        KeychainHelper.save(key: testKey, string: "to_delete")
        let deleted = KeychainHelper.delete(key: testKey)
        XCTAssertTrue(deleted)
        XCTAssertNil(KeychainHelper.readString(key: testKey))
    }

    func testOverwriteExistingKey() {
        KeychainHelper.save(key: testKey, string: "first")
        KeychainHelper.save(key: testKey, string: "second")
        XCTAssertEqual(KeychainHelper.readString(key: testKey), "second")
    }

    func testSaveAndReadData() {
        let data = "binary data".data(using: .utf8)!
        let saved = KeychainHelper.save(key: testKey, data: data)
        XCTAssertTrue(saved)
        let result = KeychainHelper.read(key: testKey)
        XCTAssertEqual(result, data)
    }
}
