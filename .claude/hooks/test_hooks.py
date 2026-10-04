"""Fixture tests for the Claude Code hooks in this directory.

Run: python3 -m unittest discover -s .claude/hooks

Each fixtures/guard/*.json holds a PreToolUse payload, the branch checked out
in the repo the payload's cwd points to, and the expected decision.
"""

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS = Path(__file__).resolve().parent
GUARD = HOOKS / "guard.py"
FORMAT = HOOKS / "format.py"
FIXTURES = HOOKS / "fixtures" / "guard"


def git_repo(path: Path, branch: str) -> None:
    subprocess.run(["git", "init", "-q", "-b", branch, str(path)], check=True)


def run_hook(script: Path, payload: dict, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(script)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
        check=False,
        timeout=30,
    )


class GuardFixtures(unittest.TestCase):
    def test_fixtures(self) -> None:
        fixtures = sorted(FIXTURES.glob("*.json"))
        self.assertTrue(fixtures, "no guard fixtures found")
        for fixture in fixtures:
            case = json.loads(fixture.read_text())
            with self.subTest(fixture=fixture.stem), tempfile.TemporaryDirectory() as tmp:
                git_repo(Path(tmp), case["branch"])
                payload = case["input"]
                payload["cwd"] = tmp
                result = run_hook(GUARD, payload)
                self.assertEqual(result.returncode, 0, result.stderr)
                if case["want"] == "allow":
                    self.assertEqual(result.stdout, "", "allow must leave the call untouched")
                    continue
                out = json.loads(result.stdout)["hookSpecificOutput"]
                self.assertEqual(out["hookEventName"], "PreToolUse")
                self.assertEqual(out["permissionDecision"], "deny")
                self.assertTrue(out["permissionDecisionReason"])

    def test_non_bash_tool_passes(self) -> None:
        payload = {"hook_event_name": "PreToolUse", "tool_name": "Read", "tool_input": {}}
        result = run_hook(GUARD, payload)
        self.assertEqual((result.returncode, result.stdout), (0, ""))


class Settings(unittest.TestCase):
    def test_settings_wire_both_hooks_and_deny_merge(self) -> None:
        settings = json.loads((HOOKS.parent / "settings.json").read_text())
        commands = {
            (event, entry["matcher"]): hook["command"]
            for event, entries in settings["hooks"].items()
            for entry in entries
            for hook in entry["hooks"]
        }
        self.assertIn("guard.py", commands[("PreToolUse", "Bash")])
        self.assertIn("format.py", commands[("PostToolUse", "Edit|MultiEdit|Write")])
        for rule in ("Bash(gh pr merge)", "Bash(gh pr merge *)"):
            self.assertIn(rule, settings["permissions"]["deny"])


class Format(unittest.TestCase):
    """A fake formatter on PATH records its arguments, so the tests need no toolchain."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()  # macOS: /var is a symlink
        self.project = self.root / "project"
        self.project.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.log"
        self.fake("golangci-lint", 0)
        self.fake("uv", 0)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "CLAUDE_PROJECT_DIR": str(self.project),
        }

    def fake(self, name: str, code: int) -> None:
        tool = self.bin / name
        tool.write_text(f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\nexit {code}\n')
        tool.chmod(tool.stat().st_mode | stat.S_IEXEC)

    def edit(self, rel: str, tool: str = "Edit") -> subprocess.CompletedProcess:
        path = self.project / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("x\n")
        payload = {
            "hook_event_name": "PostToolUse",
            "tool_name": tool,
            "cwd": str(self.project),
            "tool_input": {"file_path": str(path)},
        }
        return run_hook(FORMAT, payload, self.env)

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_go_file_formats_only_that_file(self) -> None:
        (self.project / "justfile").write_text("")
        result = self.edit("internal/a/a.go")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"golangci-lint fmt {self.project / 'internal/a/a.go'}"])

    def test_python_file_formats_only_that_file(self) -> None:
        (self.project / "justfile").write_text("")
        result = self.edit("src/pkg/mod.py", tool="Write")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"uv run ruff format {self.project / 'src/pkg/mod.py'}"])

    def test_other_files_untouched(self) -> None:
        (self.project / "justfile").write_text("")
        for rel in ("README.md", "go.mod", ".github/workflows/ci.yml"):
            self.assertEqual(self.edit(rel).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_file_outside_project_untouched(self) -> None:
        (self.project / "justfile").write_text("")
        outside = self.root / "elsewhere.go"
        outside.write_text("x\n")
        payload = {"tool_name": "Edit", "tool_input": {"file_path": str(outside)}}
        self.assertEqual(run_hook(FORMAT, payload, self.env).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_template_repo_is_noop(self) -> None:
        result = self.edit("main.go")
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.calls(), [])

    def test_formatter_failure_never_blocks(self) -> None:
        (self.project / "justfile").write_text("")
        self.fake("golangci-lint", 3)
        result = self.edit("main.go")
        self.assertEqual((result.returncode, result.stdout), (0, ""))

    def test_missing_formatter_never_blocks(self) -> None:
        (self.project / "justfile").write_text("")
        (self.project / "main.go").write_text("x\n")
        env = {**self.env, "PATH": str(self.root / "empty")}
        payload = {"tool_name": "Edit", "tool_input": {"file_path": str(self.project / "main.go")}}
        result = run_hook(FORMAT, payload, env)
        self.assertEqual((result.returncode, result.stdout), (0, ""))

    def test_malformed_input_never_blocks(self) -> None:
        result = subprocess.run(
            [sys.executable, str(FORMAT)],
            input="not json",
            capture_output=True,
            text=True,
            env=self.env,
            check=False,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
