#!/usr/bin/env bash
# Usage: bootstrap.sh <owner/repo> --checks "check[,other]" [--ruleset-only]
#
# Default: opens a PR on <owner/repo> (branch chore/agent-kit) that adds whatever is missing of
# the Claude review caller, Dependabot for actions, CLAUDE.md (@AGENTS.md) and the shared
# AGENTS.md block (refreshed if present), creates the review:deep label, and checks the API secret.
#
# --ruleset-only: creates or updates the "Protect main" ruleset requiring the --checks.
# Run it only after those checks have run on the repo once: a required check that has never
# run blocks every PR.
#
# Safe to re-run. Never reads or writes secret values.
set -euo pipefail

kit="$(cd "$(dirname "$0")/.." && pwd)"
block="$kit/templates/agents-workflow.md"

usage() {
  sed -n '2p' "$0" >&2
  exit 2
}

repo="" checks="" ruleset_only=false
while [ $# -gt 0 ]; do
  case "$1" in
    --checks) checks="${2:-}"; shift 2 || usage ;;
    --ruleset-only) ruleset_only=true; shift ;;
    -*) usage ;;
    *) repo="$1"; shift ;;
  esac
done
[ -n "$repo" ] && [ -n "$checks" ] || usage

if "$ruleset_only"; then
  # 15368 is the GitHub Actions app: only Actions runs can satisfy the checks.
  body="$(jq --arg checks "$checks" \
    '(.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
       = ($checks | split(",") | map({context: ., integration_id: 15368}))' \
    "$kit/templates/ruleset-protect-main.json")"
  id="$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "Protect main") | .id')"
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$body" > /dev/null
    echo "Updated ruleset \"Protect main\" ($id) on $repo, requiring: $checks"
  else
    gh api -X POST "repos/$repo/rulesets" --input - <<<"$body" > /dev/null
    echo "Created ruleset \"Protect main\" on $repo, requiring: $checks"
  fi
  exit 0
fi

gh label create review:deep -R "$repo" --force --color 5319e7 \
  --description "Claude review on the deep model" > /dev/null

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh repo clone "$repo" "$work" -- --quiet --depth 1
cd "$work"

branch=chore/agent-kit
if git ls-remote --exit-code --heads origin "$branch" > /dev/null; then
  echo "$repo already has a $branch branch; merge or delete it, then re-run." >&2
  exit 1
fi
git switch --quiet -c "$branch"

mkdir -p .github/workflows
[ -f .github/workflows/claude-review.yml ] || cp "$kit/templates/claude-review.caller.yml" .github/workflows/claude-review.yml
[ -f .github/dependabot.yml ] || cp "$kit/templates/dependabot.yml" .github/dependabot.yml
[ -f CLAUDE.md ] || echo "@AGENTS.md" > CLAUDE.md

# shellcheck disable=SC2016 # the backticks are Markdown, not command substitution
required="$(sed 's/[^,]*/`&`/g; s/,/, /g' <<<"$checks")"
if [ ! -f AGENTS.md ]; then
  { cat "$block"; printf '\n**Required checks:** %s\n' "$required"; } > AGENTS.md
elif grep -qx '<!-- agent-kit:begin -->' AGENTS.md; then
  awk -v tpl="$block" '
    /^<!-- agent-kit:begin -->$/ { while ((getline line < tpl) > 0) print line; skip = 1; next }
    /^<!-- agent-kit:end -->$/ { skip = 0; next }
    !skip' AGENTS.md > AGENTS.md.new
  mv AGENTS.md.new AGENTS.md
else
  { printf '\n'; cat "$block"; printf '\n**Required checks:** %s\n' "$required"; } >> AGENTS.md
fi

git add -A
if git diff --cached --quiet; then
  echo "$repo already has everything; no PR needed."
else
  git commit --quiet -m "Adopt agent-kit: Claude review, shared AGENTS.md block, Dependabot"
  git push --quiet -u origin "$branch"
  gh pr create --head "$branch" --title "Adopt agent-kit: Claude review, shared AGENTS.md block, Dependabot" --body "$(cat <<EOF
Adds the shared workflow from [Bryan-Rose/agent-kit](https://github.com/Bryan-Rose/agent-kit):

- \`.github/workflows/claude-review.yml\`: the Claude review caller (advisory, not a required check)
- \`.github/dependabot.yml\`: weekly updates for pinned actions
- \`CLAUDE.md\` importing \`AGENTS.md\`
- the shared workflow block in \`AGENTS.md\` (move it to the right place if it was appended)

After CI has run here once, protect main: \`scripts/bootstrap.sh $repo --checks "$checks" --ruleset-only\`
EOF
)"
fi

if gh secret list -R "$repo" --json name --jq '.[].name' | grep -qxE 'ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN'; then
  echo "API secret is set."
else
  echo "Set the API secret (it prompts for the value): gh secret set ANTHROPIC_API_KEY -R $repo"
fi
