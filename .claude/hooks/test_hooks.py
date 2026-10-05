"""Tests for the Claude Code hooks in this directory, except the guard (test_guard.py).

Run: python3 -m unittest discover -s .claude/hooks
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS = Path(__file__).resolve().parent
GUARD = HOOKS / "guard.py"
FORMAT = HOOKS / "format.py"
STOP = HOOKS / "stop.py"
# A generated project's justfile: format.py formats only when it has a fmt recipe.
FMT_JUSTFILE = "fmt:\n    golangci-lint fmt\n"
TEMPLATE_JUSTFILE = "fast: agents-md claude-md\n\nagents-md:\n    scripts/check-agents-md.sh 150\n"


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


class Settings(unittest.TestCase):
    def test_settings_wire_hooks_and_deny_merge(self) -> None:
        settings = json.loads((HOOKS.parent / "settings.json").read_text())
        commands = {
            (event, entry.get("matcher", "")): hook["command"]
            for event, entries in settings["hooks"].items()
            for entry in entries
            for hook in entry["hooks"]
        }
        self.assertIn("guard.py", commands[("PreToolUse", "Bash")])
        self.assertIn("format.py", commands[("PostToolUse", "Edit|MultiEdit|Write")])
        self.assertIn("stop.py", commands[("Stop", "")])
        for rule in ("Bash(gh pr merge)", "Bash(gh pr merge *)"):
            self.assertIn(rule, settings["permissions"]["deny"])

    def test_justfiles_have_fast_recipe(self) -> None:
        # The template repo: templates/*/justfile carry the shared fast gate, and
        # its root justfile names its own. A generated project has no templates/
        # (project-init deletes it); its root justfile is the copied one.
        repo = HOOKS.parent.parent
        for justfile in repo.glob("templates/*/justfile"):
            with self.subTest(justfile=str(justfile.relative_to(repo))):
                self.assertIn("fast: fmt-check lint test", justfile.read_text().splitlines())
        self.assertRegex((repo / "justfile").read_text(), r"(?m)^fast:")


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
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        result = self.edit("internal/a/a.go")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"golangci-lint fmt {self.project / 'internal/a/a.go'}"])

    def test_python_file_formats_only_that_file(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        result = self.edit("src/pkg/mod.py", tool="Write")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"uv run ruff format {self.project / 'src/pkg/mod.py'}"])

    def test_other_files_untouched(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        for rel in ("README.md", "go.mod", ".github/workflows/ci.yml"):
            self.assertEqual(self.edit(rel).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_markdown_edit_is_noop(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        result = self.edit("docs/guide.md")
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.calls(), [])

    def test_file_outside_project_untouched(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        outside = self.root / "elsewhere.go"
        outside.write_text("x\n")
        payload = {"tool_name": "Edit", "tool_input": {"file_path": str(outside)}}
        self.assertEqual(run_hook(FORMAT, payload, self.env).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_template_repo_is_noop(self) -> None:
        # The template's root justfile has gates but no fmt recipe: nothing to format.
        (self.project / "justfile").write_text(TEMPLATE_JUSTFILE)
        result = self.edit("main.go")
        self.assertEqual((result.returncode, result.stdout), (0, ""))
        self.assertEqual(self.calls(), [])

    def test_formatter_failure_never_blocks(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
        self.fake("golangci-lint", 3)
        result = self.edit("main.go")
        self.assertEqual((result.returncode, result.stdout), (0, ""))

    def test_missing_formatter_never_blocks(self) -> None:
        (self.project / "justfile").write_text(FMT_JUSTFILE)
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


class Stop(unittest.TestCase):
    """A real git repo and a fake `just` on PATH that logs each call and exits with a set code."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()
        self.project = self.root / "project"
        git_repo(self.project, "feat/x")
        (self.project / "justfile").write_text("fast:\n")
        (self.project / "main.go").write_text("package main\n")
        self.git("add", "-A")
        self.git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.log"
        self.just(0)
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "CLAUDE_PROJECT_DIR": str(self.project),
        }

    def git(self, *args: str) -> None:
        subprocess.run(["git", *args], cwd=self.project, check=True, capture_output=True)

    def just(self, code: int, output: str = "") -> None:
        tool = self.bin / "just"
        tool.write_text(
            f'#!/bin/sh\necho "just $*" >> "{self.log}"\nprintf %s "{output}"\nexit {code}\n'
        )
        tool.chmod(tool.stat().st_mode | stat.S_IEXEC)

    def stop(self, active: bool = False) -> subprocess.CompletedProcess:
        payload = {"hook_event_name": "Stop", "cwd": str(self.project), "stop_hook_active": active}
        return run_hook(STOP, payload, self.env)

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def assert_silent(self, result: subprocess.CompletedProcess) -> None:
        self.assertEqual((result.returncode, result.stdout), (0, ""), result.stderr)

    def test_no_change_skips_gate(self) -> None:
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), [])

    def test_change_and_pass_records_state(self) -> None:
        (self.project / "main.go").write_text("package main\n\nfunc main() {}\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"])
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"], "unchanged tree after a pass must not rerun")
        (self.project / "main.go").write_text("package main\n")
        self.assert_silent(self.stop())
        self.assertEqual(len(self.calls()), 2, "a later change runs the gate again")

    def test_pass_is_recorded_outside_the_tree(self) -> None:
        (self.project / "main.go").write_text("changed\n")
        self.assert_silent(self.stop())
        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=self.project,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(status.stdout.splitlines(), [" M main.go"])

    def test_dirty_tree_without_record_runs_once(self) -> None:
        # ASSUMP-1: with no passing record, the baseline is HEAD's tree.
        (self.project / "main.go").write_text("uncommitted before the session\n")
        self.assert_silent(self.stop())
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"])

    def test_untracked_file_counts_as_change(self) -> None:
        (self.project / "new.go").write_text("package main\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"])

    def test_docs_only_change_skips_gate(self) -> None:
        (self.project / "docs").mkdir()
        (self.project / "docs" / "guide.md").write_text("# Guide\n")
        (self.project / "README.md").write_text("# Readme\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), [])

    def test_root_markdown_read_by_the_gate_runs_it(self) -> None:
        for runs, name in enumerate(("AGENTS.md", "CLAUDE.md"), start=1):
            with self.subTest(file=name):
                (self.project / name).write_text("@AGENTS.md\n")
                self.assert_silent(self.stop())
                self.assertEqual(self.calls(), ["just fast"] * runs)

    def test_record_with_pruned_tree_runs_gate(self) -> None:
        # The record names a tree git no longer has: the gate must run, not skip.
        record = subprocess.run(
            ["git", "rev-parse", "--git-path", "sdd-fast-gate"],
            cwd=self.project,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        (self.project / record).write_text("0" * 40 + "\n")
        (self.project / "README.md").write_text("# Readme\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"])

    def test_docs_then_code_runs_gate_on_the_whole_turn(self) -> None:
        (self.project / "README.md").write_text("# Readme\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), [])
        (self.project / "main.go").write_text("package main\n\nfunc main() {}\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), ["just fast"])

    def test_change_and_fail_blocks_with_output(self) -> None:
        self.just(1, "main.go:1: undefined: foo")
        (self.project / "main.go").write_text("broken\n")
        result = self.stop()
        self.assertEqual(result.returncode, 0, result.stderr)
        out = json.loads(result.stdout)
        self.assertEqual(out["decision"], "block")
        self.assertIn("main.go:1: undefined: foo", out["reason"])
        self.stop()
        self.assertEqual(len(self.calls()), 2, "a failure is not recorded, so the next stop reruns")

    def test_long_output_keeps_the_tail(self) -> None:
        self.just(1, "x" * 20000 + "LAST-LINE")
        (self.project / "main.go").write_text("broken\n")
        reason = json.loads(self.stop().stdout)["reason"]
        self.assertTrue(reason.endswith("LAST-LINE"))
        self.assertLess(len(reason), 9000)

    def test_stop_hook_active_never_blocks_again(self) -> None:
        self.just(1, "still broken")
        (self.project / "main.go").write_text("broken\n")
        self.assert_silent(self.stop(active=True))
        self.assertEqual(self.calls(), [])

    def test_template_repo_is_noop(self) -> None:
        (self.project / "justfile").unlink()
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), [])

    def test_missing_just_never_blocks(self) -> None:
        (self.project / "main.go").write_text("changed\n")
        (self.bin / "just").unlink()
        env = {**self.env, "PATH": f"{self.bin}{os.pathsep}{Path(shutil.which('git')).parent}"}
        payload = {"hook_event_name": "Stop", "cwd": str(self.project), "stop_hook_active": False}
        self.assert_silent(run_hook(STOP, payload, env))

    def test_not_a_git_repo_never_blocks(self) -> None:
        shutil.rmtree(self.project / ".git")
        (self.project / "main.go").write_text("changed\n")
        self.assert_silent(self.stop())
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
