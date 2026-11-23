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

---

# Phase 2 — permanent AI development workspace

Goal: turn the repo into the durable home for on-device agent work, with
binding rules and a reusable, tested starter.

## Scope

| # | Step | Status |
|---|------|--------|
| 1 | Write comprehensive `AGENTS.md` (11 required areas) | done |
| 2 | Add reusable `templates/project/` starter | done |
| 3 | Add `scripts/new-project.sh` scaffolder | done |
| 4 | Add `scripts/backup.sh` with verification + retention | done |
| 5 | Add `scripts/check-repo.sh` seven-step gate | done |
| 6 | Add unit tests for `healthcheck.py` | done |
| 7 | Test every new file (gate exits 0, 11 checks) | done |
| 8 | Update `README.md` and add `LICENSE` | done |
| 9 | Commit and push phase 2 | done (`733bbaa`) |

## Decisions

- **Rules live in one file.** `AGENTS.md` is binding; template projects get a
  short `AGENTS.md` that repeats the non-negotiables and links back, so rules
  cannot silently diverge.
- **No CI workflow.** The token lacks the `workflow` scope, so CI is
  `scripts/check-repo.sh`. Revisit only if the user re-authorizes.
- **Backups are verified, not assumed.** `tar -tzf` and `git bundle verify`
  run before success is reported; retention prunes oldest first, never the
  newest.
- **Template smoke test is part of the gate.** A starter that only *looks*
  right rots; the gate scaffolds, tests, runs and deletes one on every check.
- **No overwrites.** Phase 1 files were edited additively; the original
  health check and its README section are intact.

## Verification

- `scripts/check-repo.sh` → `11 passed, 0 failed`, exit 0.
- `scripts/new-project.sh sample-app /tmp/...` → 5 tests pass, clean
  `git status`, refuses to overwrite on re-run.
- `scripts/backup.sh` on a git repo → archive + verified bundle, retention
  keeps last N, restore drill reproduces the file.
- README layout matches `git ls-files`.
- Fresh clone of `main` runs `check-repo.sh` → 11 passed, 0 failed,
  and scaffolds a working project (verified after the push).

## Out of scope (deliberately)

- `.github/workflows/` CI — blocked by token scope.
- Publishing the template as a package — needs a release approval.
- Rewriting phase 1 history — published, so it stays.

