import SwiftUI

private struct FloatLayoutScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var floatLayoutScale: CGFloat {
        get { self[FloatLayoutScaleKey.self] }
        set { self[FloatLayoutScaleKey.self] = max(0.01, newValue) }
    }
}

/// The always-on-top countdown surface.  Window movement is intentionally left
/// to the hosting NSPanel (`isMovableByWindowBackground` or its drag handler),
/// while controls remain ordinary SwiftUI buttons and therefore receive clicks
/// without initiating a panel drag.
struct FloatView: View {
    @ObservedObject var store: CountdownStore
    @Environment(\.floatLayoutScale) private var layoutScale

    /// Opens the setup/reconfigure panel from the `⋯` control.
    var onChange: (() -> Void)?
    /// Hides the float surface.  The store is deliberately not mutated here;
    /// the countdown and menu-bar extra continue running while hidden.
    var onHide: (() -> Void)?
    var alwaysShowControls: Bool
    var showsControls: Bool

    @State private var isHovered = false
    @State private var isControlsHovered = false
    @State private var pulse = false

    init(
        store: CountdownStore,
        onChange: (() -> Void)? = nil,
        onHide: (() -> Void)? = nil,
        alwaysShowControls: Bool = false,
        showsControls: Bool = true
    ) {
        self.store = store
        self.onChange = onChange
        self.onHide = onHide
        self.alwaysShowControls = alwaysShowControls
        self.showsControls = showsControls
    }

    private var statusIsCompleted: Bool { store.isCompleted }
    private var statusIsPaused: Bool { store.isPaused }
    private var isUrgent: Bool {
        // A paused countdown keeps its colour/progress frozen; it should not
        // acquire the urgent treatment merely because it is under five minutes.
        !statusIsPaused && (store.isUrgent || statusIsCompleted)
    }
    private var progress: CGFloat {
        // The design intentionally treats completion differently by display
        // mode: a bar drains to 0%, while the ring closes into a full circle.
        if statusIsCompleted {
            return store.displayMode == .ring ? 1 : 0
        }
        return min(max(CGFloat(store.progressFraction), 0), 1)
    }
    private var timeColor: Color {
        CountdownDesign.ColorToken.floatPrimaryText
    }
    private var progressColor: Color {
        isUrgent ? CountdownDesign.ColorToken.accent400 : CountdownDesign.ColorToken.accent
    }

    private var urgentScale: CGFloat {
        isUrgent ? 1.07 : 1
    }

    private var urgentScaleInset: CGFloat {
        isUrgent ? CountdownDesign.Metrics.urgentScaleInset * layoutScale : 0
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            timerSurface
            if showsControls && (alwaysShowControls || isHovered || isControlsHovered) {
                controlsPill
                    .offset(
                        x: CountdownDesign.Metrics.controlPillOverhangTrailing * layoutScale,
                        y: -CountdownDesign.Metrics.controlPillOverhangTop * layoutScale
                    )
                    .zIndex(2)
            }
        }
        // The controls intentionally overhang the glass by 11 pt at the top
        // and 8 pt at the trailing edge. Reserve transparent window content
        // for that overhang so NSPanel does not clip it at its content bounds.
        .padding(.top, CountdownDesign.Metrics.controlPillOverhangTop * layoutScale)
        .padding(.trailing, CountdownDesign.Metrics.controlPillOverhangTrailing * layoutScale)
        // `scaleEffect` is a render transform and is not reflected in the
        // NSHostingView fitting size. Add a transparent safety gutter outside
        // the transform so urgent/completed corners (and their glow) stay
        // inside the borderless panel on every display scale.
        .scaleEffect(urgentScale, anchor: .center)
        .padding(.horizontal, urgentScaleInset)
        .padding(.vertical, urgentScaleInset)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear { beginPulseIfNeeded() }
        .onChange(of: store.isCompleted) { _ in beginPulseIfNeeded() }
        .animation(.easeInOut(duration: 0.2), value: urgentScale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Countdown \(store.displayText)")
    }

    @ViewBuilder
    private var timerSurface: some View {
        switch store.displayMode {
        case .ring:
            ringSurface
        case .bar:
            barSurface
        }
    }

    private var barSurface: some View {
        VStack(alignment: .leading, spacing: CountdownDesign.Metrics.stackGap * layoutScale) {
            Text(store.displayText)
                .font(CountdownDesign.timeFont(size: 30 * layoutScale))
                .kerning(-0.6 * layoutScale)
                .foregroundColor(timeColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.disabled)

            ProgressBar(fraction: progress, color: progressColor, scale: layoutScale)

            Text(store.captionText)
                .font(.system(size: 11 * layoutScale, weight: .regular, design: .default).monospacedDigit())
                .foregroundColor(CountdownDesign.ColorToken.floatSecondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: CountdownDesign.Metrics.captionHeight * layoutScale, alignment: .leading)
                .textSelection(.disabled)
        }
        .padding(.top, CountdownDesign.Metrics.barTopPadding * layoutScale)
        .padding(.trailing, CountdownDesign.Metrics.barSidePadding * layoutScale)
        .padding(.bottom, CountdownDesign.Metrics.barBottomPadding * layoutScale)
        .padding(.leading, CountdownDesign.Metrics.barSidePadding * layoutScale)
        .background(GlassBackground(kind: .float, scale: layoutScale))
        .overlay(floatStateOverlay)
    }

