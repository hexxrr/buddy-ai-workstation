# AGENTS.md — operating rules for buddy-ai-workstation

This repository is the permanent AI development workspace for a OnePlus 12
running Linux (Alpine) beside Android. These rules bind every agent working
here — human-driven or autonomous. When a rule conflicts with convenience,
the rule wins.

Read this file before touching code. Project-level `AGENTS.md` files may add
rules; they may never weaken the approval, secret, or backup sections below.

---

## 1. Operating principles

1. **Facts before plans.** Inspect the real environment (`python3 --version`,
   `ls`, `git status`) before proposing work. Never assume a tool exists.
2. **Autonomy inside the device, consent at the boundary.** Local edits, tests
   and commits are autonomous. Anything that leaves the device or destroys
   state needs explicit approval (§13).
3. **Small, verifiable steps.** One change, one test, one report. Do not stack
   three unverified changes and hope.
4. **Reversible by default.** Prefer additive changes, feature branches, and
   backup copies over in-place rewrites (§12).
5. **Honest reporting.** Say what actually ran and what it printed. If a test
   was skipped or a step failed, say so plainly. Never claim a push, install or
   payment happened unless a tool confirmed it.

### Environment facts (verify, don't trust blindly)

| Component | Value |
|---|---|
| Device | OnePlus 12, Snapdragon 8 Gen 3, aarch64, ~11.5 GB RAM |
| Kernel | Linux 6.1.157-android14-11 (Android 14 base) |
| Userland | Alpine Linux 3.24.2, musl libc |
| Python | 3.14.x, standard library available |
| Node.js | 24.x with npm 11.x |
| git / gh | 2.54+ / 2.97+ |
| Shell | `/bin/sh` (busybox ash) and `bash` |
| Workspace | `/root/.buddy/work/<project>/` |
| Android builds | No Gradle/Studio; plain Java + `aapt2`, `d8`, `apksigner` |

---

## 2. Autonomous project planning

Every non-trivial task starts with a plan written to `PLAN.md` in the project
root. Keep it short enough to stay true.

Required shape:

```markdown
# Project Plan — <name>

Goal: <one sentence, measurable>

## Scope
| # | Step | Status |
|---|------|--------|
| 1 | ... | pending / done / blocked |

## Decisions
- <choice> because <reason> (alternatives considered: ...)

## Verification
- <exact command> → expected <exit code / output>
```

Rules:

- **Definition of done is executable.** "Works" is not done; `python3
  run-tests.sh` exiting 0 is done.
- **Timebox discovery.** Spend at most a few commands establishing the state;
  then plan. Do not explore indefinitely.
- **Plan the approval gates up front.** If the task ends in a push, release or
  publish, say so in step 1 and confirm the whole plan before starting the
  irreversible part.
- **Update status as you go.** A plan that still says "pending" after the work
  is finished is a bug.
- **Cap scope.** If the user asks for one fix, do not refactor the module.
  Note tempting adjacent work under "Out of scope / follow-ups".
- **Interruptions are instructions.** New user input mid-task outranks the
  current plan: re-plan, don't finish the old plan first.

---

## 3. Python development

- **Standard library first.** This userland is musl-based; many binary wheels
  are unavailable. Use `pathlib`, `json`, `argparse`, `unittest`, `urllib`
  before reaching for a package.
- **Version floor:** 3.10+ syntax is allowed; do not rely on 3.13/3.14-only
  features in shared code. Target the interpreter actually installed (3.14 here).
- **Style:** PEP 8, 4-space indent, type hints on public functions, `from
  __future__ import annotations` for newer syntax portability, docstrings that
  state the contract (inputs, outputs, exit status).
- **CLI contract:** every script supports `--help`, prints errors to stderr,
  returns `0` on success and non-zero on failure. Machine-readable output goes
  behind `--json`.
- **Virtual environments:** never install into the system interpreter.

```bash
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements-dev.txt   # only if truly needed
```

- **Dependencies:** pin versions in `requirements.txt`; justify each new
  dependency in `PLAN.md`. No package that phones home, requires a key, or has
  a paid tier (§11).
- **Tests:** `unittest` is always available; `pytest` is acceptable when the
  project already uses it. Tests must not touch the network unless marked and
  opt-in.
- **No secrets in code.** Read configuration from the environment or a file
  listed in `.gitignore`.

