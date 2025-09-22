.PHONY: env/echo env/probe env/ci env/bats env/checks test/hermetic

# knobs
ENV_ALLOW ?= PATH HOME CI GH_TOKEN PWD SHELL SHLVL TERM _ LC_ALL
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
	@ALLOWLIST='$(ENV_ALLOW)' LC_ALL=C SNAPSHOT_MODE=head bash '$(ISOLATE_CI)'


env/bats:
	@ALLOWLIST=$(BATS_ALLOW) SNAPSHOT_MODE=worktree_tracked bash '$(ISOLATE_BATS)'




ENV_ARTDIR ?= artifacts/env
BEFORE ?= $(ENV_ARTDIR)/before.json
AFTER  ?= $(ENV_ARTDIR)/after.json



env/checks:
	@test -f '$(BEFORE)' -a -f '$(AFTER)' || { echo "ERR: missing probes; run make env/ci"; exit 2; }
	@jq -e '.schema=="env/probe/v1"' '$(BEFORE)' >/dev/null
	@jq -e '.schema=="env/probe/v1"' '$(AFTER)'  >/dev/null
	@echo "OK: probe JSONs valid"

env/checks2:
	@test -f '$(BEFORE)' -a -f '$(AFTER)' || { echo "ERR: missing probes; run make env/ci"; exit 2; }
	@jq -e '.schema=="env/probe/v1"' '$(BEFORE)' >/dev/null
	@jq -e '.schema=="env/probe/v1"' '$(AFTER)'  >/dev/null
	@ALLOWLIST='$(ENV_ALLOW)' bash -lc '. ci/env/_isolate_core.sh; assert_min_env'
	@test "$$(umask)" = "0022"; @test "$${LC_ALL:-C}" = "C"; @command -v jq git bash >/dev/null


# tie into workflows (optional)
wf/prepare-isolated: env/ci env/checks
	@echo "env isolated + checks passed"

# quick hermetic test entrypoint
test/hermetic:
	@bats -r test/
