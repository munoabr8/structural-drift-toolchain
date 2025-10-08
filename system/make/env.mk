.PHONY: env/echo env/probe env/ci env/bats env/checks test/hermetic

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# knobs
ENV_ALLOW ?= PATH HOME CI GH_TOKEN PWD SHELL SHLVL TERM _ LC_ALL
BATS_ALLOW   ?= "PATH HOME WS"
ISOLATE_CI   := ci/enviornment/isolate_ci.sh
ISOLATE_BATS := ci/enviornment/isolate_bats.sh

PROBE        ?= ci/enviornment/probe_env.sh

SNAPSHOT_MODE ?= head          # CI default
 
env/echo:
	@echo "ALLOW(CI)=$(ENV_ALLOW)  ALLOW(BATS)=$(BATS_ALLOW)"

env/probe:
	@bash '$(PROBE)' | tee env.probe.json

env/ci:
	@ALLOWLIST='$(ENV_ALLOW)' LC_ALL=C SNAPSHOT_MODE=head bash '$(ISOLATE_CI)'


env/bats:
	@ALLOWLIST=$(BATS_ALLOW) SNAPSHOT_MODE=worktree_tracked bash '$(ISOLATE_BATS)'

SNAP_KEYS ?= MAIN_BRANCH EVENTS

.PHONY: wf/run
wf/run: env/events-fixture
	@SNAP_KEYS='$(SNAP_KEYS)'
	@set -euo pipefail; \
	  . system/env/load.sh; \
	  . system/contracts/run_frame.sh; begin_frame; trap "end_frame" EXIT; \
	  ASSERT_TRACE=1 bash system/env/assert.sh; \
	  . system/contracts/postcheck.sh; \
	  ts="$$(date -u +%FT%TZ)"; mkdir -p artifacts/env; \
	  jq -nc --arg ts "$$ts" \
	         --arg env "$${ENV:-}" --arg repo "$${REPO:-}" \
	         --arg branch "$${MAIN_BRANCH:-}" --arg events "$${EVENTS:-}" \
	         --slurpfile sch config/env/required.schema.json \
	         -f system/ci/env_validated.jq \
	    > artifacts/env/validated.json



ENV_ARTDIR ?= artifacts/env
ASSERT_EVENT ?= $(ENV_ARTDIR)/assert.$(shell date -u +%Y%m%dT%H%M%SZ).json
# default path if not provided by env files
EVENTS ?= artifacts/events.ndjson
 
# or bootstrap:
env/assert-auto:
	@bash -lc 'ASSERT_BOOTSTRAP=1 ASSERT_TRACE=1 bash system/env/assert.sh'

.PHONY: env/assert
# env/assert: env/events-fixture
# 	@bash -lc 'source system/env/load.sh; ASSERT_TRACE=1 bash system/env/assert.sh'

env/events-fixture:
	@EVENTS='$(EVENTS)' bash -c 'source system/env/load.sh; mkdir -p "$${EVENTS%/*}"; [ -s "$$EVENTS" ] || printf "{}\n" > "$$EVENTS"; echo "[env] EVENTS=$$EVENTS (exists=$$([ -s "$$EVENTS" ] && echo yes || echo no))"'

env/assert: env/events-fixture
	@EVENTS='$(EVENTS)' ASSERT_TRACE=1 bash -c 'source system/env/load.sh; bash system/env/assert.sh'



BEFORE ?= $(ENV_ARTDIR)/before.json
AFTER  ?= $(ENV_ARTDIR)/after.json



env/checks:
	@test -f '$(BEFORE)' -a -f '$(AFTER)' || { echo "ERR: missing probes; run make env/ci"; exit 2; }
	@jq -e '.schema=="env/probe/v1"' '$(BEFORE)' >/dev/null
	@jq -e '.schema=="env/probe/v1"' '$(AFTER)'  >/dev/null
	@echo "OK: probe JSONs valid"

.PHONY: env/validated-check
env/validated-check:
	@jq -e . artifacts/env/validated.json >/dev/null
	@diff -u <(jq -r '.keys[]' artifacts/env/validated.json | sort) <(jq -r '.keys|keys[]' config/env/required.schema.json | sort)
	@jq -n --slurpfile v artifacts/env/validated.json --slurpfile s config/env/required.schema.json -e '($$s[0].keys.ENV.enum // []) | index($$v[0].env) != null' >/dev/null
	@test -s "$$(jq -r '.events' artifacts/env/validated.json)"
		

# tie into workflows (optional)
wf/prepare-isolated: env/ci env/checks
	@echo "env isolated + checks passed"

# quick hermetic test entrypoint
test/hermetic:
	@bats -r test/
