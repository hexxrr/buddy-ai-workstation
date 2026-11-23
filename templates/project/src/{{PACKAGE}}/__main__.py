"""Command-line entry point for {{TITLE}}.

    PYTHONPATH=src python3 -m {{PACKAGE}}
    PYTHONPATH=src python3 -m {{PACKAGE}} --json

Exits 0 on success, 2 on bad usage. Machine-readable output goes behind
--json; human output stays on stdout, errors on stderr.
"""

from __future__ import annotations

import argparse
import json
import platform
import sys

from . import __project__, __version__


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=__project__,
        description="{{TITLE}} — replace this description with the real one.",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON output")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    payload = {
        "project": __project__,
        "status": "ok",
        "version": __version__,
        "python": platform.python_version(),
    }

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"{__project__} {__version__} — ok on Python {platform.python_version()}")
        print("Replace this with the tool's actual work.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
