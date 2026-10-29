# agent-kit

One home for the agentic PR workflow used across Bryan-Rose's repos:

- **Claude review.** A reusable workflow runs [claude-code-action](https://github.com/anthropics/claude-code-action) with the `review-pr` skill from this repo's plugin. It reviews each non-draft PR against the repo's `AGENTS.md` and keeps one comment (marked `<!-- claude-pr-review -->`) up to date on every push. It's advisory, never a required check.
- **The shared `AGENTS.md` block** (`templates/agents-workflow.md`): PR-only workflow, issues and `Closes #N`, review comments as proposals, merging is the maintainer's call.
- **The "Protect main" ruleset** (`templates/ruleset-protect-main.json`), with the required checks filled in per repo.
- **`scripts/bootstrap.sh`** to onboard a repo and **`scripts/check-agents-block.sh`** to catch drift in the shared block.

## How the review works

| | |
|---|---|
| Trigger | `pull_request` (opened, synchronize, reopened, ready_for_review, labeled) from same-repo branches; drafts, forks and Dependabot are skipped |
| Model | `claude-haiku-5-5` (chosen over Sonnet in a comparison on nutridog #8–#11: more confirmed findings, about a quarter of the cost); the `review:deep` label switches that PR to `claude-opus-5-5` |
| Tools | Read, Grep, Glob, `gh pr view`, `gh pr diff`, `gh issue view`; read-only token; `--max-turns 40` |
| Output | Structured output → a separate `comment` job (the only one with `pull-requests: write`) creates or updates the marked comment by `github-actions[bot]` |
| On demand | `gh workflow run "Claude review" -R <repo> -f pr=<N> [-f model=<id>]` writes the review to the run summary and doesn't comment |
| Settled points | Only OWNER, MEMBER and COLLABORATOR comments marking a point fixed, declined or deferred |
| Cost | The action logs a `result` block with `num_turns`, `total_cost_usd` and per-model usage |

Run the skill locally (after `gh pr checkout <N>` in the target repo):

```bash
claude plugin marketplace add Bryan-Rose/agent-kit
claude plugin install pr-review@agent-kit
# then in Claude Code:
/pr-review:review-pr Bryan-Rose/nutridog#42
```

## Onboard a repo

The repo needs a `make check` that runs everything CI runs, and a CI job for each required check.

1. `scripts/bootstrap.sh <owner/repo> --checks "check[,other]"` opens a PR adding the review caller, Dependabot, `CLAUDE.md` and the shared `AGENTS.md` block, and creates the `review:deep` label. If `AGENTS.md` had no block, the block is appended: move it into place and add the repo-specific sections.
2. If the script says so, set the secret yourself: `gh secret set ANTHROPIC_API_KEY -R <owner/repo>` (it prompts for the value). `CLAUDE_CODE_OAUTH_TOKEN` works instead.
3. Once the required checks have run on the repo at least once, protect `main`: `scripts/bootstrap.sh <owner/repo> --checks "check[,other]" --ruleset-only`. A required check that has never run blocks every PR, which is why this is a separate step.
4. Check for drift any time: `make check REPOS="../<repo>"`.

Re-running `bootstrap.sh` is safe: it only adds missing files and refreshes the shared block.

## Release

Callers pin the reusable workflow by tag (`@v1`). For a release:

```bash
git switch main && git pull
git tag v1.2.0 && git push origin v1.2.0
git tag -f v1 && git push -f origin v1   # move the floating major tag
```

Moving `v1` is a force-push of a tag, so it's the maintainer's call. A breaking change to the caller's inputs or secrets gets `v2`.

### Version skew

claude-code-action installs plugin marketplaces from a Git URL ending in `.git`, with no way to pick a ref. So the `review-pr` skill always comes from this repo's default branch, even for callers pinned to `@v1`: a merged skill change reaches every repo on its next review. That's acceptable for a single maintainer; keep skill changes backward compatible with the workflow's prompt and `--json-schema`.

## Deviations from the original plan

- The skill doesn't post the comment. Claude returns the review as structured output (`--json-schema`), and a separate job with `pull-requests: write` upserts the comment. That keeps the model's token read-only and drops `gh api` (which could write) from its tools. The action's `use_sticky_comment` only applies to its tag mode, not automation prompts.
- `--summary-only` became the workflow's job: every run writes the review to the run summary, and dispatch runs simply skip the comment job.
- Dispatch refuses fork PRs. The action restores `.claude/` and `CLAUDE.md` from the base branch on PR events but not on dispatch, so a fork's config would otherwise run next to the secrets.
- Auth: the action passes `ANTHROPIC_API_KEY` and `CLAUDE_CODE_OAUTH_TOKEN` through and requires at least one; an unset secret is just empty. Set only one.
