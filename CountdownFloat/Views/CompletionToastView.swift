import SwiftUI

/// Completion affordance shown when a countdown reaches zero.
///
/// The toast is deliberately a regular SwiftUI view so the app can host it in a
/// notification-style panel (or use it in previews/tests) without coupling the
/// countdown model to a particular window implementation.
struct CompletionToastView: View {
    @ObservedObject private var store: CountdownStore

    private let onClose: () -> Void
    private let onAddFive: () -> Void
    private let onEnd: () -> Void

    init(
        store: CountdownStore,
        onClose: @escaping () -> Void = {},
        onAddFive: (() -> Void)? = nil,
        onEnd: (() -> Void)? = nil
    ) {
        self.store = store
        self.onClose = onClose
        self.onAddFive = onAddFive ?? { store.addFiveMinutes() }
        self.onEnd = onEnd ?? { store.cancel() }
    }

    private var toastTitle: String {
        let name = store.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(name.isEmpty ? "Countdown" : name) — time's up"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("COUNTDOWN")
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.88)
                    .foregroundStyle(CompletionToastPalette.accent300)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Text("✕")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CompletionToastPalette.close)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ToastCloseButtonStyle())
                .help("Close")
            }
            .padding(.bottom, 2)

            Text(toastTitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(CompletionToastPalette.text)
                .lineLimit(2)
                .padding(.bottom, 5.6)

            Text("The float keeps counting up until you end or extend it.")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(CompletionToastPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 11.2)

            HStack(spacing: 5.6) {
                ToastActionButton(title: "Add 5 min", kind: .secondary, action: onAddFive)
                ToastActionButton(title: "End", kind: .ghost, action: onEnd)
            }
        }
        .padding(.vertical, 11.2)
        .padding(.horizontal, 16.8)
        .frame(width: 300, alignment: .leading)
        // Use the same AppKit-backed dark glass as the Claude Design instead
        // of SwiftUI's adaptive material. Adaptive material turns nearly
        // white over a light desktop even though the card has a dark fill.
        .background(GlassBackground(kind: .toast))
        .environment(\.colorScheme, .dark)
        .transition(.opacity.combined(with: .offset(y: -6)))
    }
}

private struct ToastCloseButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered || configuration.isPressed ? CompletionToastPalette.text : CompletionToastPalette.close)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

private struct ToastActionButton: View {
    enum Kind: Equatable { case secondary, ghost }

    let title: String
    let kind: Kind
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(kind == .secondary ? CompletionToastPalette.text : CompletionToastPalette.accent)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background {
            if kind == .secondary {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CompletionToastPalette.accent.opacity(isPressed ? 0.22 : (isHovered ? 0.10 : 0)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(CompletionToastPalette.divider, lineWidth: 1)
                    )
            } else {
                Color.clear
            }
        }
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

private enum CompletionToastPalette {
    static let text = Color(red: 0.9137, green: 0.9137, blue: 0.9294)
    static let muted = Color(red: 0.9137, green: 0.9137, blue: 0.9294).opacity(0.55)
    static let close = Color(red: 0.4588, green: 0.4745, blue: 0.5490)
    static let accent = Color(red: 0.5686, green: 0.5176, blue: 0.8510)
    static let accent300 = Color(red: 0.8235, green: 0.8078, blue: 0.9922)
    static let divider = Color(red: 0.9137, green: 0.9137, blue: 0.9294).opacity(0.16)
}
