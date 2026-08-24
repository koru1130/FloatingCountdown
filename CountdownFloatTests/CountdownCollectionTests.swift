import XCTest
@testable import CountdownFloat

@MainActor
final class CountdownCollectionTests: XCTestCase {
    func testCollectionKeepsMultipleIndependentCountdowns() {
        let first = CountdownStore(autoStartTimer: false)
        let second = CountdownStore(autoStartTimer: false)
        let collection = CountdownCollection()

        first.start(minutes: 5, label: "Tea")
        second.start(minutes: 25, label: "Focus")
        collection.add(first)
        collection.add(second)

        XCTAssertEqual(collection.count, 2)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.label, "Tea")
        XCTAssertEqual(second.label, "Focus")

        first.pause()
        XCTAssertTrue(first.isPaused)
        XCTAssertTrue(second.isRunning)

        collection.remove(first.id)
        XCTAssertEqual(collection.stores.map(\.id), [second.id])
        XCTAssertTrue(second.isRunning)
    }

    func testCompletionEventIdentifiesItsCountdown() {
        final class Clock {
            var now = Date(timeIntervalSince1970: 1_000)
        }
        let clock = Clock()
        let store = CountdownStore(clock: { clock.now }, autoStartTimer: false)
        store.start(duration: 1)

        clock.now.addTimeInterval(2)
        store.tick()

        XCTAssertEqual(store.completionEvent?.countdownID, store.id)
    }
}
