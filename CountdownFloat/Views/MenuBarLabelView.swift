import SwiftUI

/// The app's menu-bar extra label.
///
/// The menu-bar item intentionally has no countdown state of its own.  It observes
/// `CountdownStore`, so it keeps updating while the floating panel is hidden.
struct MenuBarLabelView: View {
    @ObservedObject private var store: CountdownStore
    private let onTap: () -> Void

    init(store: CountdownStore, onTap: @escaping () -> Void = {}) {
        self.store = store
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(MenuBarPalette.accent)
                    .frame(width: 6, height: 6)

                Text(store.hasCountdown ? store.displayText : "Set")
                    .font(.system(size: 12.5, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(MenuBarPalette.accent300)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(MenuBarPalette.accent.opacity(0.16))
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(MenuBarLabelButtonStyle())
        .help(store.hasCountdown ? "Open countdown menu" : "Set countdown")
    }
}

private struct MenuBarLabelButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(MenuBarPalette.accent.opacity(configuration.isPressed ? 0.34 : (isHovered ? 0.28 : 0)))
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private enum MenuBarPalette {
    static let accent = Color(red: 0.5686, green: 0.5176, blue: 0.8510)
    static let accent300 = Color(red: 0.8235, green: 0.8078, blue: 0.9922)
}
