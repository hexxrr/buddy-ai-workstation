# buddy-ai-workstation

A pocket-sized AI development workstation: this repo documents the
**OnePlus 12** environment I use to build and run code directly on the phone,
and ships a single-file health check that proves the toolchain is intact.

No laptop. No cloud IDE. Just a phone, a Linux userland, and an AI agent.

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
├── PLAN.md          # scope, decisions, verification
├── README.md        # this file
├── healthcheck.py   # dependency-free environment probe
└── .gitignore       # Python + Node.js
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
