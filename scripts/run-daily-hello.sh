#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---daily-hello}"
APP_DIR="${APP_DIR:-$ROOT_DIR/.build/CodexHudApp.app}"
HELPER="$APP_DIR/Contents/MacOS/CodexHudAutomation"

case "$MODE" in
  --daily-hello|--forced-refresh)
    ;;
  *)
    echo "Unsupported mode: $MODE" >&2
    echo "Usage: ./scripts/run-daily-hello.sh [--daily-hello|--forced-refresh]" >&2
    exit 1
    ;;
esac

if [ ! -x "$HELPER" ]; then
  echo "Missing automation helper at $HELPER"
  echo "Build the app bundle first (this copies CodexHudAutomation into the .app):"
  echo "  $ROOT_DIR/scripts/build-app.sh"
  exit 1
fi

"$HELPER" "$MODE"
