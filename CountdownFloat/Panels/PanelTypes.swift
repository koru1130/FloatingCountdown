import AppKit

/// The two standalone AppKit surfaces owned by the app.  Setup is intentionally
/// an `NSPopover` attached to the menu-bar item, not another window.
enum CountdownPanelKind {
    case float
    case completion
}

/// Shared shell for the small, borderless windows used by Countdown Float.
///
/// The panel deliberately does not paint a background.  The SwiftUI views
/// supply the glass surface, which lets their material and edge treatment
/// follow the design specification without adding a second opaque layer from
/// AppKit.
@MainActor
final class CountdownPanel: NSPanel {
    let kind: CountdownPanelKind

    init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        kind: CountdownPanelKind
    ) {
        self.kind = kind
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: true
        )

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        // Each SwiftUI shell paints the design-specific shadow (float 34 pt,
        // setup/toast 44 pt).  Disabling AppKit's generic window shadow avoids
        // stacking a second, platform-default shadow around the glass shape.
        hasShadow = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .none

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

extension CountdownPanel {
    /// Resize the panel to the measured SwiftUI content while retaining a
    /// stable origin.  `NSHostingView.fittingSize` is only reliable after a
    /// layout pass, hence the explicit `layoutSubtreeIfNeeded` call.
    func sizeToFitContent(minimumWidth: CGFloat? = nil, minimumHeight: CGFloat? = nil) {
        guard let contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        var size = contentView.fittingSize
        if let minimumWidth {
            size.width = max(size.width, minimumWidth)
        }
        if let minimumHeight {
            size.height = max(size.height, minimumHeight)
        }
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }
        setContentSize(size)
    }
}
