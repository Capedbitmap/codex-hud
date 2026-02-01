#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="${APP_NAME:-CodexHudApp}"
DISPLAY_NAME="${DISPLAY_NAME:-Codex HUD}"
BUNDLE_ID="${BUNDLE_ID:-com.mustafa.codexhud}"
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.1}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
INFO_PLIST_SRC="${INFO_PLIST_SRC:-$ROOT_DIR/scripts/AppInfo.plist}"
APP_DIR="${APP_DIR:-$ROOT_DIR/.build/${APP_NAME}.app}"

BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
AUTOMATION_BIN="$BIN_DIR/CodexHudAutomation"

if [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Executable not found at $EXECUTABLE_PATH"
  exit 1
fi

if [ ! -x "$AUTOMATION_BIN" ]; then
  (cd "$ROOT_DIR" && swift build -c "$CONFIGURATION" --product CodexHudAutomation >/dev/null)
fi

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
if [ -x "$AUTOMATION_BIN" ]; then
  cp "$AUTOMATION_BIN" "$MACOS_DIR/CodexHudAutomation"
fi

if [ ! -f "$INFO_PLIST_SRC" ]; then
  echo "Missing Info.plist template at $INFO_PLIST_SRC"
  exit 1
fi

sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__DISPLAY_NAME__|$DISPLAY_NAME|g" \
  -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
  -e "s|__EXECUTABLE__|$APP_NAME|g" \
  -e "s|__VERSION__|$VERSION|g" \
  -e "s|__BUILD__|$BUILD_NUMBER|g" \
  "$INFO_PLIST_SRC" > "$CONTENTS_DIR/Info.plist"

echo "Built app bundle at $APP_DIR"
