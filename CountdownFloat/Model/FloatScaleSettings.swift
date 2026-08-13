import Combine
import Foundation

/// Persisted user scale for the floating countdown surface.
///
/// The model deliberately lives outside `CountdownStore`: the countdown's
/// timing state is not coupled to a presentation preference, and callers can
/// inject an isolated `UserDefaults` suite in tests.  The controller observes
/// this object and updates the AppKit panel as soon as `scale` changes.
final class FloatScaleSettings: ObservableObject {
    static let minimumScale: CGFloat = 0.75
    static let maximumScale: CGFloat = 1.50
    static let step: CGFloat = 0.10
    static let defaultScale: CGFloat = 1.0
    static let defaultPersistenceKey = "floatPanel.scale"

    private let defaults: UserDefaults
    private let persistenceKey: String

    /// Values are clamped to the supported range before being persisted.
    /// Keeping the property writable makes it straightforward for a SwiftUI
    /// menu to bind a Slider or Picker directly; use `adjust(by:)` for the
    /// canonical 0.1-step controls.
    @Published var scale: CGFloat {
        didSet {
            let clamped = Self.clamped(scale)
            guard clamped != scale else {
                defaults.set(Double(scale), forKey: persistenceKey)
                return
            }

            // A setter is intentionally used instead of publishing a second
            // storage property.  `@Published` coalesces this into the final
            // value on the next run-loop turn and the recursion terminates
            // because `clamped` is idempotent.
            scale = clamped
        }
    }

    init(
        defaults: UserDefaults = .standard,
        persistenceKey: String = FloatScaleSettings.defaultPersistenceKey
    ) {
        self.defaults = defaults
        self.persistenceKey = persistenceKey

        let stored = defaults.object(forKey: persistenceKey) as? NSNumber
        let initial = stored.map { CGFloat(truncating: $0) } ?? Self.defaultScale
        _scale = Published(initialValue: Self.clamped(initial))
    }

    /// The same value-normalisation rule used by the model's setter.
    static func clamped(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return defaultScale }
        return min(max(value, minimumScale), maximumScale)
    }

    /// Set an explicit scale and return the value that was accepted.
    @discardableResult
    func setScale(_ value: CGFloat) -> CGFloat {
        scale = value
        return scale
    }

    /// Move by the supported step.  Explicit endpoints (0.75 and 1.50) are
    /// always reachable even though the range is not an integer number of
    /// 0.1 intervals from its lower bound.
    @discardableResult
    func adjust(by steps: Int) -> CGFloat {
        guard steps != 0 else { return scale }
        let next = scale + CGFloat(steps) * Self.step
        return setScale(Self.clamped(next))
    }

    @discardableResult
    func increase() -> CGFloat { adjust(by: 1) }

    @discardableResult
    func decrease() -> CGFloat { adjust(by: -1) }

    func reset() {
        scale = Self.defaultScale
    }
}