```bash
python3 -m py_compile path/to/file.py       # syntax gate
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

---

## 4. Node.js development

- **Runtime:** Node 24.x, npm 11.x. Prefer ESM (`"type": "module"`); use
  `node --test` for tests before adding Jest/Vitest.
- **Lockfiles are committed.** `package-lock.json` goes in the repo; never
  hand-edit it.
- **Dependency hygiene:** `npm audit --omit=dev` before publishing anything;
  no packages with postinstall scripts you have not read; prefer zero-dep
  implementations for small tools.
- **No global installs** for project tooling: use `npx` or `devDependencies`.
- **Scripts:** expose `test`, `lint`, `start` in `package.json` so CI and
  humans run the same commands.
- **Node on Alpine:** musl builds are fine for pure JS. Native addons
  (`node-gyp`) need build tools and often fail — avoid them or document the
  `apk add build-base python3` prerequisite.

```bash
npm ci                 # reproducible install from lockfile
node --test            # built-in runner
node --check src/index.js
```

---

## 5. Android development on ARM64

There is no Gradle and no Android Studio. Build small apps with plain Java and
the Android SDK command-line tools:

- **Toolchain location:** `~/android-sdk/` (platform `android-36`), with
  `aapt2`, `d8`, `apksigner` on `PATH` or under the SDK's `build-tools`.
- **Layout** (one folder per app):

```
AndroidManifest.xml
java/com/buddyapps/<name>/MainActivity.java
res/values/strings.xml
app.properties        # versionCode / versionName / minSdk
```

- **Rules that prevent build failures:**
  - Package names start with `com.buddyapps.` to avoid collisions.
  - `android:exported="true"` on the launcher activity.
  - Theme `@android:style/Theme.DeviceDefault`; build UI in Java, not XML.
  - No AndroidX, no Kotlin, no external libraries; Java 8 syntax is fine.
  - Bump `versionCode` on every update or Android refuses the install.
- **Architecture:** build for `arm64-v8a` only. The device is aarch64; x86
  emulator artifacts are useless here.
- **Testing:** `adb` is generally absent. Verify by installing and reading the
  screen; use `logcat -d` through the phone shell for stack traces.
- **Install gate:** the *user* taps Install/Update and confirms the
  fingerprint. Never tap it yourself, never claim you did, and never work
  around the installer.
- **Sideloading is not publishing.** Still ask before installing over an app
  the user relies on, and always keep the previous APK.

---

## 6. Alpine Linux compatibility

- **musl, not glibc.** Prebuilt Linux binaries and manylinux wheels may fail
  with "not found" even though the file exists. Check with `ldd <binary>`; if
  the loader is `/lib/ld-linux-*`, it will not run.
- **Install tools with `apk`:** `apk add --no-cache <pkg>` (as root) rather
  than downloading random tarballs. Note the addition in the project README.
- **Busybox utilities are limited.** `sed -i` needs no suffix, `grep -P` may
  be missing, `readlink -f` behaves differently. Test scripts under `sh`, not
  just `bash`, when they may be invoked by other tools.
- **No systemd.** Long-running services need an explicit supervisor or a
  foreground process; use `nohup`, `tmux`, or the app's own service model.
- **`/tmp` may be small or cleaned.** Keep build artifacts inside the project
  (`build/`) and ignore them in git.
- **Time and locale:** assume UTF-8, but keep CLI output ASCII-safe so
  logs survive odd terminals and minimal screens.
- **Containers/proot:** filesystem permissions can look odd; prefer
  user-writable paths under `$HOME`.

---

## 7. GitHub repository management

- **Identity:** `gh auth status` must show the user's account before any
  remote operation. Never print the token (§11).
- **Available scopes today:** `repo`, `read:org`, `gist`.
  - `workflow` is **not** granted: pushing `.github/workflows/*` will be
    rejected. Keep CI as local scripts (`scripts/check-repo.sh`) unless the
    user re-authorizes with `gh auth refresh -s workflow`.
  - `delete_repo` is **not** granted: deleting a repository is impossible and
    must never be attempted as a "cleanup".
- **Repository creation:** `gh repo create <name> --public|--private
  --source=. --remote=origin --push` — the push is an approval gate (§13).
- **Naming:** lowercase, hyphen-separated, descriptive. One repo per project.
- **Every repo ships:** `README.md`, `.gitignore`, a license (MIT unless the
  user says otherwise), and `PLAN.md` for active work.
- **Branches:** `main` is protected by convention, not by GitHub. Work on
  `feat/<slug>`, `fix/<slug>`, `chore/<slug>`; merge locally only after tests
  pass.
- **Commits:** imperative subject ≤ 72 chars, body explains *why*, one logical
  change per commit. Reference issues as `Refs #12`; never auto-close with
  "Closes" unless the fix is verified.
- **Never force-push** to `main`. Never rewrite published history without
  explicit approval.
- **No `--no-verify`, no skipping hooks** to make a push succeed; fix the
  cause instead.

---

## 8. Automated testing and debugging

### Test layers (cheapest first)

1. **Syntax / static:** `py_compile`, `node --check`, `bash -n`, JSON lint.
2. **Unit:** pure functions, no I/O, no clock, no network.
3. **Integration:** real files in a temp dir; assert exit codes and file
   effects.
4. **Smoke:** run the actual CLI once, end to end, and check its output.
5. **Manual/visual:** screenshots or `read_screen` for Android UI.

`scripts/check-repo.sh` runs layers 1–4 for this repository and scaffolds a
throwaway project from the template to prove the template still works.

### Debugging protocol

1. **Reproduce** with the smallest command that fails. Capture the exact
   output and exit code.
2. **Read the error**, top to bottom. Do not pattern-match to a guess.
3. **Form one hypothesis** and design one test that distinguishes it from the
   alternatives.
4. **Fix the cause, not the symptom.** No blanket `except: pass`, no retry
   loops hiding a deterministic failure.
5. **Add a regression test** that fails before the fix and passes after.
6. **Re-run the whole suite**, not just the failing test.

- Prefer `set -euo pipefail` in bash, `python3 -X dev`, and `node
  --trace-uncaught`.
- Log to stderr, keep stdout clean for data.
- If a failure needs the network, a GUI, or the user's fingerprint, stop and
  say so instead of simulating it.

---

## 9. Error recovery

Classify every failure before reacting:

| Class | Example | Response |
|---|---|---|
| Transient | network timeout, lock contention | retry once with backoff, then report |
| Environmental | missing tool, full disk | fix prerequisite or ask; do not retry blindly |
| Logic | failing assertion, wrong output | debug (§8), add regression test |
| Permission | `gh` 403, installer blocked | stop; the user must change it (§13) |
| Unknown | unexplained state change | stop and inspect; never "try again harder" |

Rules:

- **Retry budget:** at most 2 attempts for the same action, with a different
  approach on the second. Then report what you see.
- **Never retry an outward-facing action blindly.** Before re-sending a
  message, issue, PR or push, check whether the first attempt landed
  (`gh pr list`, remote log, sent items). Double-posting is worse than a
  delay.
- **Detect "nothing happened".** If the screen or command output is unchanged,
  the action failed — do not loop it.
- **Roll back with a known-good state:** `git switch -` / `git reset --hard
  <tag>` only on unpushed local work; restore from the backup created in §12
  for anything else.
- **Preserve evidence.** Save failing output to `build/logs/<timestamp>.log`
  (ignored by git) before experimenting.
- **Stop conditions:** leaked secret, destructive command that succeeded,
  unexplained data loss, or an approval that was denied. In each case, stop,
  summarize, and wait for the user.

---

## 10. Free and open-source tooling only

- **Allowed:** OSI-approved licenses (MIT, Apache-2.0, BSD, GPL family, MPL-2.0),
  public-domain tools, and software that runs entirely on-device.
- **Forbidden:** paid APIs, metered cloud services, "free tier" services that
  require billing details, license-key-gated binaries, trials that expire,
  telemetry-only SDKs, and anything that uploads source code to a third party.
- **No paid model APIs.** AI help comes from the user's existing assistant
  plan or from local models. Do not wire a project to OpenAI/Anthropic/etc.
  endpoints or embed API keys for them.
- **Verification before adopting a dependency:**
  1. License file present and permissive/compatible.
  2. No required account, key, or phone-home on first run.
  3. Buildable from source on musl/aarch64, or pure JS/Python.
  4. Maintained within the last ~2 years, or small enough to vendor.
- **Credit what you reuse** and keep the license text in the repo.

---

## 11. Secrets and credential protection

- **Never print, echo, log, or commit** a token, key, cookie, session ID,
  password, or one-time code. If a command would print one (`gh auth token`,
  `env`, `cat ~/.config/gh/hosts.yml`), redact it in the output you report.
- **Never paste secrets into a model prompt, an issue, a commit message, or a
  screenshot.**
- **Storage:** environment variables for runtime secrets, `.env` for local
  development. `.env` and every variant are git-ignored; only
  `.env.example` with dummy values is committed.
- **Before every commit:** `git diff --cached` and a pattern scan for
  `gho_`, `ghp_`, `github_pat_`, `AKIA`, `BEGIN .*PRIVATE KEY`, `sk-`,
  `xox[baprs]-`. If something slips in, rotate the credential first, then
  clean history — do not just delete the file.
- **Auth is owned by the user:** the agent never types passwords, one-time
  codes, or payment details, and never runs `gh auth login` on the user's
  behalf.
- **Least privilege:** request the narrowest scope; do not refresh tokens to
  gain `workflow`/`delete_repo` without the user asking.
- **Leak response:** revoke/rotate immediately, tell the user, and only then
  continue.

---

## 12. Backup before destructive changes

Destructive means anything that can lose data or make a working state
unrecoverable: deleting/overwriting files, `git reset --hard`, history
rewrites, dropping a database, replacing a working APK, mass `sed -i`,
uninstalling packages, or changing system settings.

Protocol:

1. **Snapshot first**, using the repo's helper:

```bash
scripts/backup.sh /path/to/project     # tar.gz + git bundle in ~/.buddy/backups
```

2. **Verify the backup** (`tar -tzf` lists files, `git bundle verify` passes,
   sizes look sane). An unverified backup is not a backup.
3. **Record the restore command** in the task summary:
   `tar -xzf ~/.buddy/backups/<name>-<stamp>.tar.gz -C <parent>`.
4. **Make the smallest destructive change possible** — delete one file, not a
   directory; rename instead of delete when in doubt.
5. **Keep the last 10 backups**; never delete the most recent good one.

For git-only work, a tag plus branch is a valid lightweight backup:

```bash
git tag -a pre-change-$(date +%Y%m%d-%H%M) -m "before <change>"
```

---

## 13. Approval gates

Autonomy stops here. **Ask the user and wait for an explicit approval before:**

- creating, renaming, archiving or deleting a GitHub repository;
- `git push`, force-push, tag push, release creation, or opening/closing
  issues and pull requests;
- publishing packages (PyPI, npm), gists, or public artifacts;
- sending messages, emails, posts, comments, or form submissions;
- anything involving payment, purchases, subscriptions, or account changes;
- deleting data the user did not create in this task, or changing settings;
- installing/updating an APK over an existing app.

How to ask:

- State the **exact** action and target, e.g. "push commit `<sha>` to
  `origin/main` of `hexxrr/<repo>`".
- Confirm the **whole plan** when a later step depends on an earlier
  irreversible one (cancel-to-rebook, delete-to-recreate).
- One approval covers one action. A denied or modified request means re-ask
  with the changed version — never proceed on the original.
- Local commits, tests, and edits inside the workspace need no approval; they
  are the safe part of the job.

---

## 14. Definition of done

A task is done only when all of these hold:

- [ ] `PLAN.md` statuses updated, out-of-scope items listed.
- [ ] `scripts/check-repo.sh` (or the project's test command) exits 0.
- [ ] New behavior has a test; fixed bug has a regression test.
- [ ] No secrets in `git diff`, logs, or generated artifacts.
- [ ] README/docs reflect what actually exists.
- [ ] Backup taken before any destructive step (§12).
- [ ] Any push/publish was approved and confirmed by tool output.
- [ ] Final report states what changed, what was verified, and what remains.

---

## 15. Repository map

```
AGENTS.md              # this file — binding rules
PLAN.md                # current workspace plan
README.md              # environment + usage
healthcheck.py         # dependency-free environment probe
scripts/
  new-project.sh       # scaffold a project from templates/project
  check-repo.sh        # layers 1–4 test gate for this repo
  backup.sh            # verified snapshot before destructive work
templates/project/     # reusable starter (Python + tests + docs)
```

Typical loop:

```bash
scripts/new-project.sh my-tool        # scaffold, git init, first test run
cd ../my-tool && $EDITOR PLAN.md      # plan the work
scripts/check-repo.sh                 # test gate (or project equivalent)
python3 healthcheck.py                # environment sanity
```

When in doubt: smaller change, more tests, ask before publishing.
