.PHONY: env/echo env/probe env/ci env/bats env/checks test/hermetic

# knobs
ENV_ALLOW    ?= "PATH HOME CI GH_TOKEN"
BATS_ALLOW   ?= "PATH HOME WS"
ISOLATE_CI   := ci/env/isolate_ci.sh
ISOLATE_BATS := ci/env/isolate_bats.sh

PROBE        ?= ci/env/probe_env.sh

SNAPSHOT_MODE ?= head          # CI default
 
env/echo:
	@echo "ALLOW(CI)=$(ENV_ALLOW)  ALLOW(BATS)=$(BATS_ALLOW)"

env/probe:
	@bash '$(PROBE)' | tee env.probe.json


env/ci:
	@ALLOWLIST=$(ENV_ALLOW) SNAPSHOT_MODE=head bash '$(ISOLATE_CI)'


env/bats:
	@ALLOWLIST=$(BATS_ALLOW) SNAPSHOT_MODE=worktree_tracked bash '$(ISOLATE_BATS)'

# invariant checks (fail-fast, machine-checkable)
env/checks:
	@jq -e '.schema=="env/probe/v1"' before.json >/dev/null
	@jq -e '.schema=="env/probe/v1"' after.json  >/dev/null
	@env | awk -F= '{print $$1}' | \
	  grep -vE '^(PATH|HOME|WS|CI|GH_TOKEN|LC_ALL|SOURCE_DATE_EPOCH|PWD|SHELL|SHLVL|_)$$' | \
	  grep . && { echo "ERR: extra env vars"; exit 66; } || true
	@test "$$(umask)" = "0022"
	@test "$${LC_ALL:-C}" = "C"
	@command -v jq git bash >/dev/null

# tie into workflows (optional)
wf/prepare-isolated: env/ci env/checks
	@echo "env isolated + checks passed"

# quick hermetic test entrypoint
test/hermetic:
	@bats -r test/
