import SwiftUI

/// Menu-bar overview for all active countdowns. Each row observes only its own
/// store and routes window operations by the store's stable identifier.
struct CountdownMenuView: View {
    @ObservedObject private var collection: CountdownCollection

    private let onAdd: () -> Void
    private let onEdit: (UUID) -> Void
    private let onToggleVisibility: (UUID) -> Void
    private let onStop: (UUID) -> Void
    private let onDismiss: () -> Void
    private let onQuit: () -> Void

    init(
        collection: CountdownCollection,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (UUID) -> Void,
        onToggleVisibility: @escaping (UUID) -> Void,
        onStop: @escaping (UUID) -> Void,
        onDismiss: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.collection = collection
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onToggleVisibility = onToggleVisibility
        self.onStop = onStop
        self.onDismiss = onDismiss
        self.onQuit = onQuit
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Countdowns")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MenuPalette.text)

                Spacer()

                Button {
                    performAndDismiss(onAdd)
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(MenuPalette.accent200)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(MenuPalette.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New countdown")
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)

            if collection.stores.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: .light))
                    Text("No active countdowns")
                        .font(.system(size: 12.5))
                }
                .foregroundStyle(MenuPalette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Divider().overlay(MenuPalette.separator)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(collection.stores, id: \.id) { store in
                            CountdownMenuTimerRow(
                                store: store,
                                onEdit: { performAndDismiss { onEdit(store.id) } },
                                onToggleVisibility: {
                                    performAndDismiss { onToggleVisibility(store.id) }
                                },
                                // Keep the menu open while its list updates.
                                onStop: { onStop(store.id) }
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 420)
            }

            Divider().overlay(MenuPalette.separator)

            Button {
                performAndDismiss(onQuit)
            } label: {
                Text("Quit Countdown Float")
                    .font(.system(size: 12.5))
                    .foregroundStyle(MenuPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .frame(width: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MenuPalette.surface.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MenuPalette.edge, lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    private func performAndDismiss(_ action: @escaping () -> Void) {
        onDismiss()
        action()
    }
}

private struct CountdownMenuTimerRow: View {
    @ObservedObject var store: CountdownStore
    let onEdit: () -> Void
    let onToggleVisibility: () -> Void
    let onStop: () -> Void

    private var title: String {
        let value = store.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? (store.isCountUp ? "Stopwatch" : "Countdown") : value
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.isCompleted ? MenuPalette.urgent : MenuPalette.accent)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MenuPalette.text)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(store.displayText)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(store.isCompleted ? MenuPalette.urgent : MenuPalette.accent200)
            }

            HStack(spacing: 4) {
                timerButton(
                    store.floatHidden ? "eye" : "eye.slash",
                    label: store.floatHidden ? "Show float" : "Hide float",
                    action: onToggleVisibility
                )
                timerButton("pencil", label: "Edit countdown", action: onEdit)
                timerButton(
                    store.isPaused ? "play.fill" : "pause.fill",
                    label: store.isPaused ? "Resume" : "Pause"
                ) {
                    store.togglePause()
                }
                .disabled(store.isCompleted)
                timerButton("plus.circle", label: "Add 5 minutes") {
                    store.addFiveMinutes()
                }
                .disabled(store.isCountUp)
                .opacity(store.isCountUp ? 0.4 : 1)

                Spacer(minLength: 2)

                timerButton("stop.fill", label: "Stop countdown", tint: MenuPalette.muted, action: onStop)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(MenuPalette.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(MenuPalette.edge, lineWidth: 1)
        )
    }

    private func timerButton(
        _ symbol: String,
        label: String,
        tint: Color = MenuPalette.text,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(MenuPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
        .help(label)
        .accessibilityLabel(label)
    }
}

private enum MenuPalette {
    static let text = Color(red: 0.9137, green: 0.9137, blue: 0.9294)
    static let muted = Color(red: 0.6980, green: 0.7137, blue: 0.7922)
    static let accent = Color(red: 0.5686, green: 0.5176, blue: 0.8510)
    static let accent200 = Color(red: 0.9059, green: 0.8980, blue: 0.9961)
    static let urgent = Color(red: 0.82, green: 0.56, blue: 0.98)
    static let surface = Color(red: 0.1373, green: 0.1451, blue: 0.1961)
    static let card = Color.white.opacity(0.045)
    static let edge = Color.white.opacity(0.12)
    static let separator = Color.white.opacity(0.10)
}
