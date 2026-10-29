#!/usr/bin/env bash
# Usage: check-agents-block.sh <repo-path>...
# Diffs the agent-kit block in each repo's AGENTS.md against templates/agents-workflow.md.
# Exits non-zero if any repo has drifted or lacks the block.
set -euo pipefail

template="$(cd "$(dirname "$0")/.." && pwd)/templates/agents-workflow.md"
status=0
for repo in "$@"; do
  agents="$repo/AGENTS.md"
  if [ ! -f "$agents" ]; then
    echo "$agents: missing" >&2
    status=1
    continue
  fi
  if ! diff -u --label template --label "$agents" "$template" \
    <(sed -n '/^<!-- agent-kit:begin -->$/,/^<!-- agent-kit:end -->$/p' "$agents"); then
    status=1
  fi
done
exit "$status"
