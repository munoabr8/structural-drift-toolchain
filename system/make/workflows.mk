SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

WF_DIR := .github/workflows
DEPLOY := $(WF_DIR)/deploy.yml
DORA   := $(WF_DIR)/dora-basics.yml

ENV ?= production
SHA ?=



 
# Config
DEPLOY_WF   := Deploy
MAIN_BRANCH ?= main
REPO        ?= $(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
EVENTS      ?= ci/dora/events.ndjson
ARTDIR      ?= artifacts
ARTNAME     ?= events-ndjson

# Verbose toggle: make V=1 …
ifeq ($(V),1)
Q :=
E := set -x;
else
Q := @
E :=
endif

  


 
.PHONY: wf/install wf/validate wf/run-deploy wf/run-dora wf/status wf/fetch-events wf/status wf/fetch-events wf/merge-prs wf/prepare-events wf/echo

wf/install:
	@test -s "$(DEPLOY)" && echo "ok: $(DEPLOY)" || { echo "ERR: missing $(DEPLOY)"; exit 64; }
	@test -s "$(DORA)"   && echo "ok: $(DORA)"   || { echo "ERR: missing $(DORA)"; exit 64; }

wf/validate:
	@if command -v actionlint >/dev/null; then actionlint; \
	else echo "note: install actionlint for strict checks"; fi

wf/run-deploy:
	@cmd=(gh workflow run Deploy -f env="$(ENV)"); \
	[[ -n "$(SHA)" ]] && cmd+=(-f sha="$(SHA)"); \
	echo "$${cmd[*]}"; "$${cmd[@]}"

wf/run-dora:
	@gh workflow run DORA

wf/status:
	@gh run list --limit 10 --json name,headSha,conclusion,workflowName,createdAt \
	  | jq -r '.[]|[.workflowName,.conclusion,.createdAt,.headSha]|@tsv'

EVENTS       ?= ci/dora/events.ndjson
MAIN_BRANCH  ?= main
REPO         ?= $(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

# Fetch artifact for a specific Deploy run by merge commit SHA (set: SHA=<merge_commit_sha>)
wf/fetch-by-sha:
	@set -euo pipefail; \
	test -n "$${SHA:-}" || { echo "ERR: set SHA=<merge_commit_sha>"; exit 64; }; \
	rid="$$(gh run list --repo '$(REPO)' --workflow Deploy --branch '$(MAIN_BRANCH)' -L 50 \
	  --json databaseId,headSha,conclusion,createdAt \
	  | jq -r --arg s "$$SHA" 'map(select(.conclusion=="success" and .headSha==$s)) \
	                            | sort_by(.createdAt) | (last//{}) | (.databaseId//empty)')"; \
	test -n "$$rid" || { echo "ERR: run not found"; exit 64; }; \
	dir="artifacts/run-$$rid"; rm -rf "$$dir"; mkdir -p "$$dir"; \
	gh run download "$$rid" --repo '$(REPO)' -n events-ndjson -D "$$dir"; \
	f="$$(find "$$dir" -type f -name events.ndjson -print -quit)"; \
	test -n "$$f" || { echo "ERR: events.ndjson missing in artifact"; exit 65; }; \
	install -d "$$(dirname '$(EVENTS)')"; cp "$$f" '$(EVENTS)'; echo "wrote $(EVENTS)"

# Fetch latest successful Deploy artifact (branch-scoped)
wf/fetch-latest:
	@set -euo pipefail; \
	rid="$$(gh run list --repo '$(REPO)' --workflow Deploy --branch '$(MAIN_BRANCH)' -L 50 \
	  --json databaseId,conclusion,createdAt \
	  | jq -r 'map(select(.conclusion=="success")) \
	           | sort_by(.createdAt) | (last//{}) | (.databaseId//empty)')"; \
	test -n "$$rid" || { echo "ERR: no successful run"; exit 64; }; \
	dir="artifacts/run-$$rid"; rm -rf "$$dir"; mkdir -p "$$dir"; \
	gh run download "$$rid" --repo '$(REPO)' -n events-ndjson -D "$$dir"; \
	f="$$(find "$$dir" -type f -name events.ndjson -print -quit)"; \
	test -n "$$f" || { echo "ERR: events.ndjson missing in artifact"; exit 65; }; \
	install -d "$$(dirname '$(EVENTS)')"; cp "$$f" '$(EVENTS)'; echo "wrote $(EVENTS)"

wf/merge-prs:
	@set -euo pipefail; \
	test -s '$(EVENTS)' || { echo "ERR: missing $(EVENTS)"; exit 64; }; \
	since="$$(python3 -c 'from datetime import datetime,timedelta,timezone; import os; wd=int(os.getenv("WINDOW_DAYS","14")); print((datetime.now(timezone.utc)-timedelta(days=wd)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"; \
	before_pr="$$(jq -s 'map(select(.type=="pr_merged"))|length' '$(EVENTS)')"; \
	before_dep="$$(jq -s 'map(select(.type=="deployment"))|length' '$(EVENTS)')"; \
	gh pr list --state merged --base '$(MAIN_BRANCH)' --limit 500 --search "merged:>=$$since" --json number \
	| jq -r '.[].number' \
	| while read -r n; do \
	    OUT='$(EVENTS)' bash ci/dora/event-append.sh pr-merged "$$n"; \
	  done; \
	after_pr="$$(jq -s 'map(select(.type=="pr_merged"))|length' '$(EVENTS)')"; \
	after_dep="$$(jq -s 'map(select(.type=="deployment"))|length' '$(EVENTS)')"; \
	if [ "$$before_dep" != "$$after_dep" ]; then echo "ERR: deployment count changed ($$before_dep -> $$after_dep)"; exit 65; fi; \
	echo "OK: PRs $$before_pr -> $$after_pr; Deployments $$after_dep"



# combo target: fetch + merge + validate
wf/prepare-events: wf/fetch-events wf/merge-prs
	bash ci/probe.sh --kind=events "$(EVENTS)"
	@echo "prepared $(EVENTS)"

wf/echo:
	$(Q)echo "REPO=$(REPO) MAIN_BRANCH=$(MAIN_BRANCH) EVENTS=$(EVENTS) ARTDIR=$(ARTDIR) ARTNAME=$(ARTNAME)"

wf/status:
	$(Q)gh auth status
	$(Q)gh run list --repo "$(REPO)" --limit 10 \
	  --json name,headSha,conclusion,workflowName,createdAt,headBranch \
	  | jq -r '.[]|[.workflowName,.conclusion,.createdAt,.headBranch,.headSha]|@tsv'

# 1) Fetch latest successful Deploy artifact and place events.ndjson at $(EVENTS)
wf/fetch-events: | $(ARTDIR)
	$(Q)$(E) rid="$$(gh run list --repo '$(REPO)' --workflow '$(DEPLOY_WF)' --branch '$(MAIN_BRANCH)' -L 50 \
	      --json databaseId,createdAt,conclusion \
	      | jq -r 'map(select(.conclusion=="success")) | sort_by(.createdAt) | (last//{}) | (.databaseId//empty)')"; \
	test -n "$$rid" || { echo "ERR:no successful $(DEPLOY_WF) run on branch $(MAIN_BRANCH)"; exit 64; }; \
	echo "RID=$$rid"; \
	gh run download "$$rid" --repo '$(REPO)' -n '$(ARTNAME)' -D '$(ARTDIR)'; \
	f="$$(find '$(ARTDIR)' -type f -name 'events.ndjson' | head -1)"; \
	test -n "$$f" || { echo "ERR:artifact $(ARTNAME) missing events.ndjson"; exit 65; }; \
	install -d "$$(dirname '$(EVENTS)')"; \
	cp "$$f" '$(EVENTS)'; \
	echo "wrote $(EVENTS)"

$(ARTDIR):
	$(Q)install -d "$@"

compute-dora:
	@python3 ci/dora/compute-dora.py "$(EVENTS)"
