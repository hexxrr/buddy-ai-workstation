"""Tests for {{TITLE}}. Standard library only; no network, no real clock."""

from __future__ import annotations

import contextlib
import io
import json
import unittest

from {{PACKAGE}} import __project__, __version__
from {{PACKAGE}}.__main__ import main


class TestMetadata(unittest.TestCase):
    def test_version_is_semver_like(self) -> None:
        parts = __version__.split(".")
        self.assertEqual(3, len(parts))
        self.assertTrue(all(p.isdigit() for p in parts), __version__)

    def test_project_name(self) -> None:
        self.assertEqual("{{PROJECT_NAME}}", __project__)


class TestCli(unittest.TestCase):
    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_human_output(self) -> None:
        code, out, err = self.run_cli()
        self.assertEqual(0, code)
        self.assertIn(__project__, out)
        self.assertEqual("", err)

    def test_json_output(self) -> None:
        code, out, _ = self.run_cli("--json")
        self.assertEqual(0, code)
        payload = json.loads(out)
        self.assertEqual(__project__, payload["project"])
        self.assertEqual("ok", payload["status"])

    def test_unknown_flag_fails(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                main(["--not-a-flag"])
        self.assertEqual(2, ctx.exception.code)


if __name__ == "__main__":
    unittest.main()
