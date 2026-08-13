import Foundation
import XCTest
@testable import CountdownFloat

@MainActor
final class CountdownStoreTests: XCTestCase {
    /// A deterministic wall clock for the store's injected DateProvider.
    final class TestClock {
        var date: Date

        init(_ date: Date) {
            self.date = date
        }

        func advance(seconds: TimeInterval) {
            date = date.addingTimeInterval(seconds)
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int = 2024,
        month: Int = 1,
        day: Int = 1,
        hour: Int = 10,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private func makeStore(
        at start: Date,
        _ clock: TestClock
    ) -> CountdownStore {
        CountdownStore(
            clock: { clock.date },
            calendar: calendar,
            autoStartTimer: false
        )
    }

    func testFormatRoundsSecondsUpAndAddsOverflowPrefix() {
        XCTAssertEqual(CountdownStore.format(milliseconds: 0), "00:00")
        XCTAssertEqual(CountdownStore.format(milliseconds: 1), "00:01")
        XCTAssertEqual(CountdownStore.format(milliseconds: 1_001), "00:02")
        XCTAssertEqual(CountdownStore.format(milliseconds: 59_001), "01:00")
        XCTAssertEqual(CountdownStore.format(milliseconds: 3_600_000), "1:00:00")
        XCTAssertEqual(CountdownStore.format(milliseconds: -1), "+00:01")
        XCTAssertEqual(CountdownStore.format(milliseconds: -60_001), "+01:01")
    }

    func testDurationStartAndFullSpanDriveProgressAndCaption() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        store.draftMinutes = 25
        store.draftSpanMinutes = 60
        store.label = "Focus"

        store.startFromDraft()

        XCTAssertEqual(store.status, .running)
        XCTAssertEqual(store.totalMilliseconds, 3_600_000)
        XCTAssertEqual(store.remainingMilliseconds, 1_500_000)
        XCTAssertEqual(store.displayText, "25:00")
        XCTAssertEqual(store.captionText, "Focus · 10:25")
        XCTAssertEqual(store.progressFraction, 25.0 / 60.0, accuracy: 0.000_001)

        clock.advance(seconds: 20 * 60)
        store.tick()
        XCTAssertEqual(store.displayText, "05:00")
        XCTAssertTrue(store.isUrgent)
        XCTAssertEqual(store.progressFraction, 5.0 / 60.0, accuracy: 0.000_001)
    }

    func testPastTargetCountsAsTomorrow() {
        let clock = TestClock(date(hour: 23, minute: 30))
        let store = makeStore(at: clock.date, clock)
        store.inputMode = .atTime
        store.draftTargetTimeString = "23:00"

        store.startFromDraft()

        XCTAssertEqual(store.status, .running)
        XCTAssertEqual(store.endAt, date(year: 2024, month: 1, day: 2, hour: 23, minute: 0))
        XCTAssertEqual(store.remainingMilliseconds, 84_600_000)
    }

    func testStartTimeLaterThanTargetRollsStartBackOneDay() {
        let clock = TestClock(date(hour: 23, minute: 30))
        let store = makeStore(at: clock.date, clock)
        store.inputMode = .atTime
        store.draftTargetTimeString = "01:00"
        store.draftStartTimeString = "23:00"

        store.startFromDraft()

        // Target is Jan 2 01:00; 23:00 is interpreted as Jan 1 23:00.
        XCTAssertEqual(store.totalMilliseconds, 7_200_000)
        XCTAssertEqual(store.progressFraction, 0.75, accuracy: 0.000_001)
    }

    func testPauseFreezesRemainingAndResumeUsesFrozenDuration() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        store.start(minutes: 10)

        clock.advance(seconds: 150)
        store.tick()
        store.pause()
        XCTAssertEqual(store.status, .paused)
        XCTAssertEqual(store.frozenMilliseconds, 450_000)
        XCTAssertEqual(store.remainingMilliseconds, 450_000)
        XCTAssertEqual(store.displayText, "07:30")

        clock.advance(seconds: 1_800)
        store.tick()
        XCTAssertEqual(store.remainingMilliseconds, 450_000)
        XCTAssertEqual(store.displayText, "07:30")

        let resumedAt = clock.date
        store.resume()
        XCTAssertEqual(store.status, .running)
        XCTAssertEqual(store.endAt, resumedAt.addingTimeInterval(450))
    }

    func testAddFiveMinutesExtendsPausedAndRunningCountdowns() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        store.start(minutes: 10)
        clock.advance(seconds: 120)
        store.pause()

        let oldTotal = store.totalMilliseconds
        store.addFiveMinutes()
        XCTAssertEqual(store.status, .paused)
        XCTAssertEqual(store.frozenMilliseconds, 8 * 60_000 + 300_000)
        XCTAssertEqual(store.totalMilliseconds, oldTotal + 300_000)

        store.resume()
        clock.advance(seconds: 1)
        store.addFiveMinutes()
        XCTAssertEqual(store.status, .running)
        XCTAssertEqual(store.remainingMilliseconds, 8 * 60_000 + 300_000 - 1_000 + 300_000)
    }

    func testDoneEmitsOneCompletionAndContinuesCountingUp() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        var completions = [CountdownCompletionEvent]()
        store.onCompletion = { completions.append($0) }
        store.start(minutes: 1)

        clock.advance(seconds: 61)
        store.tick()

        XCTAssertEqual(store.status, .done)
        XCTAssertEqual(store.lastTransition, .completed)
        XCTAssertEqual(store.displayText, "+00:01")
        XCTAssertEqual(store.captionText, "over time")
        XCTAssertEqual(store.progressFraction, 0)
        XCTAssertEqual(completions.count, 1)
        let eventID = store.completionEvent?.id

        clock.advance(seconds: 30)
        store.tick()
        XCTAssertEqual(store.displayText, "+00:31")
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(store.completionEvent?.id, eventID)
    }

    func testAddFiveMinutesFromDoneResumesAndClearsCompletion() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        store.start(minutes: 1)
        clock.advance(seconds: 61)
        store.tick()
        XCTAssertEqual(store.status, .done)

        store.addFiveMinutes()

        XCTAssertEqual(store.status, .running)
        XCTAssertNil(store.completionEvent)
        XCTAssertEqual(store.remainingMilliseconds, 300_000)
        XCTAssertEqual(store.displayText, "05:00")
    }

    func testCancelClearsCountdownAndReturnsToSetupState() {
        let clock = TestClock(date())
        let store = makeStore(at: clock.date, clock)
        store.start(minutes: 5)
        XCTAssertTrue(store.hasCountdown)

        store.cancel()

        XCTAssertEqual(store.status, .idle)
        XCTAssertFalse(store.hasCountdown)
        XCTAssertNil(store.endAt)
        XCTAssertEqual(store.totalMilliseconds, 0)
        XCTAssertEqual(store.displayText, "00:00")
        XCTAssertEqual(store.captionText, "Set countdown")
    }
}
