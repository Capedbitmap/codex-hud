#!/bin/zsh
set -euo pipefail

REPO_DIR="/Users/Mustafa/DevFiles/Mac Apps/codex-hud"
cd "$REPO_DIR"

swift run --configuration release CodexHudAutomation --daily-hello
