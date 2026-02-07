#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---daily-hello}"
APP_DIR="${APP_DIR:-$ROOT_DIR/.build/CodexHudApp.app}"
HELPER="$APP_DIR/Contents/MacOS/CodexHudAutomation"
INSTALLED_HELPER="$HOME/Applications/CodexHudApp.app/Contents/MacOS/CodexHudAutomation"

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
  if [ -x "$INSTALLED_HELPER" ]; then
    HELPER="$INSTALLED_HELPER"
  else
    echo "Missing automation helper at $HELPER"
    echo "Build/install the app first:"
    echo "  $ROOT_DIR/scripts/install-and-run.sh --no-open"
    exit 1
  fi
fi

"$HELPER" "$MODE"
