#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROJECT_NAME="CountdownFloat"
PROJECT_FILE="CountdownFloat.xcodeproj"
SCHEME="CountdownFloat"
CONFIGURATION="Debug"
BUNDLE_ID="com.koru.CountdownFloat"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/RunDerivedData"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$PROJECT_NAME"

pkill -x "$PROJECT_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Built app executable not found: $APP_BINARY" >&2
  exit 1
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROJECT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PROJECT_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
