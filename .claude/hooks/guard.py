#!/usr/bin/env python3
"""PreToolUse guard for Bash calls: no force-push, no push to main, no PR merge.

Reads the hook payload on stdin. A blocked call gets a deny decision with the
reason on stdout; every other call passes untouched (no output, exit 0).

A guard rail, not a security boundary: the `main` ruleset is the real block.
Tests: test_hooks.py, fixtures in fixtures/guard/.
"""

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

MAIN = "main"

FORCE = (
    "Force-pushing is blocked: published history is the user's to rewrite. "
    "Push new commits instead (AGENTS.md → Git and pull requests)."
)
TO_MAIN = (
    "Pushing to main is blocked: changes reach main only through a squash-merged PR. "
    "Push a <type>/<issue>-<slug> branch and open a PR."
)
MERGE = "Merging a PR is the user's step on GitHub. Hand them the PR URL instead."

# Shell operators end a simple command; a redirection takes the next word as its target.
OPERATORS = re.compile(r"^[;&|()<>]+$")
REDIRECT = re.compile(r"^&?[<>]+&?$")
# Words that run the command that follows them.
WRAPPERS = {"command", "env", "exec", "nice", "nohup", "rtk", "sudo", "time"}
SHELLS = {"bash", "sh", "zsh"}
# git options that take the next word as their value.
GIT_VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
PUSH_VALUE_OPTS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
# GitHub API calls that merge: REST pulls/{n}/merge and /merges (unless a read-only
# GET), and the GraphQL merge mutations.
REST_MERGE = re.compile(r"/pulls/[^/\s]+/merge\b|/merges\b")
GRAPHQL_MERGE = re.compile(r"\bmergePullRequest\b|\benablePullRequestAutoMerge\b")
# `gh api` sends a POST when it has fields or input and no explicit method.
API_BODY_OPTS = ("-f", "-F", "--field", "--raw-field", "--input")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as err:
        print(f"guard: unreadable hook input: {err}", file=sys.stderr)
        return 1
    if payload.get("tool_name") != "Bash":
        return 0
    command = payload.get("tool_input", {}).get("command", "")
    reason = check(command, payload.get("cwd") or ".")
    if reason:
        decision = {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
        print(json.dumps({"hookSpecificOutput": decision}))
    return 0


def check(command: str, cwd: str) -> str | None:
    """Return the deny reason for the first blocked simple command, or None."""
    for words in simple_commands(command):
        reason = check_words(strip_wrappers(words), cwd)
        if reason:
            return reason
    return None


def check_words(words: list[str], cwd: str) -> str | None:
    if not words:
        return None
    name = Path(words[0]).name
    if name in SHELLS and "-c" in words[:-1]:
        return check(words[words.index("-c") + 1], cwd)
    if name == "eval":
        return check(" ".join(words[1:]), cwd)
    if name == "git":
        return check_git(words[1:], cwd)
    if name == "gh":
        return check_gh(words[1:])
    return None


def check_git(args: list[str], cwd: str) -> str | None:
    i = 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] == "-C" and i + 1 < len(args):
            cwd = str(Path(cwd) / args[i + 1])
        i += 2 if args[i] in GIT_VALUE_OPTS else 1
    if i < len(args) and args[i] == "push":
        return check_push(args[i + 1 :], cwd)
    return None


def check_push(args: list[str], cwd: str) -> str | None:
    positional: list[str] = []
    pushes_all = False
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in PUSH_VALUE_OPTS:
            i += 2
            continue
        if arg in ("--force", "--force-with-lease") or arg.startswith("--force-with-lease="):
            return FORCE
        if re.fullmatch(r"-[a-zA-Z]*f[a-zA-Z]*", arg):
            return FORCE
        if arg in ("--all", "--branches", "--mirror"):
            pushes_all = True
        elif arg == "--":
            positional.extend(args[i + 1 :])
            break
        elif not arg.startswith("-"):
            positional.append(arg)
        i += 1

    refspecs = positional[1:]
    if any(ref.startswith("+") for ref in refspecs):
        return FORCE
    if pushes_all:
        return TO_MAIN
    if not refspecs:
        refspecs = ["HEAD"]
    for ref in refspecs:
        target = ref.split(":", 1)[1] if ":" in ref else ref
        if target in ("HEAD", "@"):
            target = current_branch(cwd)
        if target.removeprefix("refs/heads/") == MAIN:
            return TO_MAIN
    return None


def check_gh(args: list[str]) -> str | None:
    if args[:2] == ["pr", "merge"]:
        return MERGE
    if args[:1] != ["api"]:
        return None
    if any(GRAPHQL_MERGE.search(arg) for arg in args[1:]):
        return MERGE
    if any(REST_MERGE.search(arg) for arg in args[1:]) and api_method(args[1:]) != "GET":
        return MERGE
    return None


def api_method(args: list[str]) -> str:
    for i, arg in enumerate(args):
        if arg in ("-X", "--method") and i + 1 < len(args):
            return args[i + 1].upper()
        if arg.startswith("--method="):
            return arg.split("=", 1)[1].upper()
        if arg.startswith("-X") and len(arg) > 2:
            return arg[2:].upper()
    has_body = any(arg.split("=", 1)[0] in API_BODY_OPTS for arg in args)
    return "POST" if has_body else "GET"


def current_branch(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],  # noqa: S607 - git from PATH, as the agent runs it
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip()


def simple_commands(command: str) -> list[list[str]]:
    """Split a shell command line into simple commands (word lists)."""
    lexer = shlex.shlex(
        unquoted_newlines_to_semicolons(command), posix=True, punctuation_chars=True
    )
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:  # unbalanced quotes: fall back to plain words
        tokens = command.split()
    commands: list[list[str]] = [[]]
    skip_target = False
    for token in tokens:
        if skip_target:
            skip_target = False
        elif REDIRECT.match(token):
            if commands[-1] and commands[-1][-1].isdigit():
                commands[-1].pop()  # the fd in 2>&1
            skip_target = True
        elif OPERATORS.match(token):
            commands.append([])
        else:
            commands[-1].append(token)
    return [words for words in commands if words]


def unquoted_newlines_to_semicolons(command: str) -> str:
    """shlex treats newlines as spaces; outside quotes they separate commands."""
    out: list[str] = []
    quote = ""
    escaped = False
    for char in command:
        if escaped:
            escaped = False
        elif char == "\\" and quote != "'":
            escaped = True
        elif quote:
            quote = "" if char == quote else quote
        elif char in "'\"":
            quote = char
        elif char == "\n":
            out.append(";")
            continue
        out.append(char)
    return "".join(out)


def strip_wrappers(words: list[str]) -> list[str]:
    """Drop leading VAR=value assignments and wrappers such as env or rtk."""
    i = 0
    while i < len(words):
        word = words[i]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", word) or word in WRAPPERS:
            i += 1
        elif word.startswith("-") and i > 0 and words[i - 1] in WRAPPERS:
            i += 1  # wrapper option, e.g. `env -i`
        else:
            break
    return words[i:]


if __name__ == "__main__":
    sys.exit(main())
