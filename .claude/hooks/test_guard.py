"""PreToolUse guard tests: one table of Bash commands and the decision each gets.

Run: python3 -m unittest discover -s .claude/hooks -v

Each row is (case name, branch checked out in the temporary repo, command, want).
The branch matters for the `main-current-*` cases, where the push target is HEAD.
A deny must return a reason; an allow must leave the call untouched.
"""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import guard
from test_hooks import GUARD, git_repo, run_hook

# Added with the early return: quoting and backslashes must not hide git or gh.
QUOTING_CASES = [
    ("force-quoted-letters", "feat/1-x", 'g"i"t push -f', "deny"),
    ("force-backslash-letters", "feat/1-x", "g\\it push -f", "deny"),
    ("allow-no-git-or-gh", "feat/1-x", "make push FORCE=1", "allow"),
]

CASES = [
    ('allow-feature-head', 'feat/1-x', 'git push origin HEAD', 'allow'),
    ('allow-feature-push-current', 'feat/1-x', 'git push', 'allow'),
    ('allow-feature-push', 'feat/1-x', 'git push -u origin feat/1-x', 'allow'),
    ('allow-feature-redirect', 'feat/1-x', 'git push -u origin feat/1-x > push.log 2>&1', 'allow'),
    ('allow-feature-refspec-from-main', 'main', 'git push origin feat/1-x', 'allow'),
    ('allow-gh-api-merged-check-explicit-get', 'feat/1-x', 'gh api --method GET repos/o/r/pulls/12/merge', 'allow'),
    ('allow-gh-api-merged-check', 'feat/1-x', 'gh api repos/o/r/pulls/12/merge', 'allow'),
    ('allow-gh-api-read', 'feat/1-x', 'gh api repos/o/r/pulls/12', 'allow'),
    ('allow-gh-pr-checks', 'feat/1-x', 'gh pr checks --watch', 'allow'),
    ('allow-gh-pr-create', 'feat/1-x', "gh pr create --title 'feat: x' --body-file body.md", 'allow'),
    ('allow-gh-pr-view-merge-state', 'feat/1-x', 'gh pr view 12 --json mergeStateStatus,mergeable', 'allow'),
    ('allow-git-fetch', 'main', 'git fetch origin main && git switch -c feat/2-y origin/main', 'allow'),
    ('allow-git-pull-main', 'main', 'git pull --ff-only origin main', 'allow'),
    ('allow-mainline-branch-name', 'feat/1-x', 'git push origin feat/1-maintenance', 'allow'),
    ('allow-quoted-text', 'feat/1-x', "git commit -m 'never git push --force to main'", 'allow'),
    ('allow-unparseable', 'feat/1-x', "echo 'unterminated", 'allow'),
    ('force-after-cd', 'feat/1-x', 'cd /tmp && git push -f origin feat/1-x', 'deny'),
    ('force-bash-c', 'feat/1-x', "bash -c 'git push --force origin feat/1-x'", 'deny'),
    ('force-env-prefix', 'feat/1-x', 'GIT_TRACE=1 git push -f', 'deny'),
    ('force-git-global-opts', 'feat/1-x', 'git -C . -c push.default=current push --force', 'deny'),
    ('force-long', 'feat/1-x', 'git push --force origin feat/1-x', 'deny'),
    ('force-plus-head-refspec', 'feat/1-x', 'git push origin +HEAD:feat/1-x', 'deny'),
    ('force-plus-refspec', 'feat/1-x', 'git push origin +feat/1-x', 'deny'),
    ('force-rtk-wrapper', 'feat/1-x', 'rtk git push --force', 'deny'),
    ('force-second-line', 'feat/1-x', 'git status\ngit push --force', 'deny'),
    ('force-short-cluster', 'feat/1-x', 'git push -uf origin feat/1-x', 'deny'),
    ('force-short', 'feat/1-x', 'git push -f', 'deny'),
    ('force-with-lease-value', 'feat/1-x', 'git push --force-with-lease=feat/1-x:abc123 origin feat/1-x', 'deny'),
    ('force-with-lease', 'feat/1-x', 'git push --force-with-lease origin feat/1-x', 'deny'),
    ('main-all', 'feat/1-x', 'git push --all origin', 'deny'),
    ('main-colon-delete', 'feat/1-x', 'git push origin :main', 'deny'),
    ('main-current-at', 'main', 'git push origin @', 'deny'),
    ('main-current-head', 'main', 'git push origin HEAD', 'deny'),
    ('main-current-no-refspec', 'main', 'git push', 'deny'),
    ('main-current-redirect', 'main', 'git push origin 2>&1 | tail -5', 'deny'),
    ('main-current-remote-only', 'main', 'git push origin', 'deny'),
    ('main-current-set-upstream', 'main', 'git push -u origin', 'deny'),
    ('main-delete', 'feat/1-x', 'git push origin --delete main', 'deny'),
    ('main-explicit', 'feat/1-x', 'git push origin main', 'deny'),
    ('main-full-ref', 'feat/1-x', 'git push origin feat/1-x:refs/heads/main', 'deny'),
    ('main-head-refspec', 'feat/1-x', 'git push origin HEAD:main', 'deny'),
    ('merge-api-graphql-auto', 'feat/1-x', 'gh api graphql -f query=\'mutation { enablePullRequestAutoMerge(input: {pullRequestId: "PR_1"}) { clientMutationId } }\'', 'deny'),
    ('merge-api-graphql', 'feat/1-x', 'gh api graphql -f query=\'mutation { mergePullRequest(input: {pullRequestId: "PR_1"}) { clientMutationId } }\'', 'deny'),
    ('merge-api-merges', 'feat/1-x', 'gh api -X POST repos/o/r/merges -f base=main -f head=feat/1-x', 'deny'),
    ('merge-api-rest-implicit-post', 'feat/1-x', 'gh api repos/o/r/pulls/12/merge -f merge_method=squash', 'deny'),
    ('merge-api-rest', 'feat/1-x', 'gh api -X PUT repos/o/r/pulls/12/merge -f merge_method=squash', 'deny'),
    ('merge-pr-auto', 'feat/1-x', 'gh pr merge --auto --squash', 'deny'),
    ('merge-pr-no-args', 'feat/1-x', 'gh pr merge', 'deny'),
    ('merge-pr', 'feat/1-x', 'gh pr merge 12 --squash', 'deny'),
]


