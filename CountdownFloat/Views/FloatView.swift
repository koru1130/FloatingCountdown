import SwiftUI

/// The always-on-top countdown surface.  Window movement is intentionally left
/// to the hosting NSPanel (`isMovableByWindowBackground` or its drag handler),
/// while controls remain ordinary SwiftUI buttons and therefore receive clicks
/// without initiating a panel drag.
struct FloatView: View {
    @ObservedObject var store: CountdownStore

    /// Opens the setup/reconfigure panel from the `⋯` control.
    var onChange: (() -> Void)?
    /// Hides the float surface.  The store is deliberately not mutated here;
    /// the countdown and menu-bar extra continue running while hidden.
    var onHide: (() -> Void)?
    var alwaysShowControls: Bool

    @State private var isHovered = false
    @State private var pulse = false

    init(
        store: CountdownStore,
        onChange: (() -> Void)? = nil,
        onHide: (() -> Void)? = nil,
        alwaysShowControls: Bool = false
    ) {
        self.store = store
        self.onChange = onChange
        self.onHide = onHide
        self.alwaysShowControls = alwaysShowControls
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
        isUrgent ? CountdownDesign.Metrics.urgentScaleInset : 0
    }

    private var shouldShowControls: Bool {
        alwaysShowControls || isHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            timerSurface
            // Keep the pill in the layout at all times. Its opacity changes,
            // but its position and the root's padded hover region stay fixed.
            controlsPill
                .opacity(shouldShowControls ? 1 : 0)
                .offset(
                    x: CountdownDesign.Metrics.controlPillOverhangTrailing,
                    y: -CountdownDesign.Metrics.controlPillOverhangTop
                )
                .allowsHitTesting(shouldShowControls)
                .accessibilityHidden(!shouldShowControls)
                .zIndex(2)
        }
        // The controls intentionally overhang the glass by 11 pt at the top
        // and 8 pt at the trailing edge. Reserve transparent window content
        // for that overhang so NSPanel does not clip it at its content bounds.
        .padding(.top, CountdownDesign.Metrics.controlPillOverhangTop)
        .padding(.trailing, CountdownDesign.Metrics.controlPillOverhangTrailing)
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
        VStack(alignment: .leading, spacing: CountdownDesign.Metrics.stackGap) {
            Text(store.displayText)
                .font(CountdownDesign.timeFont(size: 30))
                .kerning(-0.6)
                .foregroundColor(timeColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.disabled)

            ProgressBar(fraction: progress, color: progressColor)

            Text(store.captionText)
                .font(CountdownDesign.captionFont())
                .foregroundColor(CountdownDesign.ColorToken.floatSecondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: CountdownDesign.Metrics.captionHeight, alignment: .leading)
                .textSelection(.disabled)
        }
        .padding(.top, CountdownDesign.Metrics.barTopPadding)
        .padding(.trailing, CountdownDesign.Metrics.barSidePadding)
        .padding(.bottom, CountdownDesign.Metrics.barBottomPadding)
        .padding(.leading, CountdownDesign.Metrics.barSidePadding)
        .background(GlassBackground(kind: .float))
        .overlay(floatStateOverlay)
    }

    private var ringSurface: some View {
        ZStack {
            RingProgress(fraction: progress, color: progressColor)
                .frame(width: CountdownDesign.Metrics.ringSize, height: CountdownDesign.Metrics.ringSize)
            Text(store.displayText)
                .font(CountdownDesign.timeFont(size: 20))
                .kerning(-0.4)
                .foregroundColor(timeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.disabled)
        }
        .frame(width: CountdownDesign.Metrics.floatRingWidth, height: CountdownDesign.Metrics.floatRingWidth)
        .background(GlassBackground(kind: .float))
        .overlay(floatStateOverlay)
    }

    @ViewBuilder
    private var floatStateOverlay: some View {
        if statusIsCompleted {
            RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius, style: .continuous)
                .fill(CountdownDesign.ColorToken.accent.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius, style: .continuous)
                        .stroke(CountdownDesign.ColorToken.accent, lineWidth: 1.5)
                )
                .shadow(color: CountdownDesign.ColorToken.completedGlow, radius: 34)
                .opacity(pulse ? 0.85 : 0.25)
                .allowsHitTesting(false)
        } else if isUrgent {
            RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius, style: .continuous)
                .fill(CountdownDesign.ColorToken.accent.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: CountdownDesign.Metrics.floatRadius, style: .continuous)
                        .stroke(CountdownDesign.ColorToken.accent400, lineWidth: 1.5)
                )
                .shadow(color: CountdownDesign.ColorToken.urgentGlow, radius: 28)
                .allowsHitTesting(false)
        }
    }

    private var controlsPill: some View {
        HStack(spacing: 3) {
            FloatControlButton(systemImage: "ellipsis", pointSize: 12, accessibilityLabel: "Change countdown") {
                onChange?()
            }
            FloatControlButton(systemImage: "xmark", pointSize: 11, accessibilityLabel: "Hide countdown") {
                onHide?()
            }
        }
        .padding(CountdownDesign.Metrics.controlPillPadding)
        .background(GlassBackground(kind: .pill))
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

private struct FloatControlButton: View {
    let systemImage: String
    let pointSize: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: pointSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(CountdownDesign.ColorToken.text)
                .frame(width: CountdownDesign.Metrics.controlButtonSize, height: CountdownDesign.Metrics.controlButtonSize)
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
        .frame(width: CountdownDesign.Metrics.controlButtonSize, height: CountdownDesign.Metrics.controlButtonSize)
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
        .frame(height: 2)
        .clipShape(Capsule(style: .continuous))
        .accessibilityLabel("Countdown progress")
        .accessibilityValue(Text("\(Int(fraction * 100)) percent"))
    }
}

private struct RingProgress: View {
    let fraction: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(CountdownDesign.ColorToken.ringTrack, style: StrokeStyle(lineWidth: CountdownDesign.Metrics.ringStroke, lineCap: .round))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: CountdownDesign.Metrics.ringStroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: fraction)
        }
        .accessibilityLabel("Countdown progress")
        .accessibilityValue(Text("\(Int(fraction * 100)) percent"))
    }
}
