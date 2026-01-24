#!/usr/bin/env bash
set -euo pipefail

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint
else
  echo "swiftlint not installed; skipping. Install with: brew install swiftlint"
fi

if command -v swiftformat >/dev/null 2>&1; then
  swiftformat --lint .
else
  echo "swiftformat not installed; skipping. Install with: brew install swiftformat"
fi
