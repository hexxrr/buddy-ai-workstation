#!/usr/bin/env python3
"""Health check for the OnePlus 12 on-device AI development workstation.

Dependency-free by design: only the Python standard library is used, so this
runs on a bare Alpine/Termux userland with nothing installed.

    python3 healthcheck.py            # human-readable report
    python3 healthcheck.py --json     # machine-readable report
    python3 healthcheck.py --network  # also test outbound HTTPS (opt-in)

Exit status: 0 when no check fails, 1 when at least one check fails.
Optional tools that are simply absent report WARN, never crash the run.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

PASS, WARN, FAIL = "PASS", "WARN", "FAIL"
MIN_PYTHON = (3, 10)
NETWORK_URL = "https://api.github.com/zen"
NETWORK_TIMEOUT = 5.0

# Windows/macOS consoles still choke on box drawing; keep the glyphs ASCII.
RULE = "-" * 46


def run(cmd: list[str]) -> str | None:
    """Return the first line of a command's stdout, or None if it can't run."""
    if shutil.which(cmd[0]) is None:
        return None
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    text = (out.stdout or out.stderr or "").strip()
    return text.splitlines()[0] if text else None


def human_bytes(n: int | float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return f"{n:.1f} TB"


def result(name: str, status: str, detail: str) -> dict:
    return {"check": name, "status": status, "detail": detail}


def check_python() -> dict:
    v = sys.version_info
    detail = f"{platform.python_version()} (>= {'.'.join(map(str, MIN_PYTHON))})"
    return result("python", PASS if v >= MIN_PYTHON else FAIL, detail)


def check_tool(
    name: str,
    cmd: list[str],
    pattern: str | None = None,
    required: bool = False,
) -> dict:
    raw = run(cmd)
    if raw is None:
        # A missing optional tool is a warning; a missing required one is fatal.
        return result(name, FAIL if required else WARN, "not found on PATH")
    if pattern:
        m = re.search(pattern, raw)
        if m:
            raw = m.group(0)
    return result(name, PASS, raw)


def check_disk() -> dict:
    try:
        usage = shutil.disk_usage(os.getcwd())
    except OSError as exc:
        return result("disk", WARN, f"unavailable ({exc.__class__.__name__})")
    free_gb = usage.free / 1024**3
    detail = f"{human_bytes(usage.free)} free of {human_bytes(usage.total)}"
    return result("disk", PASS if free_gb >= 1 else WARN, detail)


def check_memory() -> dict:
    try:
        with open("/proc/meminfo", encoding="ascii") as fh:
            info = dict(
                (k.rstrip(":"), int(v.split()[0]) * 1024)
                for k, v in (line.split(":", 1) for line in fh if ":" in line)
            )
    except (OSError, ValueError):
        return result("memory", WARN, "not readable on this platform")

    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    if not total:
        return result("memory", WARN, "MemTotal missing")
    pct = avail / total * 100
    detail = f"{human_bytes(avail)} available of {human_bytes(total)} ({pct:.0f}%)"
    return result("memory", PASS if pct >= 5 else WARN, detail)


def check_workspace() -> dict:
    cwd = os.getcwd()
    try:
        with tempfile.NamedTemporaryFile(dir=cwd, prefix=".hc-", delete=True):
            pass
    except OSError as exc:
        return result("workspace", FAIL, f"{cwd} not writable ({exc.strerror})")
    return result("workspace", PASS, f"{cwd} writable")


def check_network() -> dict:
    request = urllib.request.Request(
        NETWORK_URL, headers={"User-Agent": "buddy-ai-workstation-healthcheck"}
    )
    try:
        with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as resp:
            body = resp.read(80).decode("utf-8", "replace").strip()
    except Exception as exc:  # noqa: BLE001 - network errors are all reportable
        return result("network", WARN, f"{exc.__class__.__name__}: {exc}")
    return result("network", PASS, f"HTTP {resp.status} from api.github.com")


def collect(network: bool = False) -> list[dict]:
    checks = [
        check_python(),
        check_tool("node.js", ["node", "--version"]),
        check_tool("git", ["git", "--version"]),
        check_tool("gh", ["gh", "--version"], pattern=r"\d+\.\d+\.\d+"),
        check_disk(),
        check_memory(),
        check_workspace(),
    ]
    if network:
        checks.append(check_network())
    return checks


def report(checks: list[dict], as_json: bool) -> int:
    counts = {s: sum(1 for c in checks if c["status"] == s) for s in (PASS, WARN, FAIL)}

    if as_json:
        payload = {
            "host": platform.node(),
            "platform": f"{platform.system()} {platform.machine()}",
            "python": platform.python_version(),
            "checks": checks,
            "summary": {
                "passed": counts[PASS],
                "warnings": counts[WARN],
                "failed": counts[FAIL],
            },
            "ok": counts[FAIL] == 0,
        }
        print(json.dumps(payload, indent=2))
    else:
        print("buddy-ai-workstation health check")
        print(f"host:      {platform.node()}  ({platform.system()} {platform.machine()})")
        print(RULE)
        width = max(len(c["check"]) for c in checks)
        for c in checks:
            print(f"{c['status']:<4}  {c['check']:<{width}}  {c['detail']}")
        print(RULE)
        print(
            f"{counts[PASS]} passed, {counts[WARN]} warnings, {counts[FAIL]} failed",
            file=sys.stdout if counts[FAIL] == 0 else sys.stderr,
        )

    return 0 if counts[FAIL] == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check the health of this on-device AI development environment."
    )
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    parser.add_argument(
        "--network",
        action="store_true",
        help="also test outbound HTTPS to api.github.com",
    )
    args = parser.parse_args(argv)
    return report(collect(network=args.network), as_json=args.json)


if __name__ == "__main__":
    raise SystemExit(main())
