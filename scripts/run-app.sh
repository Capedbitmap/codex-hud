#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CodexHudApp}"
APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"

"$ROOT_DIR/scripts/build-app.sh"

# `open` will foreground an existing running instance instead of launching the newly-built binary.
# Ensure we restart so changes take effect.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "Stopping running $APP_NAME..."
  killall "$APP_NAME" >/dev/null 2>&1 || true
  for _ in {1..30}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
fi

echo "Opening $APP_DIR"
defaults read "$APP_DIR/Contents/Info" CFBundleIdentifier 2>/dev/null | sed 's/^/Bundle ID: /' || true
open -n "$APP_DIR"
