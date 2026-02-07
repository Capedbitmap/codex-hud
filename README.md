# Codex HUD

Codex HUD is a macOS menu bar application for managing Codex usage across accounts. It ingests local Codex session data, models usage state with strongly typed domain logic, and recommends the next account to use based on weekly reset timing and remaining capacity.

<p align="center">
  <img src="docs/images/codex-hud-menu.png" alt="Codex HUD menu bar popover showing account status, weekly usage, and recommendation" width="560" />
</p>

## Why This Exists
- Codex usage constraints are multi-windowed and account-scoped.
- Weekly capacity is the highest-value resource and should drive switching decisions.
- Manual tracking across accounts is error-prone and wastes reset opportunities.
- A local-first desktop assistant gives immediate visibility without introducing backend risk.

## Core Capabilities
- Weekly-first dashboard with 5-hour context for the active account.
- Automatic active-account detection from local auth state.
- Incremental ingestion of `token_count` events from Codex session logs.
- Deterministic recommendation engine with stickiness and reset-aware prioritization.
- Notification evaluation on threshold crossings (`30%`, `15%`, `5%` remaining).
- Optional headless automation to send a minimal Codex message (`"hi"`) for timer kick-off and refresh recovery.
- Local persistence with migration and backup safeguards.

## Architecture Overview
`CodexHudCore` owns domain behavior and policy logic.
`CodexHudApp` owns presentation, orchestration, and system integrations.
`CodexHudAutomation` is an optional executable for scheduled policy actions.

### Data Flow
```text
~/.codex/auth.json + ~/.codex/sessions/**/rollout-*.jsonl
            |
            v
   AuthDecoder + SessionLogIngestor
            |
            v
   CodexHudCore domain models/policies
            |
            v
   AppStateStore (Application Support/state.json)
            |
            v
 AppViewModel + NotificationManager + SwiftUI Menu UI
```

## Design Choices
- Local-first ingestion over API polling: eliminates external dependencies and privacy exposure while keeping latency low.
- Strong typing at domain boundaries: `Percent`, usage-window models, and evaluators reduce invalid state propagation.
- Policy-driven decision engines: recommendation, notifications, refresh gating, and reminders are explicit and testable.
- Event-driven refresh with safety net: file watchers provide immediate updates; periodic health checks prevent drift.
- Deterministic recommendation ordering: earliest weekly reset first, with clear tie-breaking on remaining capacity.
- Resilient storage lifecycle: atomic writes, backup rotation, and migration handling protect continuity.

## Reliability and Operational Behavior
- Reads only the newest relevant log window through tail-based and incremental parsers.
- Applies assumed reset logic when a stored reset passes while fresh logs are unavailable.
- Debounces repeated threshold notifications by keeping a notification ledger in state.
- Isolates automation decisions behind cooldown and window policies to avoid runaway behavior.

## Privacy and Security
- All state stays local in `~/Library/Application Support/<bundle-id>/state.json`.
- No telemetry, no analytics, no external service dependencies.
- Tokens are not persisted by this app; JWT data is decoded in memory only for identity derivation.

## Requirements
- macOS 15+
- Swift 6.2 toolchain (Xcode 16+ recommended)
- Codex CLI installed and authenticated (`~/.codex` present)

## Install and Run (First Time)
Clone and launch in one flow:
```bash
git clone https://github.com/Capedbitmap/codex-hud.git
cd codex-hud
./scripts/install-and-run.sh
```

What this does:
- Builds the app from source.
- Installs it to `~/Applications/CodexHudApp.app`.
- Opens the app after install.

If you only want to install without launching:
```bash
./scripts/install-and-run.sh --no-open
```

## Daily Use
After first install, launch from Finder (`~/Applications/CodexHudApp.app`) or run:
```bash
open ~/Applications/CodexHudApp.app
```

## Configuration
1. Open **Settings** from the popover.
2. Map `Codex 2` through `Codex 6` to unique account emails.
3. Enable notifications if needed.

If account/usage data is empty, confirm Codex CLI is installed and authenticated (`~/.codex/auth.json` exists).

## Headless Automation (Optional)
Start 5-hour countdown automation manually:
```bash
./scripts/run-daily-hello.sh --daily-hello
```

Run weekly-aware forced refresh manually:
```bash
./scripts/run-forced-refresh.sh
```

Daily hello (`--daily-hello`) sends `"hi"` only when all policy checks pass:
- Time window is 06:00-20:00 local time.
- Maximum 3 sends per day.
- Minimum 4 hours since the previous send.
- 5-hour window has not already started for the active account.
- Weekly remaining is above depleted threshold.

Forced refresh (`--forced-refresh`) sends `"hi"` only when all policy checks pass:
- Weekly remaining is above depleted threshold.
- At least 12 hours since previous forced-refresh attempt.
- No forced-refresh failure in the last 24 hours.

Install a launch agent for scheduled daily hello:
```bash
./scripts/install-launch-agent.sh
```

Remove that launch agent:
```bash
./scripts/install-launch-agent.sh --unload
```

Default automation model is `gpt-5.1-codex-mini`. Override with `CODEX_HUD_HELLO_MODEL`.

## Development Scripts
Build app bundle only:
```bash
./scripts/build-app.sh
```

Build and run from `.build`:
```bash
./scripts/run-app.sh
```

Install/update app in `~/Applications` without opening:
```bash
./scripts/install-app.sh
```

Install or remove launchd automation:
```bash
./scripts/install-launch-agent.sh
./scripts/install-launch-agent.sh --unload
```

## Development and Verification
Run tests:
```bash
swift test
```

Run lint/format checks (if installed):
```bash
./scripts/lint.sh
```

## Project Layout
```text
Sources/
  CodexHudCore/        # Domain models, parsing, recommendation, policy evaluators, storage
  CodexHudApp/         # Menu bar UI, view model, file watchers, notifications
  CodexHudAutomation/  # Optional scheduled automation entry point
Tests/
  CodexHudCoreTests/   # Parser, recommendation, scheduling, state, and notification tests
scripts/               # Build, run, install, lint utilities
LaunchAgents/          # launchd template(s) for optional automation
.github/               # CI, CODEOWNERS, and PR template
docs/images/           # README assets
```

## Scope Boundaries
- Single-user, local machine workflow.
- No credential management or account switching automation.
- No cloud sync or multi-device state sharing.

## Contributing
Contributions are welcome via pull requests. See `CONTRIBUTING.md` for workflow, required checks, and branch-protection recommendations.

## License
This project is licensed under `PolyForm-Noncommercial-1.0.0`. See `LICENSE`.

Commercial use is not permitted under this license. If you need a commercial license, see `COMMERCIAL-LICENSE.md` or contact `warm_doublet1b@icloud.com`.

This repository also includes a required attribution notice in `NOTICE`. If you redistribute this software, preserve that notice and provide this license text or URL as required by the license.