    private var ringSurface: some View {
        ZStack {
            RingProgress(fraction: progress, color: progressColor, scale: layoutScale)
                .frame(
                    width: CountdownDesign.Metrics.ringSize * layoutScale,
                    height: CountdownDesign.Metrics.ringSize * layoutScale
                )
            Text(store.displayText)
                .font(CountdownDesign.timeFont(size: 20 * layoutScale))
                .kerning(-0.4 * layoutScale)
                .foregroundColor(timeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.disabled)
        }
        .frame(
            width: CountdownDesign.Metrics.floatRingWidth * layoutScale,
            height: CountdownDesign.Metrics.floatRingWidth * layoutScale
        )
        .background(GlassBackground(kind: .float, scale: layoutScale))
        .overlay(floatStateOverlay)
    }

    @ViewBuilder
    private var floatStateOverlay: some View {
        if statusIsCompleted {
            RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius * layoutScale, style: .continuous)
                .fill(CountdownDesign.ColorToken.accent.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius * layoutScale, style: .continuous)
                        .stroke(CountdownDesign.ColorToken.accent, lineWidth: 1.5 * layoutScale)
                )
                .shadow(color: CountdownDesign.ColorToken.completedGlow, radius: 34 * layoutScale)
                .opacity(pulse ? 0.85 : 0.25)
                .allowsHitTesting(false)
        } else if isUrgent {
            RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius * layoutScale, style: .continuous)
                .fill(CountdownDesign.ColorToken.accent.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius * layoutScale, style: .continuous)
                        .stroke(CountdownDesign.ColorToken.urgentBorder, lineWidth: 1.5 * layoutScale)
                )
                .shadow(color: CountdownDesign.ColorToken.urgentGlow, radius: 28 * layoutScale)
                .allowsHitTesting(false)
        }
    }

    private var controlsPill: some View {
        FloatControlsPill(scale: layoutScale, onChange: onChange, onHide: onHide)
        .onHover { isControlsHovered = $0 }
    }

    private func beginPulseIfNeeded() {
        guard statusIsCompleted else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

/// Controls rendered in real layout coordinates. `scale` multiplies every
/// metric rather than applying a visual transform, keeping the button frames
/// and SwiftUI hit regions aligned at all float sizes.
struct FloatControlsPill: View {
    var scale: CGFloat = 1
    var onChange: (() -> Void)?
    var onHide: (() -> Void)?

    var body: some View {
        HStack(spacing: 3 * scale) {
            FloatControlButton(
                systemImage: "ellipsis",
                pointSize: 12 * scale,
                size: CountdownDesign.Metrics.controlButtonSize * scale,
                accessibilityLabel: "Change countdown"
            ) {
                onChange?()
            }
            FloatControlButton(
                systemImage: "xmark",
                pointSize: 11 * scale,
                size: CountdownDesign.Metrics.controlButtonSize * scale,
                accessibilityLabel: "Hide countdown"
            ) {
                onHide?()
            }
        }
        .padding(CountdownDesign.Metrics.controlPillPadding * scale)
        .background(GlassBackground(kind: .pill))
    }
}

private struct FloatControlButton: View {
    let systemImage: String
    let pointSize: CGFloat
    let size: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: pointSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(CountdownDesign.ColorToken.text)
                .frame(width: size, height: size)
                // Keep the circular treatment while making the whole visual
                // button rectangle the hit target (including transparent
                // glyph-side pixels).
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .background(
            Circle().fill(isHovered ? CountdownDesign.ColorToken.accent.opacity(0.40) : .clear)
        )
        .clipShape(Circle())
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ProgressBar: View {
    let fraction: CGFloat
    let color: Color
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(CountdownDesign.ColorToken.track)
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: max(0, proxy.size.width * fraction))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 2 * scale)
        .clipShape(Capsule(style: .continuous))
        .accessibilityLabel("Countdown progress")
        .accessibilityValue(Text("\(Int(fraction * 100)) percent"))
    }
}

private struct RingProgress: View {
    let fraction: CGFloat
    let color: Color
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(CountdownDesign.ColorToken.ringTrack, style: StrokeStyle(lineWidth: CountdownDesign.Metrics.ringStroke * scale, lineCap: .round))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: CountdownDesign.Metrics.ringStroke * scale, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: fraction)
        }
        .accessibilityLabel("Countdown progress")
        .accessibilityValue(Text("\(Int(fraction * 100)) percent"))
    }
}
