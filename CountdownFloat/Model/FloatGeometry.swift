import Foundation

/// The edge used when a floating panel is resized.
enum FloatScaleAnchor: Equatable {
    case center
    case topTrailing
}

/// Pure geometry helpers for the borderless floating panel.
enum FloatPanelGeometry {
    /// Distance from the visible desktop edge for the initial placement and
    /// subsequent clamping.  AppKit's coordinate system grows upward, so the
    /// top-right origin is `visible.maxY - height - margin`.
    static let defaultMargin: CGFloat = 16

    static func topTrailingOrigin(
        contentSize: CGSize,
        in visibleFrame: CGRect,
        margin: CGFloat = defaultMargin
    ) -> CGPoint {
        let inset = max(0, margin)
        let x = visibleFrame.maxX - contentSize.width - inset
        let y = visibleFrame.maxY - contentSize.height - inset
        return CGPoint(x: x, y: y)
    }

    static func topTrailingFrame(
        contentSize: CGSize,
        in visibleFrame: CGRect,
        margin: CGFloat = defaultMargin
    ) -> CGRect {
        CGRect(origin: topTrailingOrigin(contentSize: contentSize, in: visibleFrame, margin: margin), size: contentSize)
    }

    /// Clamp a frame's origin while preserving its size.  If the panel is
    /// larger than the visible frame, the origin is pinned to the nearest
    /// inset and the panel may intentionally extend beyond the opposite edge.
    static func clamped(
        _ frame: CGRect,
        to visibleFrame: CGRect,
        margin: CGFloat = defaultMargin
    ) -> CGRect {
        let inset = max(0, margin)
        let minX = visibleFrame.minX + inset
        let minY = visibleFrame.minY + inset
        let maxX = max(minX, visibleFrame.maxX - frame.width - inset)
        let maxY = max(minY, visibleFrame.maxY - frame.height - inset)

        var result = frame
        result.origin.x = min(max(frame.origin.x, minX), maxX)
        result.origin.y = min(max(frame.origin.y, minY), maxY)
        return result
    }

    /// Resize around a semantic anchor.  The old right/top edge remains fixed
    /// for `.topTrailing`; the old centre remains fixed for `.center`.
    static func resized(
        _ frame: CGRect,
        to newSize: CGSize,
        anchor: FloatScaleAnchor
    ) -> CGRect {
        let origin: CGPoint
        switch anchor {
        case .center:
            origin = CGPoint(
                x: frame.midX - newSize.width / 2,
                y: frame.midY - newSize.height / 2
            )
        case .topTrailing:
            origin = CGPoint(
                x: frame.maxX - newSize.width,
                y: frame.maxY - newSize.height
            )
        }
        return CGRect(origin: origin, size: newSize)
    }

    /// Scale a size while avoiding negative/NaN dimensions from an invalid
    /// fitting pass.  A zero result lets the caller keep its previous size.
    static func scaledSize(_ size: CGSize, by scale: CGFloat) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              scale.isFinite, scale > 0 else { return nil }
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        guard scaled.width.isFinite, scaled.height.isFinite,
              scaled.width > 0, scaled.height > 0 else { return nil }
        return scaled
    }
}
