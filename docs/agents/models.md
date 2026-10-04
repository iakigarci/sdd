# Model assignment

Each workflow step runs on the model below. Judgement-heavy steps (interviews, ticket breakdown, diagnosis, the independent Spec review) get Opus; steps that follow a written spec get Sonnet; the PR body, a summary of what is already on the branch, gets Haiku.

| Model | Steps |
|---|---|
| Opus | `/grill-with-docs`, `/to-tickets`, `/diagnosing-bugs`, `/improve-codebase-architecture`, `/close-epic`, spec review (`spec-reviewer` agent), hotfix diagnosis |
| Opus/Sonnet | `/to-spec`: the model of the session it follows, Opus straight after a grill |
| Sonnet | `/implement`, `/tdd`, standards review (`standards-reviewer` agent), `/handoff`, hotfix fix |
| Haiku | PR body (`pr` skill, forked) |

## How each step gets its model

- **Session default**: `.claude/settings.json` sets `"model": "sonnet"`. Your own `.claude/settings.local.json` or `/model` overrides it.
- **Single-turn skills** pin their model in frontmatter: `handoff` (`sonnet`), `to-spec` (`inherit`).
- **Multi-turn skills** cannot be pinned and open with "Run under `/model opus`": `grill-with-docs`, `to-tickets` (it quizzes you until you approve the breakdown), `diagnosing-bugs`, `improve-codebase-architecture`, `close-epic` (it stops for your confirmation before writing). Switch back with `/model sonnet` afterwards.
- **Reviewer agents** pin their model in `.claude/agents/`: `spec-reviewer` (`opus`), `standards-reviewer` (`sonnet`).
- **PR body**: the `pr` skill runs as a forked Haiku agent (`context: fork`, `model: haiku`) and returns the title and body as text; `/implement` opens the PR itself.

## Caveat: `model:` lasts one turn

A skill's `model:` frontmatter applies for the rest of the current turn only; the session model resumes with your next prompt. Two consequences:

- A multi-turn skill pinned to Opus would run its follow-up turns on the session model, so these skills ask for `/model opus` instead.
- A skill invoked mid-turn by another skill switches the caller's model for the rest of that turn. `/implement` and the skills it calls (`tdd`, `code-review`) therefore pin nothing, and the PR body is written in a fork (with `context: fork`, `model:` sets the fork's model, not the session's).

## Escalating `/implement` to Opus

`/implement` runs on the session model, so `/model opus` before `/implement` escalates the whole ticket. The escalation triggers are listed in `/implement`. An Opus implementer shares the Spec reviewer's model: `/code-review` then reports "Spec review not independent", and the PR's Merge Danger says so.
