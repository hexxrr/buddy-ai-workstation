"""Tests for healthcheck.py — the workspace's own environment probe."""

from __future__ import annotations

import contextlib
import io
import json
import unittest

import healthcheck


class TestHumanBytes(unittest.TestCase):
    def test_bytes(self) -> None:
        self.assertEqual("512 B", healthcheck.human_bytes(512))

    def test_gigabytes(self) -> None:
        self.assertEqual("1.5 GB", healthcheck.human_bytes(int(1.5 * 1024**3)))

    def test_terabytes_passthrough(self) -> None:
        self.assertEqual("2.0 TB", healthcheck.human_bytes(2 * 1024**4))


class TestChecks(unittest.TestCase):
    def test_python_check_passes(self) -> None:
        check = healthcheck.check_python()
        self.assertEqual(healthcheck.PASS, check["status"])
        self.assertEqual("python", check["check"])

    def test_missing_optional_tool_warns(self) -> None:
        check = healthcheck.check_tool("definitely-not-a-tool", ["definitely-not-a-tool"])
        self.assertEqual(healthcheck.WARN, check["status"])
        self.assertIn("not found", check["detail"])

    def test_missing_required_tool_fails(self) -> None:
        check = healthcheck.check_tool(
            "definitely-not-a-tool", ["definitely-not-a-tool"], required=True
        )
        self.assertEqual(healthcheck.FAIL, check["status"])

    def test_workspace_is_writable(self) -> None:
        self.assertEqual(healthcheck.PASS, healthcheck.check_workspace()["status"])

    def test_disk_and_memory_have_status(self) -> None:
        for check in (healthcheck.check_disk(), healthcheck.check_memory()):
            self.assertIn(check["status"], {healthcheck.PASS, healthcheck.WARN})


class TestReport(unittest.TestCase):
    def test_json_report_is_parseable_and_ok(self) -> None:
        checks = [healthcheck.result("demo", healthcheck.PASS, "fine")]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = healthcheck.report(checks, as_json=True)
        payload = json.loads(buf.getvalue())
        self.assertEqual(0, code)
        self.assertTrue(payload["ok"])
        self.assertEqual(1, payload["summary"]["passed"])

    def test_failure_sets_exit_code(self) -> None:
        checks = [healthcheck.result("demo", healthcheck.FAIL, "broken")]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(
            io.StringIO()
        ):
            code = healthcheck.report(checks, as_json=True)
        self.assertEqual(1, code)

    def test_collect_returns_named_checks(self) -> None:
        names = [c["check"] for c in healthcheck.collect()]
        self.assertIn("python", names)
        self.assertIn("workspace", names)
        self.assertNotIn("network", names)


if __name__ == "__main__":
    unittest.main()
