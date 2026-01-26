#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CodexHudApp}"
APP_DIR="${APP_DIR:-$ROOT_DIR/.build/${APP_NAME}.app}"

"$ROOT_DIR/scripts/build-app.sh"
open "$APP_DIR"
