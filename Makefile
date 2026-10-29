# Single entry point for checks, used by people, agents and CI.
#   make check                                  lint workflows and scripts, parse YAML/JSON, check AGENTS.md
#   make check REPOS="../nutridog ../recipes"   also check those checkouts' AGENTS.md block for drift

REPOS ?=

.PHONY: check
check:
	uvx --from actionlint-py==1.7.12.25 actionlint .github/workflows/*.yml templates/*.caller.yml
	uvx --from shellcheck-py==0.11.0.1 shellcheck scripts/*.sh
	uv run --no-project --with pyyaml==6.0.3 python -c 'import sys, yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]' .github/*.yml templates/*.yml
	jq empty .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json templates/*.json
	scripts/check-agents-block.sh . $(REPOS)
