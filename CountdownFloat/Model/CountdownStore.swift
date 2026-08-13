import Combine
import Foundation

/// The lifecycle of a countdown.
public enum CountdownStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case idle
    case running
    case paused
    case done

    /// Readable alias for clients that call the terminal state "completed".
    public static var completed: CountdownStatus { .done }
}

/// The two visual treatments supported by the float.
public enum CountdownDisplayMode: String, CaseIterable, Codable, Equatable, Sendable {
    case bar
    case ring
}

/// Compatibility aliases keep the model easy to consume from small AppKit
/// coordinators without duplicating the underlying enum.
public typealias CountdownDisplayStyle = CountdownDisplayMode
public typealias CountdownState = CountdownStatus

/// The mode used by the setup editor.
public enum CountdownInputMode: String, CaseIterable, Codable, Equatable, Sendable {
    case duration
    case atTime

    /// Compatibility spelling used by the cleaned HTML reference.
    public static var clock: CountdownInputMode { .atTime }
}

/// A small, stable event that controllers can use to react to lifecycle changes.
public enum CountdownTransition: Equatable, Sendable {
    case started
    case paused
    case resumed
    case completed
    case extended
    case cancelled
    case stopped
    case reset
}

/// Information delivered once when a running countdown crosses zero.
public struct CountdownCompletionEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let label: String
    public let endedAt: Date

    public init(id: UUID = UUID(), label: String, endedAt: Date) {
        self.id = id
        self.label = label
        self.endedAt = endedAt
    }
}

/// Main countdown model shared by the float, setup panel, menu-bar extra and
/// completion affordance.
///
/// All mutation is main-actor isolated because SwiftUI observes this object and
/// AppKit's timer also runs on the main run loop.  `clock` is injectable: tests
/// can provide a mutable date and call `tick()` without waiting for wall time.
@MainActor
public final class CountdownStore: ObservableObject {
    public typealias DateProvider = () -> Date

    // MARK: Published lifecycle state

    @Published public private(set) var status: CountdownStatus = .idle
    @Published public private(set) var now: Date
    @Published public private(set) var endAt: Date?
    @Published public private(set) var totalMilliseconds: Int64 = 0
    @Published public private(set) var frozenMilliseconds: Int64 = 0
    @Published public private(set) var remainingMilliseconds: Int64 = 0
    @Published public private(set) var progressFraction: Double = 0
    @Published public private(set) var displayText: String = "00:00"
    @Published public private(set) var captionText: String = "Set countdown"
    @Published public private(set) var isUrgent: Bool = false
    @Published public private(set) var floatHidden: Bool = false

    /// Incremented for every lifecycle transition.  This is convenient for
    /// controllers that need to trigger a one-shot animation/notification.
    @Published public private(set) var transitionID: UInt64 = 0
    @Published public private(set) var lastTransition: CountdownTransition?
    @Published public private(set) var completionEvent: CountdownCompletionEvent?

    // MARK: Setup drafts

    @Published public var inputMode: CountdownInputMode = .duration
    @Published public var displayMode: CountdownDisplayMode = .bar
    @Published public var draftMinutes: Int = 25
    @Published public var draftSpanMinutes: Int?
    @Published public var draftTargetTimeString: String
    @Published public var draftStartTimeString: String = ""
    @Published public var label: String = ""

    /// Urgent styling starts at this many minutes remaining.
    @Published public var urgentThresholdMinutes: Double = 5

    // MARK: Configuration and timer

    public let tickInterval: TimeInterval = 0.2
    private let clock: DateProvider
    private var calendar: Calendar
    private var timer: Timer?
    private var autoStartTimer: Bool

    /// Optional callback for AppKit coordinators. It is invoked on the main
    /// actor after the corresponding published values have been updated.
    public var onTransition: ((CountdownTransition) -> Void)?
    /// Convenience callback specifically for completion notifications.
    public var onCompletion: ((CountdownCompletionEvent) -> Void)?

    // MARK: Init / teardown

    public init(
        clock: @escaping DateProvider = { Date() },
        calendar: Calendar = .autoupdatingCurrent,
        autoStartTimer: Bool = true
    ) {
        self.clock = clock
        self.calendar = calendar
        self.autoStartTimer = autoStartTimer
        let initialNow = clock()
        self.now = initialNow
        self.endAt = nil
        self.draftTargetTimeString = Self.clockString(initialNow, calendar: calendar)

        if autoStartTimer {
            startTimer()
        }
    }

