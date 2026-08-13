import SwiftUI

/// The custom menu displayed from the menu-bar extra.
///
/// Float visibility belongs to the window coordinator rather than the countdown
/// model, so show/hide are injected as closures.  Countdown operations themselves
/// are intentionally routed through `CountdownStore` to keep menu-bar and float
/// state in sync.
struct CountdownMenuView: View {
    @ObservedObject private var store: CountdownStore

    private let isFloatHidden: Bool
    private let onShowFloat: () -> Void
    private let onHideFloat: () -> Void
    private let onChange: () -> Void
    private let onReset: () -> Void
    private let onCancel: (() -> Void)?
    private let onDismiss: () -> Void

    init(
        store: CountdownStore,
        isFloatHidden: Bool = false,
        onShowFloat: @escaping () -> Void = {},
        onHideFloat: @escaping () -> Void = {},
        onChange: @escaping () -> Void = {},
        onReset: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.isFloatHidden = isFloatHidden
        self.onShowFloat = onShowFloat
        self.onHideFloat = onHideFloat
        self.onChange = onChange
        self.onReset = onReset ?? { store.cancel() }
        self.onCancel = onCancel
        self.onDismiss = onDismiss
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

            MenuRow(title: "Change…") {
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

            Rectangle()
                .fill(CountdownMenuPalette.separator)
                .frame(height: 1)
                .padding(.vertical, 5.6)
                .padding(.horizontal, 11.2)

            MenuRow(title: "Cancel countdown", tint: CountdownMenuPalette.neutral400) {
                perform {
                    store.cancel()
                    onCancel?()
                }
            }
            .disabled(!store.hasCountdown)
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
