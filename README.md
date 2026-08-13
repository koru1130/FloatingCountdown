# Countdown Float

Native macOS implementation of the Countdown Float MVP. The app is a menu-bar utility with an always-on-top countdown float, setup panel, menu-bar controls, and completion notifications, following the handoff in `macOS 懸浮倒數工具 MVP/handoff/`.

## Requirements

- macOS 13 or newer
- Xcode 16 or newer (the project uses Xcode's synchronized source groups)
- Swift 5 language mode

The project has no external dependencies.

## Build and run

Open `CountdownFloat.xcodeproj` in Xcode, select the `CountdownFloat` scheme, and press Run. The app is configured as an agent/menu-bar app (`LSUIElement`) so it does not add a Dock icon.

For a command-line build:

```sh
xcodebuild -project CountdownFloat.xcodeproj \
  -scheme CountdownFloat \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build \
  CODE_SIGNING_ALLOWED=NO
```

Run the unit-test target with:

```sh
xcodebuild -project CountdownFloat.xcodeproj \
  -scheme CountdownFloat \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  test \
  CODE_SIGNING_ALLOWED=NO
```

Swift sources are kept in `CountdownFloat/`; the Xcode project uses a synchronized source group, so new `.swift` files in that directory are included automatically. Test sources belong in `CountdownFloatTests/`.
