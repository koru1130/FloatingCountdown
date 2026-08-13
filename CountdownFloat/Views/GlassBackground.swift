import AppKit
import SwiftUI

/// `clipShape` around an `NSViewRepresentable` is not sufficient on every
/// macOS release: `NSVisualEffectView` can still sample/draw across its full
/// rectangular host bounds.  Mask the AppKit layer itself so the blur never
/// leaks beyond the rounded glass surface.
final class RoundedVisualEffectView: NSVisualEffectView {
    var clippingRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = clippingRadius
            needsLayout = true
        }
    }

    private let clippingMask = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        installClippingMask()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installClippingMask()
    }

    private func installClippingMask() {
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.mask = clippingMask
        clippingMask.fillRule = .nonZero
        clippingMask.needsDisplayOnBoundsChange = true
        updateClippingMask()
    }

    override func layout() {
        super.layout()
        updateClippingMask()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clippingMask.contentsScale = window?.backingScaleFactor ?? 2
        updateClippingMask()
    }

    private func updateClippingMask() {
        guard let layer else { return }
        let maskBounds = layer.bounds
        clippingMask.frame = maskBounds
        clippingMask.bounds = maskBounds
        let radius = min(clippingRadius, min(maskBounds.width, maskBounds.height) / 2)
        clippingMask.path = CGPath(
            roundedRect: maskBounds,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        layer.cornerRadius = radius
    }
}

/// A lightweight NSVisualEffectView bridge.  Native vibrancy is preferable to
/// a hand-rolled blur because it follows the window's actual screen backdrop.
struct CountdownVisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> RoundedVisualEffectView {
        let view = RoundedVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.clippingRadius = cornerRadius
        return view
    }

    func updateNSView(_ nsView: RoundedVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.clippingRadius = cornerRadius
    }
}

/// Shared frosted-glass shell.  The shape is supplied by the content's frame,
/// so it can be reused for the intrinsic-width bar and fixed-size ring.
struct GlassBackground: View {
    enum Kind: Equatable {
        case float
        case panel
        case pill
        case toast

        var radius: CGFloat {
            switch self {
            case .pill: return 999
            default: return CountdownDesign.Metrics.floatRadius
            }
        }

        var fill: Color {
            switch self {
            case .float: return CountdownDesign.ColorToken.floatFill
            case .panel: return CountdownDesign.ColorToken.panelFill
            case .pill: return CountdownDesign.ColorToken.pillFill
            case .toast: return CountdownDesign.ColorToken.toastFill
            }
        }

        var edge: Color {
            switch self {
            case .toast: return CountdownDesign.ColorToken.accent.opacity(0.50)
            case .pill: return CountdownDesign.ColorToken.text.opacity(0.14)
            default: return CountdownDesign.ColorToken.hairline
            }
        }

        var material: NSVisualEffectView.Material {
            switch self {
            case .pill: return .popover
            case .toast: return .hudWindow
            default: return .hudWindow
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .pill: return 16
            case .toast: return 44
            case .panel: return 44
            case .float: return 34
            }
        }

        var shadowY: CGFloat {
            switch self {
            case .pill: return 6
            case .float: return 14
            default: return 18
            }
        }
    }

    let kind: Kind

    init(kind: Kind = .float) {
        self.kind = kind
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind.radius, style: .continuous)
        let surface = shape
            .fill(kind.fill)
            .background(
                CountdownVisualEffect(
                    material: kind.material,
                    blendingMode: .behindWindow,
                    cornerRadius: kind.radius
                )
                    .clipShape(shape)
            )
            // Keep the hairline inset. A centered stroke can draw a half-pixel
            // outside the host bounds and expose a rectangular visual-effect
            // seam on the leading edge.
            .overlay(shape.strokeBorder(kind.edge, lineWidth: 1))
            // This final clip is intentional even though the SwiftUI shape is
            // already rounded: NSVisualEffectView is AppKit-backed and may
            // otherwise sample across its rectangular representable bounds.
            .clipShape(shape)

        if kind == .toast {
            surface.shadow(
                color: Color.black.opacity(0.60),
                radius: kind.shadowRadius,
                x: 0,
                y: kind.shadowY
            )
        } else {
            // Float/pill sit against a tightly-fitted transparent NSPanel;
            // panel sits inside an NSPopover that supplies its own shadow.
            // Drawing another large shadow here clips into rectangular strips.
            surface
        }
    }
}
