import SwiftUI

/// The small, resolved visual language shared by the floating timer and its
/// supporting glass surfaces.  Values intentionally mirror the handoff spec
/// rather than relying on system colours that can vary between macOS releases.
enum CountdownDesign {
    enum ColorToken {
        static let text = Color(red: 233 / 255, green: 233 / 255, blue: 237 / 255)
        // The float now sits over real desktop content rather than the dark
        // reference ground.  Keep its high-salience copy a little brighter
        // than the shared text token so the translucent shell remains legible
        // on light wallpapers as well.
        static let floatPrimaryText = Color(red: 246 / 255, green: 246 / 255, blue: 250 / 255)
        static let floatSecondaryText = Color(red: 239 / 255, green: 239 / 255, blue: 244 / 255).opacity(0.74)
        static let text55 = text.opacity(0.55)
        static let text45 = text.opacity(0.45)
        static let divider = text.opacity(0.16)
        static let hairline = text.opacity(0.13)
        static let separator = text.opacity(0.10)
        static let track = text.opacity(0.13)
        static let ringTrack = text.opacity(0.14)
        static let neutral400 = Color(red: 178 / 255, green: 182 / 255, blue: 202 / 255)
        static let neutral500 = Color(red: 147 / 255, green: 151 / 255, blue: 171 / 255)
        static let neutral600 = Color(red: 117 / 255, green: 121 / 255, blue: 140 / 255)
        static let surface = Color(red: 35 / 255, green: 37 / 255, blue: 50 / 255)
        static let accent = Color(red: 145 / 255, green: 132 / 255, blue: 217 / 255)
        static let accent400 = Color(red: 181 / 255, green: 171 / 255, blue: 252 / 255)
        static let accent300 = Color(red: 210 / 255, green: 206 / 255, blue: 253 / 255)
        static let accent200 = Color(red: 231 / 255, green: 229 / 255, blue: 254 / 255)
        // Keep enough of the real desktop backdrop visible to read as glass.
        // The previous 0.86 fill was effectively opaque against a light
        // wallpaper.  Setup remains intentionally denser while the float is
        // the always-on-top, translucent surface.
        static let floatFill = Color(red: 35 / 255, green: 37 / 255, blue: 50 / 255).opacity(0.72)
        static let panelFill = Color(red: 35 / 255, green: 37 / 255, blue: 50 / 255).opacity(0.86)
        static let pillFill = Color(red: 22 / 255, green: 24 / 255, blue: 38 / 255).opacity(0.82)
        static let toastFill = Color(red: 35 / 255, green: 37 / 255, blue: 50 / 255).opacity(0.90)
        static let urgentGlow = Color(red: 181 / 255, green: 171 / 255, blue: 252 / 255).opacity(0.40)
        static let completedGlow = Color(red: 145 / 255, green: 132 / 255, blue: 217 / 255).opacity(0.55)
    }

    enum Metrics {
        static let floatRadius: CGFloat = 14
        static let barTopPadding: CGFloat = 13
        static let barSidePadding: CGFloat = 16
        static let barBottomPadding: CGFloat = 12
        static let ringSize: CGFloat = 82
        static let floatRingWidth: CGFloat = 108
        static let ringStroke: CGFloat = 6
        static let stackGap: CGFloat = 7
        static let captionHeight: CGFloat = 16
        static let controlPillPadding: CGFloat = 3
        static let controlButtonSize: CGFloat = 20
        // `scaleEffect(1.07)` is a rendering transform and does not contribute
        // to SwiftUI's fitting size.  Reserve this transparent room before
        // the host panel is measured so urgent/completed corners cannot clip.
        static let urgentScaleInset: CGFloat = 8
    }

    static func timeFont(size: CGFloat) -> Font {
        // Keep the system/Inter-like sans glyphs, while forcing tabular figures
        // so a ticking digit never changes the float's measured width.
        .system(size: size, weight: .medium, design: .default).monospacedDigit()
    }

    static func captionFont() -> Font {
        .system(size: 11, weight: .regular, design: .default).monospacedDigit()
    }
}
