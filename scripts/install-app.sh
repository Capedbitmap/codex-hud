#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CodexHudApp}"
BUILD_APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP_DIR="$INSTALL_DIR/${APP_NAME}.app"

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$INSTALL_DIR"

if [ -d "$INSTALL_APP_DIR" ]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  mv "$INSTALL_APP_DIR" "$INSTALL_DIR/${APP_NAME}.app.bak.$TS"
fi

cp -R "$BUILD_APP_DIR" "$INSTALL_APP_DIR"
codesign --force --deep --sign - "$INSTALL_APP_DIR" >/dev/null 2>&1 || true

echo "Installed app at $INSTALL_APP_DIR"
