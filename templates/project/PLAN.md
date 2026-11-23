# Project Plan — {{PROJECT_NAME}}

Goal: replace this with one measurable sentence.

Created {{DATE}}.

## Scope

| # | Step | Status |
|---|------|--------|
| 1 | Define behavior and CLI contract | pending |
| 2 | Implement core logic in `src/{{PACKAGE}}/` | pending |
| 3 | Add tests, including one failure case | pending |
| 4 | Run `./run-tests.sh` until green | pending |
| 5 | Update `README.md` to match reality | pending |

## Decisions

- Standard library only, because Alpine/musl lacks many binary wheels.
- `unittest` instead of pytest, so the gate runs with nothing installed.
- Text output for humans, `--json` for scripts.

## Verification

- `./run-tests.sh` → exit 0, all tests pass.
- `PYTHONPATH=src python3 -m {{PACKAGE}} --json` → `{"status": "ok", ...}`.
- `git status --short` → clean after the final commit.

## Out of scope

- (list tempting adjacent work here instead of doing it)
