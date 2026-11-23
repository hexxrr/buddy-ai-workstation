# AGENTS.md — {{PROJECT_NAME}}

Project rules. The full, binding workspace rules live in
[`buddy-ai-workstation/AGENTS.md`](https://github.com/hexxrr/buddy-ai-workstation/blob/main/AGENTS.md);
this file only adds project specifics and repeats the non-negotiables.

## Non-negotiables

- **Free and open-source only.** No paid APIs, metered services, or key-gated
  tools. If a dependency needs an account, it is the wrong dependency.
- **Never expose secrets.** No tokens, keys, or `.env` contents in code,
  commits, logs, or output you report.
- **Ask before publishing or pushing.** Commits and tests are local and free;
  `git push`, releases, issues, PRs and packages all need explicit approval.
- **Back up before destructive changes.** Run
  `../buddy-ai-workstation/scripts/backup.sh .` (or `git tag pre-change-...`)
  and verify the result before deleting or rewriting anything.
- **Honest reporting.** State what actually ran and what it printed.

## Project conventions

- Python 3.10+, standard library first, type hints on public functions.
- Tests in `tests/`, run with `./run-tests.sh`; a bug fix needs a regression
  test, new behavior needs a test.
- CLI: `--help`, `--json`, errors on stderr, non-zero exit on failure.
- One logical change per commit; imperative subject, ≤ 72 characters.
- Update `PLAN.md` statuses and `README.md` in the same change.

## Definition of done

- [ ] `./run-tests.sh` exits 0
- [ ] `PLAN.md` and `README.md` match the code
- [ ] No secrets staged (`git diff --cached` reviewed)
- [ ] Backup taken if anything was deleted or rewritten
- [ ] Push, if any, was approved first
