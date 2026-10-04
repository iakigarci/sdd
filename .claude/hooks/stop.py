#!/usr/bin/env python3
"""Stop hook: run `just fast` when the code changed, and send failures back to the agent.

The working tree (tracked and untracked files, .gitignore respected) is
fingerprinted as a git tree hash. The gate runs only when that hash differs from
the last passing run, recorded in the git directory, outside the working tree.
With no record yet, the baseline is HEAD's tree, so a turn that changed nothing
costs one `git add` into a scratch index and nothing more.

On failure the stop is blocked with the tail of the output as the reason; on
success the hash is recorded. When `stop_hook_active` is set the agent is
already continuing because of this hook, so it never blocks twice in a row.
No-op without a justfile (the template repo). Infrastructure failures (no git,
no just, a timeout) never block: `just check` in CI is still the real gate.
Tests: test_hooks.py.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RECORD = "sdd-fast-gate"
GATE_TIMEOUT = 540  # below the hook timeout in settings.json, so a slow gate fails open
MAX_REASON = 8000  # characters of output kept; the tail holds the failures


class GitError(Exception):
    pass


def git(project: Path, *args: str, env: dict | None = None) -> str:
    try:
        result = subprocess.run(  # noqa: S603 - fixed git argv
            ["git", *args],
            cwd=project,
            env=env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired) as err:
        raise GitError(str(err)) from err
    if result.returncode != 0:
        raise GitError(result.stderr.strip())
    return result.stdout.strip()


def tree_hash(project: Path) -> str:
    """Hash of the whole working tree, written through a scratch copy of the index."""
    index = project / git(project, "rev-parse", "--git-path", "index")
    with tempfile.TemporaryDirectory() as tmp:
        scratch = Path(tmp) / "index"
        if index.is_file():
            shutil.copyfile(index, scratch)  # keeps git's stat cache: only changed files rehash
        env = {**os.environ, "GIT_INDEX_FILE": str(scratch)}
        git(project, "add", "-A", env=env)
        return git(project, "write-tree", env=env)


def baseline(project: Path, record: Path) -> str | None:
    if record.is_file():
        return record.read_text().strip()
    try:
        return git(project, "rev-parse", "--verify", "-q", "HEAD^{tree}")
    except GitError:
        return None  # no commits yet


def run_gate(project: Path) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(
            ["just", "fast"],  # noqa: S607 - just from PATH, as in every other gate
            cwd=project,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            check=False,
            timeout=GATE_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired) as err:
        print(f"stop hook: `just fast` did not run to completion: {err}", file=sys.stderr)
        return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
        project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or ".").resolve()
    except (json.JSONDecodeError, TypeError, AttributeError, OSError):
        return
    if payload.get("stop_hook_active") or not (project / "justfile").is_file():
        return
    try:
        record = project / git(project, "rev-parse", "--git-path", RECORD)
        current = tree_hash(project)
        if current == baseline(project, record):
            return
    except (GitError, OSError):
        return
    result = run_gate(project)
    if result is None:
        return
    if result.returncode == 0:
        try:
            record.write_text(current + "\n")
        except OSError:
            pass  # the next stop runs the gate again
        return
    output = result.stdout[-MAX_REASON:]
    reason = (
        f"`just fast` failed (exit {result.returncode}). Fix it before ending the turn:\n\n{output}"
    )
    print(json.dumps({"decision": "block", "reason": reason}))


if __name__ == "__main__":
    main()
