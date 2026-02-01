#!/bin/zsh
set -euo pipefail

REPO_DIR="/Users/Mustafa/DevFiles/Mac Apps/codex-hud"
cd "$REPO_DIR"

APP_DIR="${APP_DIR:-$REPO_DIR/.build/CodexHudApp.app}"
HELPER="$APP_DIR/Contents/MacOS/CodexHudAutomation"

if [ ! -x "$HELPER" ]; then
  echo "Missing automation helper at $HELPER"
  echo "Build the app bundle first (this copies CodexHudAutomation into the .app):"
  echo "  $REPO_DIR/scripts/build-app.sh"
  exit 1
fi

"$HELPER" --daily-hello
