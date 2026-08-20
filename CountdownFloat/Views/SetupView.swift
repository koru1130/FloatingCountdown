import SwiftUI

/// The countdown editor displayed inside the menu-bar setup popover.
///
/// Draft values live in `CountdownStore` so the menu-bar item, setup panel and
/// floating window all observe the same state.  The small local string buffers
/// intentionally allow a user to clear a numeric field while typing; the
/// store receives the value as soon as it becomes parseable.
struct SetupView: View {
    @ObservedObject private var store: CountdownStore

    @State private var inputMode: CountdownInputMode
    @State private var displayMode: CountdownDisplayMode
    @State private var minutesText: String
    @State private var spanText: String
    @State private var targetTimeText: String
    @State private var startTimeText: String
    @State private var labelText: String
    @FocusState private var focusedField: InputField?

    private let isEditing: Bool
    private let onCancel: () -> Void
    private let onStart: () -> Void

    private enum InputField: Hashable {
        case minutes, span, target, start, label
    }

    init(
        store: CountdownStore,
        isEditing: Bool = false,
        onCancel: @escaping () -> Void = {},
        onStart: @escaping () -> Void = {}
    ) {
        _store = ObservedObject(wrappedValue: store)
        _inputMode = State(initialValue: store.inputMode)
        _displayMode = State(initialValue: store.displayMode)
        _minutesText = State(initialValue: store.draftMinutes > 0 ? String(store.draftMinutes) : "")
        _spanText = State(initialValue: store.draftSpanMinutes.map(String.init) ?? "")
        _targetTimeText = State(initialValue: store.draftTargetTimeString)
        _startTimeText = State(initialValue: store.draftStartTimeString)
        _labelText = State(initialValue: store.label)
        self.isEditing = isEditing
        self.onCancel = onCancel
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                header
                editingControls
            } else {
                header
                modeSwitch

                if inputMode == .duration {
                    durationFields
                } else if inputMode == .atTime {
                    atATimeFields
                } else {
                    countUpInfo
                }

                labelField
                if inputMode != .countUp {
                    floatStyle
                }
                footer
            }
        }
        .padding(16.8)
        .frame(width: 312)
        // Use the exact same material/fill stack as the float.  The two fill
        // tokens are aliases, so their depth cannot drift apart again.
        .background(GlassBackground(kind: .panel))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onAppear(perform: syncDraftStrings)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Text(isEditing ? "Edit countdown" : "New countdown")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tracking(-0.24)
                .foregroundColor(Self.text)

            Spacer(minLength: 0)

            if isEditing {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Self.neutral400)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close edit panel")
                .help("Close edit panel")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isEditing ? 24 : 19)
        .padding(.bottom, 11.2)
    }

    private var modeSwitch: some View {
        HStack(spacing: 3) {
            modeButton("At a time", isSelected: inputMode == .atTime) {
                inputMode = .atTime
                focusedField = .target
            }
            modeButton("Duration", isSelected: inputMode == .duration) {
                inputMode = .duration
                focusedField = .minutes
            }
            modeButton("Count up", isSelected: inputMode == .countUp) {
                inputMode = .countUp
                displayMode = .bar
                focusedField = .label
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.23))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.bottom, 16.8)
    }

    private var editingControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 5.6) {
                Text("LABEL")
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.88)
                    .foregroundStyle(Self.text55)

                textInput(
                    text: $labelText,
                    field: .label,
                    placeholder: "Label (optional)",
                    onChange: updateLabel
                )
            }

            HStack(spacing: 8) {
                editorActionButton(
                    pauseActionTitle,
                    systemImage: pauseActionSymbol
                ) {
                    store.togglePause()
                }
                .disabled(store.isCompleted)
                .opacity(store.isCompleted ? 0.45 : 1)

                editorActionButton("Add 5 min", systemImage: "plus") {
                    store.addFiveMinutes()
                }
                .disabled(store.isCountUp)
                .opacity(store.isCountUp ? 0.45 : 1)
            }
        }
    }

    private var pauseActionTitle: String {
        return store.isPaused ? "Resume" : "Pause"
    }

    private var pauseActionSymbol: String {
        return store.isPaused ? "play.fill" : "pause.fill"
    }

    private func editorActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Self.accent200)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Self.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var durationFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 11.2) {
                HStack(spacing: 5.6) {
                    ForEach([5, 15, 25, 60], id: \.self) { preset in
                        chip("\(preset)m", selected: validMinutes == preset) {
                            minutesText = String(preset)
                            focusedField = nil
                        }
                    }
                }

                HStack(spacing: 8.4) {
                    Text("Custom")
                        .font(Self.fieldFont)
                        .foregroundColor(Self.neutral400)
                    numericField(
                        text: $minutesText,
                        field: .minutes,
                        width: 84,
                        placeholder: "—",
                        onChange: updateMinutes
                    )
                    Text("min")
                        .font(Self.fieldFont)
                        .foregroundColor(Self.neutral400)
                }

                if let error = minutesError {
                    validationText(error)
                }
            }
            .padding(.bottom, 11.2)

            VStack(alignment: .leading, spacing: 5.6) {
                HStack(spacing: 8.4) {
                    Text("Full span")
                        .font(Self.fieldFont)
                        .foregroundColor(Self.neutral400)
                    numericField(
                        text: $spanText,
                        field: .span,
                        width: 84,
                        placeholder: "—",
                        onChange: updateSpan
                    )
                    Text("min")
                        .font(Self.fieldFont)
                        .foregroundColor(Self.neutral400)
                }
                Text("Optional — what a full bar or ring stands for. Blank uses the whole countdown.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Self.text55)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 11.2)
        }
    }

    private var atATimeFields: some View {
        VStack(alignment: .leading, spacing: 5.6) {
            textInput(
                text: $targetTimeText,
                field: .target,
                placeholder: "HH:mm",
                font: .system(size: 17, weight: .regular, design: .monospaced),
                onChange: updateTargetTime
            )
            Text("A time already past counts as tomorrow.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(Self.text55)

            HStack(spacing: 8.4) {
                Text("Start time")
                    .font(Self.fieldFont)
                    .foregroundColor(Self.neutral400)
                textInput(
                    text: $startTimeText,
                    field: .start,
                    placeholder: "HH:mm",
                    width: 108,
                    font: .system(size: 14, weight: .regular, design: .monospaced),
                    onChange: updateStartTime
                )
            }
            Text("Optional — only used to size the bar or ring. Blank uses the whole countdown.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(Self.text55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 11.2)
    }

    private var countUpInfo: some View {
        HStack(spacing: 10) {
            Image(systemName: "stopwatch")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Self.accent200)

            VStack(alignment: .leading, spacing: 3) {
                Text("Starts at 00:00")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.text)
                Text("Keeps counting upward until you stop it.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Self.text55)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Self.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Self.divider, lineWidth: 1)
        )
        .padding(.bottom, 11.2)
    }

    private var labelField: some View {
        textInput(
            text: $labelText,
            field: .label,
            placeholder: "Label (optional)",
            onChange: updateLabel
        )
        .padding(.bottom, 11.2)
    }

    private var floatStyle: some View {
        VStack(alignment: .leading, spacing: 5.6) {
            Text("FLOAT STYLE")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.88)
                .foregroundColor(Self.text55)

            HStack(spacing: 5.6) {
                chip("Bar", selected: displayMode == .bar) {
                    displayMode = .bar
                }
                chip("Ring", selected: displayMode == .ring) {
                    displayMode = .ring
                }
            }
        }
        .padding(.bottom, 16.8)
    }

    private var footer: some View {
        HStack(spacing: 8.4) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Self.neutral400)
                .padding(.horizontal, 4)

            Button(action: start) {
                Text("Start")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Self.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(OutlineStartButtonStyle())
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)

            Text(startHint)
                .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                .foregroundColor(Self.text55)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Controls

    private func modeButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isSelected ? Self.text : Self.neutral500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Self.accent.opacity(0.26) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(selected ? Self.accent200 : Self.neutral400)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selected ? Self.accent.opacity(0.22) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(selected ? Self.accent : Self.divider, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func numericField(
        text: Binding<String>,
        field: InputField,
        width: CGFloat,
        placeholder: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        textInput(
            text: text,
            field: field,
            placeholder: placeholder,
            width: width,
            alignment: .trailing,
            font: .system(size: 14, weight: .regular, design: .monospaced),
            onChange: onChange
        )
    }

    private func textInput(
        text: Binding<String>,
        field: InputField,
        placeholder: String,
        width: CGFloat? = nil,
        alignment: TextAlignment = .leading,
        font: Font = .system(size: 14, weight: .regular),
        onChange: @escaping (String) -> Void
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder).foregroundColor(Self.text55)
        )
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .foregroundColor(Self.text)
            .tint(Self.accent)
            .padding(.horizontal, 10)
            .frame(width: width)
            .frame(minHeight: 36)
            .background(Self.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(focusedField == field ? Self.accent : Self.divider, lineWidth: focusedField == field ? 1.5 : 1)
            }
            .focused($focusedField, equals: field)
            .onChange(of: text.wrappedValue, perform: onChange)
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .regular))
            .foregroundColor(Self.accent400)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Draft and validation

    private func syncDraftStrings() {
        inputMode = store.inputMode
        displayMode = store.displayMode
        minutesText = store.draftMinutes > 0 ? String(store.draftMinutes) : ""
        spanText = store.draftSpanMinutes.map(String.init) ?? ""
        targetTimeText = store.draftTargetTimeString
        startTimeText = store.draftStartTimeString
        labelText = store.label
    }

    private func updateMinutes(_ value: String) {
        _ = value
    }

    private func updateSpan(_ value: String) {
        _ = value
    }

    private func updateTargetTime(_ value: String) {
        _ = value
    }

    private func updateStartTime(_ value: String) {
        _ = value
    }

    private func updateLabel(_ value: String) {
        if isEditing {
            store.updatePresentation(label: value, displayMode: store.displayMode)
        }
    }

    private var validMinutes: Int? {
        guard let value = Int(minutesText), (1...600).contains(value) else { return nil }
        return value
    }

    private var validSpan: Int? {
        guard !spanText.isEmpty else { return nil }
        guard let value = Int(spanText), (1...1440).contains(value) else { return nil }
        return value
    }

    private var validTarget: Date? {
        guard inputMode != .countUp else { return nil }
        guard inputMode == .duration || parseClock(targetTimeText) != nil else { return nil }
        guard inputMode == .atTime, let time = parseClock(targetTimeText) else {
            return Date().addingTimeInterval(TimeInterval((validMinutes ?? 0) * 60))
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        guard var target = calendar.date(from: components) else { return nil }
        if target <= now { target = calendar.date(byAdding: .day, value: 1, to: target) ?? target }
        return target
    }

    private var minutesError: String? {
        guard !minutesText.isEmpty else { return "Enter 1–600 minutes." }
        guard validMinutes != nil else { return "Minutes must be between 1 and 600." }
        return nil
    }

    private var isValid: Bool {
        switch inputMode {
        case .duration:
            return validMinutes != nil && (spanText.isEmpty || validSpan != nil)
        case .atTime:
            return validTarget != nil
        case .countUp:
            return true
        }
    }

    private var startHint: String {
        if inputMode == .countUp { return "00:00 ↑" }
        guard isValid, let target = validTarget else { return "—" }
        let duration = max(1, Int(ceil(target.timeIntervalSinceNow)))
        let text = formatDuration(duration)
        if inputMode == .atTime { return text }
        return "\(text) · ends \(clockString(target))"
    }

    private func start() {
        guard isValid else { return }
        store.inputMode = inputMode
        store.displayMode = displayMode
        store.draftMinutes = validMinutes ?? store.draftMinutes
        store.draftSpanMinutes = validSpan
        store.draftTargetTimeString = targetTimeText
        store.draftStartTimeString = startTimeText
        store.label = labelText
        store.startFromDraft()
        onStart()
    }

    private func parseClock(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private func clockString(_ date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remainder) }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    // MARK: - Appearance

    private struct OutlineStartButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 145 / 255, green: 132 / 255, blue: 217 / 255), lineWidth: 1)
                }
                .background(
                    Color(red: 145 / 255, green: 132 / 255, blue: 217 / 255)
                        .opacity(configuration.isPressed ? 0.22 : 0.0)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
        }
    }

    private static let text = Color(red: 233 / 255, green: 233 / 255, blue: 237 / 255)
    private static let text55 = text.opacity(0.55)
    private static let neutral400 = Color(red: 178 / 255, green: 182 / 255, blue: 202 / 255)
    private static let neutral500 = Color(red: 147 / 255, green: 151 / 255, blue: 171 / 255)
    private static let accent = Color(red: 145 / 255, green: 132 / 255, blue: 217 / 255)
    private static let accent200 = Color(red: 231 / 255, green: 229 / 255, blue: 254 / 255)
    private static let accent400 = Color(red: 181 / 255, green: 171 / 255, blue: 252 / 255)
    private static let surface = Color(red: 35 / 255, green: 37 / 255, blue: 50 / 255)
    private static let divider = text.opacity(0.16)
    private static let fieldFont = Font.system(size: 12.5, weight: .regular)
}
