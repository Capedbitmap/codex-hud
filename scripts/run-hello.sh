#!/usr/bin/env bash
set -euo pipefail

codex exec -m gpt-5.1-codex-mini "hi" --skip-git-repo-check
