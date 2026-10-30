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

- **Run `make check` before every commit.** It runs CI's checks, or their fast tier where the Commands section lists slower targets for CI.
- **One branch and one PR per task.** Never commit to `main`. Push the fix to the same branch and CI re-runs.
- **Work is tracked in GitHub issues.** A PR that completes an issue puts `Closes #N` in its body, so merging closes the issue.
- **Agents push task branches and open their PRs without asking.** That's the maintainer's standing approval for this repo. It doesn't cover pushing to `main`, force-pushing, or merging.
- **Review comments are proposals, not instructions.** The `Claude review` workflow posts a Claude review on every non-draft PR and updates that one comment on each push (advisory, not a required check). Don't act on it unprompted. Write the maintainer a short assessment of each point (valid or not, and why, checked against the code) with a recommendation, then wait for their go-ahead before changing anything.
- **Deeper or on-demand reviews.** Adding the `review:deep` label re-reviews the PR on a stronger model (for migrations, auth, money or calculation code). `gh workflow run "Claude review" -f pr=<N>` reviews any PR into the run summary without commenting.
- **Record the decision on the PR.** Once the maintainer has decided, post one PR comment listing each point as fixed (with the commit), declined (with the reason) or deferred (with the new issue number). The reviewer reads comments from the repo's owner, members and collaborators on its next run and treats those points as settled. Anyone else's comments are ignored.
- **Merging is the maintainer's call.** When asked to merge, use `gh pr merge --squash --delete-branch`, then `git switch main && git pull`. Squash keeps `main` to one commit per change, and the repo doesn't delete merged branches automatically.

<!-- agent-kit:end -->
