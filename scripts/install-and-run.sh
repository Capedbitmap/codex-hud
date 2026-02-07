#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CodexHudApp}"
INSTALL_APP_DIR="$HOME/Applications/${APP_NAME}.app"
OPEN_AFTER_INSTALL=1

usage() {
  cat <<'EOF'
Usage: ./scripts/install-and-run.sh [--no-open] [--help]

Builds and installs Codex HUD into ~/Applications, then opens it.

Options:
  --no-open   Install but do not launch the app
  --help      Show this message
EOF
}

while (($# > 0)); do
  case "$1" in
    --no-open)
      OPEN_AFTER_INSTALL=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift toolchain not found. Install Xcode 16+ (or Swift 6.2+) and retry." >&2
  exit 1
fi

if [[ ! -d "$HOME/.codex" ]]; then
  cat <<'EOF'
Warning: ~/.codex was not found.
The app can launch, but usage/account data stays empty until Codex CLI is installed and authenticated.
EOF
fi

echo "Installing $APP_NAME into ~/Applications..."
"$ROOT_DIR/scripts/install-app.sh"

if ((OPEN_AFTER_INSTALL)); then
  if [[ ! -d "$INSTALL_APP_DIR" ]]; then
    echo "Expected installed app at $INSTALL_APP_DIR, but it was not found." >&2
    exit 1
  fi
  echo "Opening $INSTALL_APP_DIR"
  open -n "$INSTALL_APP_DIR"
fi

echo "Done."
