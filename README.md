# buddy-ai-workstation

A pocket-sized AI development workstation: this repo documents the
**OnePlus 12** environment I use to build and run code directly on the phone,
defines the rules an autonomous agent follows here, and ships a reusable
project template plus a health check that prove the toolchain is intact.

No laptop. No cloud IDE. Just a phone, a Linux userland, and an AI agent.

- **Environment:** Alpine 3.24 on ARM64, Python 3.14, Node 24, on-device
  Android builds without Gradle.
- **Rules:** [`AGENTS.md`](AGENTS.md) — planning, testing, error recovery,
  free-software-only, secrets, backups, approval gates.
- **Template:** `scripts/new-project.sh my-tool` → tested project in seconds.
- **Gate:** `scripts/check-repo.sh` → syntax, unit, smoke, backup and secret
  checks in one command.

---

## The device

| | |
|---|---|
| Phone | OnePlus 12 |
| Chipset | Snapdragon 8 Gen 3 (8 cores visible to Linux) |
| Memory | ~11.5 GB visible to the userland (`MemTotal`) |
| Kernel | Linux 6.1.157-android14-11 (aarch64) |
| Host OS | Android 14-based OxygenOS |

The phone stays a phone. Everything below runs in an isolated Linux userland
alongside Android, inside [Buddy](https://github.com/ghorbelhamdi/buddy-android),
the on-device assistant that exposes the shell and the phone's UI to an agent.

## The Linux userland

Verified from a live shell on the device:

| Component | Version / value |
|---|---|
| Distribution | Alpine Linux 3.24.2 |
| Architecture | aarch64 |
| Python | 3.14.10 |
| pip | 26.1.2 |
| Node.js | 24.22.3 |
| npm | 11.12.1 |
| git | 2.54.1 |
| GitHub CLI | 2.97.0 |
| Workspace | `/root/.buddy/work` |
| CPUs / RAM | 8 cores / ~11.5 GB |
| Python deps | standard library only |

Alpine keeps the image small, which matters when the whole operating system
is a guest on a phone. The trade-off is musl instead of glibc: prebuilt wheels
are scarcer, so this repo deliberately avoids third-party packages.

## How the agent fits in

The workflow is conversational rather than IDE-driven:

1. **Ask** in the Buddy chat bubble — "build me a health check for this box".
2. The agent **reads the device state** (shell, screen, notifications) to ground
   itself in facts instead of assumptions.
3. It **writes and runs** code in `/root/.buddy/work/<project>/`.
4. Anything outward-facing — a push, a post, a payment — stops at an
   **approval card** before it happens.

That last point is the safety model: full local autonomy, human consent at the
boundary where the work leaves the device.

## Workspace rules

[`AGENTS.md`](AGENTS.md) is the binding contract for this repository. It covers:

| Area | What it enforces |
|---|---|
| Planning | `PLAN.md` with executable definition of done, scope caps |
| Python / Node.js | stdlib-first, pinned deps, `unittest` / `node --test` |
| Android (ARM64) | plain Java + `aapt2`/`d8`/`apksigner`, no Gradle, user-installed |
| Alpine / musl | no glibc binaries, `apk` over tarballs, busybox-safe scripts |
| GitHub | branch/commit discipline; `workflow` and `delete_repo` scopes absent |
| Testing & debugging | layered gates, reproduce-first, regression test per fix |
| Error recovery | failure classes, retry budget, no blind re-sends |
| Licensing | free and open source only, no paid APIs or key-gated tools |
| Secrets | redaction, `.env` ignored, pre-commit token scan, rotate on leak |
| Backups | verified `tar.gz` + git bundle before destructive work |
| Approval | push, publish, delete, pay — explicit consent every time |

Project-level `AGENTS.md` files may add rules but never weaken those.

## Scaffolding a project

`scripts/new-project.sh` copies `templates/project/`, fills in the name and
date, initialises git on `main`, commits, and runs the new project's tests.

```bash
scripts/new-project.sh my-tool            # -> ../my-tool
scripts/new-project.sh my-tool ~/code     # -> ~/code/my-tool
cd ../my-tool && ./run-tests.sh
```

The template ships a Python package (`src/<package>/`), `unittest` smoke
tests, `PLAN.md`, a project `AGENTS.md`, and a `.gitignore` for Python and
Node.js. It refuses to overwrite an existing directory, and it never creates
a remote — publishing stays a separate, approved step.

## Testing the workspace

```bash
scripts/check-repo.sh          # full gate
scripts/check-repo.sh --keep   # keep smoke-test artifacts in build/
```

It runs seven steps: shell syntax, Python compilation, unit tests,
`healthcheck.py` (text + JSON), a backup round-trip, a template scaffold that
is tested and discarded, and a credential-pattern scan over tracked and
untracked files. Green output on this device:

```
PASS  all shell scripts parse
PASS  all Python files compile
PASS  unit tests
PASS  healthcheck.py exits 0
PASS  healthcheck.py --json is valid and ok
PASS  backup archive created and lists data
PASS  scaffold has no leftover placeholders
PASS  scaffolded project tests pass
PASS  scaffolded CLI runs
PASS  scaffold has an initial commit
PASS  no credential-shaped strings in working tree
----------------------------------------------
11 passed, 0 failed
```

## Backups before destructive work

```bash
scripts/backup.sh .                      # current project
scripts/backup.sh ~/work/other --keep 5  # custom retention
```

Each run writes a verified `tar.gz` (caches, venvs and `.git` excluded) and,
for git repositories, a verified `git bundle`, into `~/.buddy/backups`. Old
snapshots beyond the retention limit are pruned; the newest is never touched.

## The health check

`healthcheck.py` reports on Python, Node.js, git, GitHub CLI, disk, memory
and the workspace, with a `PASS` / `WARN` / `FAIL` verdict per check.

```bash
# human-readable
python3 healthcheck.py

# machine-readable
python3 healthcheck.py --json

# also test outbound HTTPS to api.github.com (opt-in, off by default)
python3 healthcheck.py --network
```

Exit codes: `0` all checks passed (warnings allowed), `1` at least one failure.

Example:

```
buddy-ai-workstation health check
host:      buddy-alpine  (Linux aarch64)
----------------------------------------------
PASS  python       3.14.10 (>= 3.10)
PASS  node.js      v24.22.3
PASS  git          git version 2.54.1
PASS  gh           2.97.0
PASS  disk         106.3 GB free of 217.5 GB
PASS  memory       2.1 GB available of 11.0 GB (19%)
PASS  workspace    /root/.buddy/work/buddy-ai-workstation writable
----------------------------------------------
7 passed, 0 warnings, 0 failed
```

`disk` reports the Linux image's own filesystem, which is not the phone's
user storage — don't read it as free space in Android.

## Layout

```
buddy-ai-workstation/
├── AGENTS.md            # binding agent rules (planning, safety, backups)
├── PLAN.md              # workspace plan and phase history
├── README.md            # this file
├── LICENSE              # MIT
├── healthcheck.py       # dependency-free environment probe
├── .gitignore           # Python + Node.js
├── scripts/
│   ├── new-project.sh   # scaffold from templates/project
│   ├── check-repo.sh    # seven-step test gate
│   └── backup.sh        # verified snapshot before destructive work
├── templates/project/   # reusable starter: package, tests, docs, plan
│   ├── AGENTS.md
│   ├── PLAN.md
│   ├── README.md
│   ├── .gitignore
│   ├── run-tests.sh
│   ├── src/{{PACKAGE}}/
│   └── tests/test_smoke.py
└── tests/
    └── test_healthcheck.py
```

## Running it on your own phone

You need a Linux userland with Python 3.10+ (Termux works). Everything else
is optional — missing tools degrade to `WARN`, never to a crash:

```bash
git clone https://github.com/hexxrr/buddy-ai-workstation.git
cd buddy-ai-workstation
python3 healthcheck.py
```

## License

MIT
