#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/LaunchAgents/io.github.capedbitmap.codexhud.daily-hello.plist.template"
AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL_BASE="${LABEL_BASE:-io.github.capedbitmap.codexhud}"
LABEL="${LABEL_BASE}.daily-hello"
TARGET_PLIST="$AGENTS_DIR/$LABEL.plist"
RUN_SCRIPT="$ROOT_DIR/scripts/run-daily-hello.sh"
LOG_OUT="${LOG_OUT:-/tmp/codex-hud-daily-hello.log}"
LOG_ERR="${LOG_ERR:-/tmp/codex-hud-daily-hello.err}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-launch-agent.sh [--load]
  ./scripts/install-launch-agent.sh --unload

Options:
  --load    Install/update plist and load it with launchctl (default behavior)
  --unload  Unload and remove the installed plist
EOF
}

MODE="load"
if (($# > 1)); then
  usage >&2
  exit 1
fi
if (($# == 1)); then
  case "$1" in
    --load) MODE="load" ;;
    --unload) MODE="unload" ;;
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
fi

if [[ "$MODE" == "unload" ]]; then
  launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
  rm -f "$TARGET_PLIST"
  echo "Removed launch agent: $TARGET_PLIST"
  exit 0
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing template: $TEMPLATE" >&2
  exit 1
fi
if [[ ! -x "$RUN_SCRIPT" ]]; then
  echo "Missing executable automation script: $RUN_SCRIPT" >&2
  exit 1
fi

mkdir -p "$AGENTS_DIR"
sed \
  -e "s|__LABEL__|$LABEL|g" \
  -e "s|__RUN_SCRIPT__|$RUN_SCRIPT|g" \
  -e "s|__LOG_OUT__|$LOG_OUT|g" \
  -e "s|__LOG_ERR__|$LOG_ERR|g" \
  "$TEMPLATE" > "$TARGET_PLIST"

launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$TARGET_PLIST"
launchctl enable "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true

echo "Installed launch agent: $TARGET_PLIST"
