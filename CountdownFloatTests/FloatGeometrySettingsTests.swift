import Foundation
import XCTest
@testable import CountdownFloat

final class FloatGeometrySettingsTests: XCTestCase {
    func testTopTrailingOriginUsesVisibleMaxYAndMargin() {
        let visible = CGRect(x: 100, y: 80, width: 1_440, height: 900)
        let origin = FloatPanelGeometry.topTrailingOrigin(
            contentSize: CGSize(width: 240, height: 120),
            in: visible,
            margin: 16
        )

        XCTAssertEqual(origin.x, visible.maxX - 240 - 16)
        XCTAssertEqual(origin.y, visible.maxY - 120 - 16)
    }

    func testResizeAnchorsKeepCenterOrTopTrailingEdge() {
        let oldFrame = CGRect(x: 400, y: 300, width: 200, height: 100)
        let newSize = CGSize(width: 300, height: 150)

        let centered = FloatPanelGeometry.resized(oldFrame, to: newSize, anchor: .center)
        XCTAssertEqual(centered.midX, oldFrame.midX, accuracy: 0.000_1)
        XCTAssertEqual(centered.midY, oldFrame.midY, accuracy: 0.000_1)

        let topTrailing = FloatPanelGeometry.resized(oldFrame, to: newSize, anchor: .topTrailing)
        XCTAssertEqual(topTrailing.maxX, oldFrame.maxX, accuracy: 0.000_1)
        XCTAssertEqual(topTrailing.maxY, oldFrame.maxY, accuracy: 0.000_1)
    }

    func testClampingRespectsVisibleFrameInset() {
        let visible = CGRect(x: 0, y: 0, width: 800, height: 600)
        let frame = CGRect(x: -100, y: 700, width: 200, height: 100)
        let clamped = FloatPanelGeometry.clamped(frame, to: visible, margin: 16)

        XCTAssertEqual(clamped.minX, 16, accuracy: 0.000_1)
        XCTAssertEqual(clamped.minY, 484, accuracy: 0.000_1)
    }

    func testScaledSizeUsesOneUserScaleWithoutChangingAspect() {
        let base = CGSize(width: 116, height: 84)

        XCTAssertEqual(
            FloatPanelGeometry.scaledSize(base, by: 0.75),
            CGSize(width: 87, height: 63)
        )
        XCTAssertEqual(
            FloatPanelGeometry.scaledSize(base, by: 1.5),
            CGSize(width: 174, height: 126)
        )
        XCTAssertNil(FloatPanelGeometry.scaledSize(base, by: 0))
        XCTAssertNil(FloatPanelGeometry.scaledSize(.zero, by: 1))
    }

    func testScaleSettingsClampPersistAndAdjustByStep() {
        let suiteName = "FloatGeometrySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = FloatScaleSettings(defaults: defaults, persistenceKey: "scale")
        XCTAssertEqual(settings.scale, FloatScaleSettings.defaultScale)

        settings.scale = 99
        XCTAssertEqual(settings.scale, FloatScaleSettings.maximumScale)
        XCTAssertEqual(defaults.double(forKey: "scale"), Double(FloatScaleSettings.maximumScale))

        settings.scale = 0
        XCTAssertEqual(settings.scale, FloatScaleSettings.minimumScale)
        settings.scale = 1
        XCTAssertEqual(settings.increase(), 1.1, accuracy: 0.000_1)

        settings.scale = 1.45
        XCTAssertEqual(settings.increase(), FloatScaleSettings.maximumScale, accuracy: 0.000_1)
        settings.scale = 0.80
        XCTAssertEqual(settings.decrease(), FloatScaleSettings.minimumScale, accuracy: 0.000_1)

        let restored = FloatScaleSettings(defaults: defaults, persistenceKey: "scale")
        XCTAssertEqual(restored.scale, FloatScaleSettings.minimumScale, accuracy: 0.000_1)
    }

    func testScrollZoomUsesWheelNotchesAndAccumulatesPreciseDeltas() {
        var accumulator = FloatScrollZoomAccumulator()

        XCTAssertEqual(accumulator.steps(for: 1, hasPreciseDeltas: false), 1)
        XCTAssertEqual(accumulator.steps(for: -1, hasPreciseDeltas: false), -1)

        XCTAssertEqual(accumulator.steps(for: 10, hasPreciseDeltas: true), 0)
        XCTAssertEqual(accumulator.steps(for: 13, hasPreciseDeltas: true), 0)
        XCTAssertEqual(accumulator.steps(for: 2, hasPreciseDeltas: true), 1)
        XCTAssertEqual(accumulator.steps(for: -48, hasPreciseDeltas: true), -2)

        accumulator.reset()
        XCTAssertEqual(accumulator.steps(for: 23, hasPreciseDeltas: true), 0)
    }

    @MainActor
    func testFloatPanelAndContentBoundsGrowWithScale() {
        let suiteName = "FloatPanelScaleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = FloatScaleSettings(defaults: defaults, persistenceKey: "scale")
        let controller = FloatPanelController(
            store: CountdownStore(autoStartTimer: false),
            scaleSettings: settings
        )
        controller.refreshLayout()
        let originalSize = controller.panel.frame.size

        controller.setScale(1.5)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(
            controller.panel.frame.width,
            originalSize.width * 1.5,
            accuracy: 1
        )
        XCTAssertEqual(
            controller.panel.frame.height,
            originalSize.height * 1.5,
            accuracy: 1
        )
        XCTAssertEqual(
            controller.panel.contentView?.bounds.size,
            controller.panel.contentLayoutRect.size
        )
        XCTAssertEqual(
            controller.panel.contentView?.frame.size,
            controller.panel.contentLayoutRect.size
        )
        XCTAssertTrue(controller.panel.contentView is FloatPanelContentView)

        guard let hostedContent = controller.panel.contentView?.subviews.first else {
            return XCTFail("Expected a hosted countdown view")
        }
        XCTAssertEqual(hostedContent.frame.size, controller.panel.contentLayoutRect.size)
        XCTAssertEqual(hostedContent.bounds.size, controller.panel.contentLayoutRect.size)
    }

    @MainActor
    func testScaledControlHitRegionsFollowVisualButtons() throws {
        let suiteName = "FloatControlHitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var changeCount = 0
        var hideCount = 0
        let settings = FloatScaleSettings(defaults: defaults, persistenceKey: "scale")
        let controller = FloatPanelController(
            store: CountdownStore(autoStartTimer: false),
            scaleSettings: settings,
            onChange: { changeCount += 1 },
            onHide: { hideCount += 1 },
            alwaysShowControls: true
        )
        controller.show()
        defer { controller.panel.orderOut(nil) }
        controller.setScale(1.5)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let scale = settings.scale
        let size = controller.panel.contentLayoutRect.size
        try click(
            point: NSPoint(x: size.width - 36 * scale, y: size.height - 13 * scale),
            in: controller.panel
        )
        try click(
            point: NSPoint(x: size.width - 13 * scale, y: size.height - 13 * scale),
            in: controller.panel
        )

        XCTAssertEqual(changeCount, 1)
        XCTAssertEqual(hideCount, 1)
    }

    @MainActor
    private func click(point: NSPoint, in panel: NSPanel) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try XCTUnwrap(
                NSEvent.mouseEvent(
                    with: type,
                    location: point,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: type == .leftMouseDown ? 1 : 0
                )
            )
            panel.sendEvent(event)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
}
