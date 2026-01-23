# Codex HUD

Private macOS menu bar app for tracking Codex usage across five accounts. It reads local Codex session logs, persists account state locally, recommends which account to use next, and can send a minimal headless message to start the 5‑hour window early.

## Requirements
- macOS 14+ (Sonoma/Sequoia preferred)
- Xcode command line tools
- Codex CLI installed and authenticated (`~/.codex` populated)

## Build & Run

### App (menu bar)
```
cd /Users/Mustafa/DevFiles/Mac\ Apps/codex-hud
swift run CodexHudApp
```

### Automation (daily hello)
```
cd /Users/Mustafa/DevFiles/Mac\ Apps/codex-hud
swift run --configuration release CodexHudAutomation --daily-hello
```

## Automation Scheduling
We use a LaunchAgent to trigger the headless "hi" message (non‑interactive Codex). The guardrails in the automation binary ensure we never exceed limits.

Install (from repo root):
```
launchctl unload ~/Library/LaunchAgents/com.mustafa.codexhud.hello.plist 2>/dev/null || true
cp LaunchAgents/com.mustafa.codexhud.hello.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mustafa.codexhud.hello.plist
```

Uninstall:
```
launchctl unload ~/Library/LaunchAgents/com.mustafa.codexhud.hello.plist
rm ~/Library/LaunchAgents/com.mustafa.codexhud.hello.plist
```

## Headless "Hello" Guardrails (must‑pass)
- Only runs **between 6:00 AM–8:00 PM** local time.
- **Max 3 sends per day** per active account.
- **Minimum 4 hours between sends**.
- **Skip** if weekly remaining is **≤ 5%**.
- **Skip** if 5‑hour window already started (used% > 0, after 6am snapshot).
- **No retry loops**; a failure counts toward the daily cap.

## Environment Overrides
- `CODEX_BIN` — absolute path to the Codex CLI if `which codex` is not available in LaunchAgent context.
- `CODEX_HUD_HELLO_MODEL` — override the default model (`gpt-5.1-codex-mini`).

Example:
```
launchctl setenv CODEX_BIN /usr/local/bin/codex
launchctl setenv CODEX_HUD_HELLO_MODEL gpt-5.1-codex-mini
```

## Notes / Troubleshooting
- If `codex exec` fails with permission errors, fix ownership:
```
sudo chown -R $(whoami) /Users/Mustafa/.codex
```
- Logs are local only; no telemetry is sent.