class Guard(unittest.TestCase):
    def test_cases(self) -> None:
        for name, branch, command, want in CASES + QUOTING_CASES:
            with self.subTest(case=name), tempfile.TemporaryDirectory() as tmp:
                git_repo(Path(tmp), branch)
                payload = {
                    "hook_event_name": "PreToolUse",
                    "tool_name": "Bash",
                    "tool_input": {"command": command},
                    "cwd": tmp,
                }
                result = run_hook(GUARD, payload)
                self.assertEqual(result.returncode, 0, result.stderr)
                if want == "allow":
                    self.assertEqual(result.stdout, "", "allow must leave the call untouched")
                    continue
                out = json.loads(result.stdout)["hookSpecificOutput"]
                self.assertEqual(out["hookEventName"], "PreToolUse")
                self.assertEqual(out["permissionDecision"], "deny")
                self.assertTrue(out["permissionDecisionReason"])

    def test_command_without_git_or_gh_skips_parsing(self) -> None:
        # The early return: the parser is never reached, so a parser fault cannot matter.
        with mock.patch.object(guard, "simple_commands", side_effect=AssertionError("parsed")):
            self.assertIsNone(guard.check("make push FORCE=1", "."))

    def test_non_bash_tool_passes(self) -> None:
        payload = {"hook_event_name": "PreToolUse", "tool_name": "Read", "tool_input": {}}
        result = run_hook(GUARD, payload)
        self.assertEqual((result.returncode, result.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
