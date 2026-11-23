# {{TITLE}}

{{TITLE}} — replace with one sentence on what this does and who it is for.

Created {{DATE}} from the [`buddy-ai-workstation`](https://github.com/hexxrr/buddy-ai-workstation) template.

## Quick start

```bash
./run-tests.sh                              # test gate
PYTHONPATH=src python3 -m {{PACKAGE}}        # run it
PYTHONPATH=src python3 -m {{PACKAGE}} --json # machine-readable
```

No third-party dependencies: Python 3.10+ standard library only, which keeps
it runnable on Alpine/musl and ARM64 Android userlands.

## Layout

```
PLAN.md                 # scope, decisions, verification
AGENTS.md               # project rules for AI agents
run-tests.sh            # unittest gate
src/{{PACKAGE}}/          # package
tests/test_smoke.py     # unit tests
```

## Status

- [x] Template scaffolded, tests pass
- [ ] Real functionality
- [ ] Docs match behavior

## License

MIT
