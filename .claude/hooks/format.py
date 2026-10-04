#!/usr/bin/env python3
"""PostToolUse hook: format the one Go or Python file the agent just edited.

Uses the project's formatter (the same tools as `just fmt`, on that file only).
No-op in the template repo, which has no justfile yet. Never blocks the edit:
every failure, a missing formatter included, ends in exit 0 with no output;
`just fmt-check` in the pre-commit hook and CI still catches what this misses.
Tests: test_hooks.py.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

FORMATTERS = {
    ".go": ["golangci-lint", "fmt"],
    ".py": ["uv", "run", "ruff", "format"],
    ".pyi": ["uv", "run", "ruff", "format"],
}


def main() -> None:
    try:
        payload = json.load(sys.stdin)
        project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or ".").resolve()
        target = Path(payload["tool_input"]["file_path"]).resolve()
    except (json.JSONDecodeError, KeyError, TypeError, OSError):
        return
    formatter = FORMATTERS.get(target.suffix)
    if not formatter or not (project / "justfile").is_file() or not target.is_file():
        return
    if not target.is_relative_to(project):
        return
    try:
        subprocess.run(  # noqa: S603 - fixed argv, the path is the file the agent edited
            [*formatter, str(target)],
            cwd=project,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return


if __name__ == "__main__":
    main()
