# Contributing

Thanks for your interest in improving Codex HUD.

## Ground Rules
- Use pull requests for all changes. Do not push directly to `master`.
- Keep PRs focused and small enough for review.
- Include or update tests when behavior changes.
- Keep local-only files, credentials, and secrets out of commits.

## Development Setup
```bash
git clone https://github.com/Capedbitmap/codex-hud.git
cd codex-hud
./scripts/install-and-run.sh --no-open
swift test
```

## Pull Request Process
1. Create a branch from `master`.
2. Implement one logical change per PR.
3. Run `swift test` and include results in PR notes.
4. Open a PR and complete the checklist.
5. Wait for CI + review before merge.

## Repository Protection (Maintainer Setup)
Enable branch protection on `master` in GitHub settings:
- Require a pull request before merging.
- Require approvals (at least 1).
- Require status checks to pass (`Swift CI`).
- Restrict direct pushes to admins/maintainers only.
- Disable force pushes and deletions on `master`.

## Licensing and Contributions
- By submitting a contribution, you agree your contribution is licensed under this repository's license (`PolyForm-Noncommercial-1.0.0`).
- Commercial rights are not granted by contribution; see `COMMERCIAL-LICENSE.md`.
