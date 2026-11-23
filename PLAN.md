# Project Plan — buddy-ai-workstation

Goal: a small, public, self-documenting repo that captures the OnePlus 12
on-device AI development environment and gives it a runnable health check.

## Scope

| # | Step | Status |
|---|------|--------|
| 1 | Confirm `hexxrr/buddy-ai-workstation` does not exist on GitHub | done |
| 2 | Initialize a clean git project (no venv, no secrets) | done |
| 3 | Write `README.md` describing the OnePlus 12 AI dev environment | done |
| 4 | Add `.gitignore` covering Python + Node.js | done |
| 5 | Add stdlib-only `healthcheck.py` | done |
| 6 | Run the script and verify output + exit code | done |
| 7 | Create the public GitHub repo and push `main` | pending your approval |

## Design decisions

- **No dependencies.** `healthcheck.py` uses only the standard library so it runs
  on a fresh Android/Linux shell with nothing installed.
- **Read-only checks.** Nothing is modified, downloaded or installed; the only
  optional network call is behind `--network`.
- **Honest environment data.** Every version and figure in the README was read
  from the running device, not copied from marketing specs.
- **Ignore the toolchain, not just build output.** The repo must not pick up
  `.venv/`, `node_modules/`, or the host `~/.buddy` runtime state.

## Verification

- `python3 healthcheck.py` exits 0 and prints a PASS/WARN/FAIL table.
- `python3 healthcheck.py --json` produces valid JSON.
- `git status` shows only the four intended files.
