import XCTest
@testable import BroadcastBrain

final class SessionStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BBTest-\(UUID())", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
        super.tearDown()
    }

    func testSaveAndReloadSession() throws {
        let store = SessionStore(storageDir: tmp)
        // Fixture sessions are seeded on empty init
        let seededCount = store.sessions.count
        XCTAssertGreaterThanOrEqual(seededCount, 2, "Expected seeded fixtures on fresh store")

        let s = Session(title: "Test Match")
        store.save(s)
        XCTAssertEqual(store.sessions.count, seededCount + 1)

        let store2 = SessionStore(storageDir: tmp)
        XCTAssertEqual(store2.sessions.count, seededCount + 1)
        XCTAssertTrue(store2.sessions.contains(where: { $0.title == "Test Match" }))
    }

    func testDeleteSession() throws {
        let store = SessionStore(storageDir: tmp)
        let s = Session(title: "To Delete")
        store.save(s)
        XCTAssertTrue(store.sessions.contains(where: { $0.id == s.id }))

        store.delete(s)
        XCTAssertFalse(store.sessions.contains(where: { $0.id == s.id }))

        let store2 = SessionStore(storageDir: tmp)
        XCTAssertFalse(store2.sessions.contains(where: { $0.id == s.id }))
    }
}