    /// Alternate label retained for tests and clients that naturally call the
    /// injected source a `nowProvider`.
    public convenience init(
        nowProvider: @escaping DateProvider,
        calendar: Calendar = .autoupdatingCurrent,
        autoStartTimer: Bool = true
    ) {
        self.init(clock: nowProvider, calendar: calendar, autoStartTimer: autoStartTimer)
    }

    public convenience init(
        dateProvider: @escaping DateProvider,
        calendar: Calendar = .autoupdatingCurrent,
        autoStartTimer: Bool = true
    ) {
        self.init(clock: dateProvider, calendar: calendar, autoStartTimer: autoStartTimer)
    }

    public convenience init(
        now: @escaping DateProvider,
        calendar: Calendar = .autoupdatingCurrent,
        autoStartTimer: Bool = true
    ) {
        self.init(clock: now, calendar: calendar, autoStartTimer: autoStartTimer)
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts the real 200 ms main-run-loop ticker. Safe to call repeatedly.
    public func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            // Keep the hop explicit: Timer's callback is not actor-isolated in
            // Swift 6 even though this timer is installed on RunLoop.main.
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Compatibility/read-only aliases

    public var hasCountdown: Bool { status != .idle }
    public var isRunning: Bool { status == .running }
    public var isPaused: Bool { status == .paused }
    public var isCompleted: Bool { status == .done }
    public var isDone: Bool { status == .done }
    public var displayStyle: CountdownDisplayMode {
        get { displayMode }
        set { displayMode = newValue }
    }
    public var remainingMs: Int64 { remainingMilliseconds }
    public var totalMs: Int64 { totalMilliseconds }
    public var frozenMs: Int64 { frozenMilliseconds }
    public var endDate: Date? { endAt }
    public var formattedRemaining: String { displayText }
    public var progress: Double { progressFraction }

    /// Remaining time as a signed number of seconds, useful to clients that do
    /// not need millisecond precision.
    public var remainingTimeInterval: TimeInterval {
        TimeInterval(remainingMilliseconds) / 1000
    }

    // MARK: Time / state updates

    /// Recomputes all derived state using the injected clock. Tests can pass an
    /// explicit date to make a transition deterministic.
    public func tick(at explicitDate: Date? = nil) {
        let date = explicitDate ?? clock()
        now = date

        if status == .running, let endAt, date >= endAt {
            remainingMilliseconds = Int64((endAt.timeIntervalSince(date) * 1000).rounded(.towardZero))
            status = .done
            isUrgent = false
            recomputeDerivedState()
            let event = CountdownCompletionEvent(label: label, endedAt: date)
            completionEvent = event
            emit(.completed)
            onCompletion?(event)
            return
        }

        recomputeDerivedState()
    }

    /// Alias used by a few lightweight test harnesses.
    public func refresh() { tick() }

    private func recomputeDerivedState() {
        let remaining: Int64
        switch status {
        case .idle:
            remaining = 0
        case .paused:
            remaining = frozenMilliseconds
        case .running, .done:
            guard let endAt else {
                remaining = 0
                break
            }
            remaining = Int64((endAt.timeIntervalSince(now) * 1000).rounded(.towardZero))
        }

        remainingMilliseconds = remaining
        displayText = Self.format(milliseconds: remaining)
        progressFraction = totalMilliseconds > 0
            ? min(1, max(0, Double(remaining) / Double(totalMilliseconds)))
            : 0
        let urgentWindow = max(0, urgentThresholdMinutes) * 60_000
        isUrgent = status == .running && remaining > 0 && Double(remaining) <= urgentWindow
        captionText = caption(for: status, endAt: endAt)
    }

    private func caption(for status: CountdownStatus, endAt: Date?) -> String {
        switch status {
        case .idle:
            return "Set countdown"
        case .paused:
            return "Paused"
        case .done:
            return "over time"
        case .running:
            let clock = endAt.map { Self.clockString($0, calendar: calendar) } ?? "--:--"
            let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanLabel.isEmpty ? "ends \(clock)" : "\(cleanLabel) · \(clock)"
        }
    }

    // MARK: Starting / setup draft

    /// Starts using the current setup drafts. Invalid values are clamped to the
    /// documented input ranges so a programmatic caller cannot create a broken
    /// countdown (the setup view performs friendlier validation before calling).
    public func startFromDraft() {
        let startedAt = clock()
        let target: Date
        switch inputMode {
        case .duration:
            let minutes = min(600, max(1, draftMinutes))
            target = startedAt.addingTimeInterval(TimeInterval(minutes * 60))
        case .atTime:
            target = targetDate(from: draftTargetTimeString, relativeTo: startedAt)
                ?? startedAt.addingTimeInterval(60)
        }

        var span = max(1, Int64((target.timeIntervalSince(startedAt) * 1000).rounded()))
        if inputMode == .duration, let draftSpanMinutes, draftSpanMinutes > 0 {
            span = Int64(min(1_440, max(1, draftSpanMinutes))) * 60_000
        } else if inputMode == .atTime,
                  !draftStartTimeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let start = timeOnTargetDay(from: draftStartTimeString, target: target) {
            // The reference guarantees at least one minute of visual span.
            span = max(60_000, Int64((target.timeIntervalSince(start) * 1000).rounded()))
        }

        start(endAt: target, totalMilliseconds: span, transition: .started)
    }

    /// Starts a duration in minutes, optionally overriding the progress span.
    public func start(minutes: Int, spanMinutes: Int? = nil, label: String? = nil) {
        draftMinutes = min(600, max(1, minutes))
        if let spanMinutes { draftSpanMinutes = min(1_440, max(1, spanMinutes)) }
        if let label { self.label = label }
        inputMode = .duration
        startFromDraft()
    }

    /// Starts a duration supplied in seconds.
    public func start(duration: TimeInterval, span: TimeInterval? = nil, label: String? = nil) {
        let now = clock()
        let durationMilliseconds = max(1_000, Int64((duration * 1000).rounded()))
        // A full-span reference may intentionally be shorter than the actual
        // countdown (the progress then clamps at 100% until the final span).
        let spanMilliseconds = max(1_000, Int64(((span ?? duration) * 1000).rounded()))
        if let label { self.label = label }
        start(endAt: now.addingTimeInterval(TimeInterval(durationMilliseconds) / 1000),
              totalMilliseconds: spanMilliseconds,
              transition: .started)
    }

    /// Starts until an absolute target date.
    public func start(at targetDate: Date, span: TimeInterval? = nil, label: String? = nil) {
        let now = clock()
        let durationMilliseconds = max(1_000, Int64((targetDate.timeIntervalSince(now) * 1000).rounded()))
        let spanMilliseconds = max(1_000, Int64(((span ?? TimeInterval(durationMilliseconds) / 1000) * 1000).rounded()))
        if let label { self.label = label }
        start(endAt: targetDate, totalMilliseconds: spanMilliseconds, transition: .started)
    }

    /// Naming alias for callers that prefer an explicit target-date label.
    public func start(targetDate: Date, span: TimeInterval? = nil, label: String? = nil) {
        start(at: targetDate, span: span, label: label)
    }

    private func start(
        endAt target: Date,
        totalMilliseconds span: Int64,
        transition: CountdownTransition
    ) {
        status = .running
        endAt = target
        totalMilliseconds = max(1, span)
        frozenMilliseconds = 0
        completionEvent = nil
        floatHidden = false
        tick(at: clock())
        // If a caller starts with a target already in the past, tick() will
        // produce a proper completed transition immediately.
        if status == .running {
            emit(transition)
        }
    }

    // MARK: Pause, resume, extend, stop and cancel

    public func pause() {
        guard status == .running else { return }
        tick()
        guard status == .running, let endAt else { return }
        frozenMilliseconds = max(0, Int64((endAt.timeIntervalSince(now) * 1000).rounded(.towardZero)))
        status = .paused
        recomputeDerivedState()
        emit(.paused)
    }

    public func resume() {
        guard status == .paused else { return }
        let date = clock()
        now = date
        endAt = date.addingTimeInterval(TimeInterval(frozenMilliseconds) / 1000)
        status = .running
        completionEvent = nil
        tick(at: date)
        if status == .running { emit(.resumed) }
    }

    public func togglePause() {
        if isPaused { resume() }
        else if isRunning { pause() }
        else if isCompleted { reset() }
    }

    /// Adds five minutes. For a completed countdown this resumes counting up
    /// from the current time, matching the completion toast's action.
    public func addFiveMinutes() {
        guard status != .idle else { return }
        let extensionMilliseconds: Int64 = 300_000
        let date = clock()
        now = date

        switch status {
        case .paused:
            frozenMilliseconds += extensionMilliseconds
            totalMilliseconds = max(1, totalMilliseconds + extensionMilliseconds)
            recomputeDerivedState()
            completionEvent = nil
            emit(.extended)
        case .running, .done:
            let base = max(date, endAt ?? date)
            endAt = base.addingTimeInterval(TimeInterval(extensionMilliseconds) / 1000)
            totalMilliseconds = max(1, totalMilliseconds + extensionMilliseconds)
            frozenMilliseconds = 0
            status = .running
            completionEvent = nil
            tick(at: date)
            if status == .running { emit(.extended) }
        case .idle:
            break
        }
    }

    public func cancel() {
        guard status != .idle || endAt != nil else { return }
        clearCountdown(transition: .cancelled)
    }

    /// Stops the active countdown without reopening the setup editor.
    ///
    /// `stop` intentionally has its own transition so AppKit coordinators can
    /// hide the float while keeping the setup popover closed.  Completion's
    /// existing `cancel`/`End` path remains separate and continues to emit
    /// ``CountdownTransition/cancelled``.
    public func stop() {
        guard status != .idle || endAt != nil else { return }
        clearCountdown(transition: .stopped)
    }

    public func reset() {
        guard status != .idle || endAt != nil else { return }
        clearCountdown(transition: .reset)
    }

    private func clearCountdown(transition: CountdownTransition) {
        status = .idle
        endAt = nil
        totalMilliseconds = 0
        frozenMilliseconds = 0
        remainingMilliseconds = 0
        progressFraction = 0
        displayText = "00:00"
        captionText = "Set countdown"
        isUrgent = false
        completionEvent = nil
        emit(transition)
    }

    public func setFloatHidden(_ hidden: Bool) {
        floatHidden = hidden
    }

    public func toggleFloatHidden() {
        floatHidden.toggle()
    }

    // MARK: Formatting / dates

    /// Formats signed milliseconds as `mm:ss`, `h:mm:ss`, or `+mm:ss` after
    /// completion. Seconds are rounded upward exactly as specified by handoff.
    public static func format(milliseconds: Int64) -> String {
        let negative = milliseconds < 0
        let magnitude: UInt64
        if milliseconds == Int64.min {
            magnitude = UInt64(Int64.max) + 1
        } else {
            magnitude = UInt64(abs(milliseconds))
        }
        let seconds = (magnitude + 999) / 1_000
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        let body: String
        if hours > 0 {
            body = "\(hours):" + String(format: "%02llu:%02llu", minutes, remainder)
        } else {
            body = String(format: "%02llu:%02llu", minutes, remainder)
        }
        return negative ? "+" + body : body
    }

    public func format(_ milliseconds: Int64) -> String {
        Self.format(milliseconds: milliseconds)
    }

    public func clockString(_ date: Date) -> String {
        Self.clockString(date, calendar: calendar)
    }

    private static func clockString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func targetDate(from value: String, relativeTo now: Date) -> Date? {
        guard let parts = parseClock(value) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = parts.hour
        components.minute = parts.minute
        components.second = 0
        components.nanosecond = 0
        guard var target = calendar.date(from: components) else { return nil }
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }

    private func timeOnTargetDay(from value: String, target: Date) -> Date? {
        guard let parts = parseClock(value) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: target)
        components.hour = parts.hour
        components.minute = parts.minute
        components.second = 0
        components.nanosecond = 0
        guard var start = calendar.date(from: components) else { return nil }
        // A target that rolled into tomorrow may have a start clock later than
        // its target clock. The reference treats that start as the previous
        // day, preserving the intended elapsed span across midnight.
        if start > target {
            start = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        }
        return start
    }

    private func parseClock(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func emit(_ transition: CountdownTransition) {
        lastTransition = transition
        transitionID &+= 1
        onTransition?(transition)
    }
}
