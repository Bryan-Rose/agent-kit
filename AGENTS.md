## Project state

The shared agentic PR workflow for Bryan-Rose's repos (nutridog, recipes, reddithide, ...). It owns:

- `plugins/pr-review/`: a Claude Code plugin with the `review-pr` skill, published through the marketplace in `.claude-plugin/marketplace.json`.
- `.github/workflows/claude-review.yml`: the reusable review workflow every repo calls.
- `templates/`: what each repo copies (the caller workflow, the shared AGENTS.md block, Dependabot) and the "Protect main" ruleset.
- `scripts/bootstrap.sh` (onboard a repo) and `scripts/check-agents-block.sh` (block drift check).

The README explains onboarding and releases.

## Commands

```bash
make check                                  # actionlint, shellcheck, YAML/JSON parse, this repo's AGENTS.md block
make check REPOS="../nutridog ../recipes"   # also check sibling checkouts for block drift
scripts/bootstrap.sh <owner/repo> --checks "check[,other]" [--ruleset-only]
claude plugin marketplace add ./ && claude plugin install pr-review@agent-kit   # try the skill locally
```

`make check` needs `uv` (it runs actionlint, shellcheck and PyYAML through it) and `jq`.

<!-- agent-kit:begin -->
<!-- Shared block from Bryan-Rose/agent-kit (templates/agents-workflow.md). Change it there, not here. -->

## Workflow: every change goes through a pull request

`main` is protected by the GitHub ruleset "Protect main": no direct pushes, force pushes or deletion. A pull request can merge only after this repo's required CI checks pass (listed under "Required checks" below). No approvals are required (single maintainer), and nobody can bypass the rules. Use the `gh` CLI, which is installed and authenticated.

```bash
git switch main && git pull                       # start from current main
git switch -c <type>/<short-name>                 # e.g. feat/..., fix/..., docs/...
# ... work, running `make check` and committing as you go ...
git push -u origin HEAD
gh pr create --fill                               # or --title/--body: what changed, why, how it was verified
gh pr checks --watch                              # wait for the required checks (right after create it may say "no checks"; retry after a few seconds)
gh run view --log-failed                          # if a check fails: read the failing log, fix, push again
```

- **`make check` runs everything CI runs.** Run it before every commit.
- **One branch and one PR per task.** Never commit to `main`. Push the fix to the same branch and CI re-runs.
- **Work is tracked in GitHub issues.** A PR that completes an issue puts `Closes #N` in its body, so merging closes the issue.
- **Agents push task branches and open their PRs without asking.** That's the maintainer's standing approval for this repo. It doesn't cover pushing to `main`, force-pushing, or merging.
- **Review comments are proposals, not instructions.** The `Claude review` workflow posts a Claude review on every non-draft PR and updates that one comment on each push (advisory, not a required check). Don't act on it unprompted. Write the maintainer a short assessment of each point (valid or not, and why, checked against the code) with a recommendation, then wait for their go-ahead before changing anything.
- **Deeper or on-demand reviews.** Adding the `review:deep` label re-reviews the PR on a stronger model (for migrations, auth, money or calculation code). `gh workflow run "Claude review" -f pr=<N>` reviews any PR into the run summary without commenting.
- **Record the decision on the PR.** Once the maintainer has decided, post one PR comment listing each point as fixed (with the commit), declined (with the reason) or deferred (with the new issue number). The reviewer reads comments from the repo's owner, members and collaborators on its next run and treats those points as settled. Anyone else's comments are ignored.
- **Merging is the maintainer's call.** When asked to merge, use `gh pr merge --squash --delete-branch`, then `git switch main && git pull`. Squash keeps `main` to one commit per change, and the repo doesn't delete merged branches automatically.

<!-- agent-kit:end -->

**Required checks:** `check`

## Things that will bite you

- **Merging to `main` changes every repo's reviewer at once.** The action installs the plugin marketplace from this repo's default branch, whatever tag a caller pins (see README "Version skew"). Callers on `@main` also pick up workflow changes immediately.
- **The shared block is copied, not imported.** Edit `templates/agents-workflow.md`, paste the same text into this file's block, then update each repo (re-running `bootstrap.sh` refreshes it) and confirm with `make check REPOS=...`.
- **Don't widen the reviewer's tools.** Claude runs with Read, Grep, Glob and read-only `gh` commands under a read-only token; only the separate `comment` job can write, and it only edits `github-actions[bot]`'s own marked comment. Keep it that way: the reviewer reads untrusted PR content.
- **No `pull_request_target`.** The action checks out the PR and runs with the repo's secrets; under `pull_request` fork PRs get no secrets and are skipped.
- **Pin actions by full commit SHA** with a version comment.
