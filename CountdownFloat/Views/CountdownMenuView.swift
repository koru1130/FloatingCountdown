import SwiftUI

/// The custom menu displayed from the menu-bar extra.
///
/// Float visibility belongs to the window coordinator rather than the countdown
/// model, so show/hide are injected as closures.  Countdown operations themselves
/// are intentionally routed through `CountdownStore` to keep menu-bar and float
/// state in sync.
struct CountdownMenuView: View {
    @ObservedObject private var store: CountdownStore
    @ObservedObject private var scaleSettings: FloatScaleSettings

    private let isFloatHidden: Bool
    private let onShowFloat: () -> Void
    private let onHideFloat: () -> Void
    private let onChange: () -> Void
    private let onDecreaseFloatSize: () -> Void
    private let onResetFloatSize: () -> Void
    private let onIncreaseFloatSize: () -> Void
    private let onReset: () -> Void
    private let onStop: (() -> Void)?
    private let onDismiss: () -> Void
    private let onQuit: () -> Void

    init(
        store: CountdownStore,
        isFloatHidden: Bool = false,
        onShowFloat: @escaping () -> Void = {},
        onHideFloat: @escaping () -> Void = {},
        onChange: @escaping () -> Void = {},
        scaleSettings: FloatScaleSettings = FloatScaleSettings(),
        onDecreaseFloatSize: (() -> Void)? = nil,
        onResetFloatSize: (() -> Void)? = nil,
        onIncreaseFloatSize: (() -> Void)? = nil,
        onReset: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.store = store
        self._scaleSettings = ObservedObject(wrappedValue: scaleSettings)
        self.isFloatHidden = isFloatHidden
        self.onShowFloat = onShowFloat
        self.onHideFloat = onHideFloat
        self.onChange = onChange
        self.onDecreaseFloatSize = onDecreaseFloatSize ?? { scaleSettings.decrease() }
        self.onResetFloatSize = onResetFloatSize ?? { scaleSettings.reset() }
        self.onIncreaseFloatSize = onIncreaseFloatSize ?? { scaleSettings.increase() }
        self.onReset = onReset ?? { store.cancel() }
        // Keep accepting the old callback label for clients that construct the
        // menu directly; new callers should use `onStop`.
        self.onStop = onStop ?? onCancel
        self.onDismiss = onDismiss
        self.onQuit = onQuit
    }

    private var pauseTitle: String {
        if store.isCompleted { return "Reset" }
        return store.isPaused ? "Resume" : "Pause"
    }

    private func perform(_ action: @escaping () -> Void) {
        // Dismiss the menu before performing an action that may open the setup
        // popover.  Closing afterwards would immediately close the new popover.
        onDismiss()
        action()
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuRow(title: isFloatHidden ? "Show float" : "Hide float") {
                perform(isFloatHidden ? onShowFloat : onHideFloat)
            }

            MenuRow(title: "Edit") {
                perform(onChange)
            }

            MenuRow(title: pauseTitle) {
                if store.isCompleted {
                    perform(onReset)
                } else {
                    perform { store.togglePause() }
                }
            }
            .disabled(!store.hasCountdown)

            MenuRow(title: "Add 5 min") {
                perform { store.addFiveMinutes() }
            }
            .disabled(!store.hasCountdown)

            floatSizeRow

            Rectangle()
                .fill(CountdownMenuPalette.separator)
                .frame(height: 1)
                .padding(.vertical, 5.6)
                .padding(.horizontal, 11.2)

            MenuRow(title: "Stop", tint: CountdownMenuPalette.neutral400) {
                perform {
                    store.stop()
                    onStop?()
                }
            }
            .disabled(!store.hasCountdown)

            MenuRow(title: "Quit", tint: CountdownMenuPalette.neutral400) {
                perform(onQuit)
            }
        }
        .padding(8.4)
        .frame(width: 232)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CountdownMenuPalette.surface.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CountdownMenuPalette.edge, lineWidth: 1)
        )
        .shadow(color: CountdownMenuPalette.shadow, radius: 22, x: 0, y: 18)
        .transition(.opacity.combined(with: .offset(y: -6)))
        .animation(.easeOut(duration: 0.16), value: store.hasCountdown)
    }

    private var floatSizeRow: some View {
        HStack(spacing: 5.6) {
            Text("Float size")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(CountdownMenuPalette.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            FloatSizeButton(
                symbol: "−",
                accessibilityLabel: "Decrease float size",
                isDisabled: isAtMinimumScale
            ) {
                perform(onDecreaseFloatSize)
            }

            Button(action: { perform(onResetFloatSize) }) {
                Text(scalePercentage)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(CountdownMenuPalette.text)
                    .frame(minWidth: 42, minHeight: 28)
                    .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(CountdownMenuPalette.accent.opacity(0.14))
            )
            .accessibilityLabel("Reset float size")
            .accessibilityValue(Text("\(scalePercent) percent"))

            FloatSizeButton(
                symbol: "+",
                accessibilityLabel: "Increase float size",
                isDisabled: isAtMaximumScale
            ) {
                perform(onIncreaseFloatSize)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .padding(.vertical, 1)
        .padding(.horizontal, 11.2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Float size")
        .accessibilityValue(Text("\(scalePercent) percent"))
    }

    private var scalePercent: Int {
        Int((scaleSettings.scale * 100).rounded())
    }

    private var scalePercentage: String {
        "\(scalePercent)%"
    }

    private var isAtMinimumScale: Bool {
        scaleSettings.scale <= FloatScaleSettings.minimumScale + 0.000_1
    }

    private var isAtMaximumScale: Bool {
        scaleSettings.scale >= FloatScaleSettings.maximumScale - 0.000_1
    }
}

private struct FloatSizeButton: View {
    let symbol: String
    let accessibilityLabel: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CountdownMenuPalette.text)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CountdownMenuPalette.accent.opacity(0.14))
        )
        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MenuRow: View {
    let title: String
    var tint: Color = CountdownMenuPalette.text
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 11.2)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(CountdownMenuPalette.accent.opacity(isHovered ? 0.18 : 0))
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

private enum CountdownMenuPalette {
    static let text = Color(red: 0.9137, green: 0.9137, blue: 0.9294)
    static let neutral400 = Color(red: 0.6980, green: 0.7137, blue: 0.7922)
    static let accent = Color(red: 0.5686, green: 0.5176, blue: 0.8510)
    static let surface = Color(red: 0.1373, green: 0.1451, blue: 0.1961)
    static let edge = Color(red: 0.9137, green: 0.9137, blue: 0.9294).opacity(0.12)
    static let separator = Color(red: 0.9137, green: 0.9137, blue: 0.9294).opacity(0.10)
    static let shadow = Color.black.opacity(0.60)
}
