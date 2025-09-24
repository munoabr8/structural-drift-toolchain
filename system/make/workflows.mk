# ci/workflows.mk
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# ---------------- cfg ----------------
MAIN_BRANCH ?= main
ENV         ?= production
SHA         ?=
REPO        ?= $(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
WF_DIR      := .github/workflows
DEPLOY_WF   := Deploy
DORA_WF     := DORA

EVENTS      ?= ci/dora/events.ndjson
ARTDIR      ?= artifacts
ARTNAME     ?= events-ndjson
WINDOW_DAYS ?= 60

# verbosity: make V=1
ifeq ($(V),1)
Q :=
E := set -x;
else
Q := @
E :=
endif

# ---------------- phony ----------------
.PHONY: wf/help wf/echo wf/install wf/validate wf/status \
        wf/run-deploy wf/run-dora \
        wf/fetch-latest wf/fetch-by-sha wf/merge-prs wf/probe wf/compute-dora \
        wf/prepare-events wf/all wf/all-by-sha 

# ---------------- info -----------------
wf/help:
	$(Q)echo "Targets:"
	$(Q)echo "  wf/run-deploy [ENV=.. SHA=..]     trigger Deploy"
	$(Q)echo "  wf/run-dora                       trigger DORA"
	$(Q)echo "  wf/status                         recent runs"
	$(Q)echo "  wf/fetch-latest                   copy latest Deploy artifact → $(EVENTS)"
	$(Q)echo "  wf/fetch-by-sha SHA=<merge>       copy Deploy artifact for specific merge"
	$(Q)echo "  wf/merge-prs                      append PR merges (last $(WINDOW_DAYS)d)"
	$(Q)echo "  wf/probe                          validate $(EVENTS)"
	$(Q)echo "  wf/compute-dora                   compute metrics"
	$(Q)echo "  wf/all                            fetch-latest → merge-prs → probe → compute"
	$(Q)echo "  wf/all-by-sha SHA=<merge>         fetch-by-sha → merge-prs → probe → compute"

wf/echo:
	$(Q)echo "REPO=$(REPO) MAIN_BRANCH=$(MAIN_BRANCH) ENV=$(ENV) EVENTS=$(EVENTS) ARTDIR=$(ARTDIR) ARTNAME=$(ARTNAME)"

# ---------------- hygiene ----------------
wf/install:
	@test -s "$(WF_DIR)/deploy2.yml" || { echo "ERR: missing $(WF_DIR)/deploy.yml"; exit 64; }
	@test -s "$(WF_DIR)/dora2.yml" || { echo "ERR: missing $(WF_DIR)/dora-basics.yml"; exit 64; }

wf/validate:
	@if command -v actionlint >/dev/null; then actionlint; else echo "note: install actionlint"; fi

wf/status:
	$(Q)gh auth status
	$(Q)gh run list --repo "$(REPO)" --limit 10 \
	  --json name,workflowName,headBranch,headSha,conclusion,createdAt \
	  | jq -r '.[]|[.workflowName,.conclusion,.createdAt,.headBranch,.headSha]|@tsv'

# ---------------- triggers -------------
wf/run-deploy:
	@set -euo pipefail; \
	cmd=(gh workflow run "$(DEPLOY_WF)" -f env="$(ENV)"); \
	if [ -n "$(SHA)" ]; then cmd+=(-f sha="$(SHA)"); fi; \
	printf '%q ' "$${cmd[@]}"; echo; \
	"$${cmd[@]}"

wf/run-dora:
	$(Q)gh workflow run '$(DORA_WF)'

# ---------------- fetch artifacts -------
$(ARTDIR):
	$(Q)install -d "$@"

wf/fetch-window:
	@WINDOW_DAYS='$(WINDOW_DAYS)' REPO='$(REPO)' DEPLOY_WF='$(DEPLOY_WF)' MAIN_BRANCH='$(MAIN_BRANCH)' \
	ARTDIR='$(ARTDIR)' EVENTS='$(EVENTS)' ARTNAME='$(ARTNAME)' \
	bash ci/dora/fetch_window_events.sh


wf/fetch-latest: | $(ARTDIR)
	$(Q)$(E) rid="$$(gh run list --repo '$(REPO)' --workflow '$(DEPLOY_WF)' --branch '$(MAIN_BRANCH)' -L 50 \
	      --json databaseId,conclusion,createdAt \
	      | jq -r 'map(select(.conclusion=="success"))|sort_by(.createdAt)|(last//{})|(.databaseId//empty)')"; \
	test -n "$$rid" || { echo "ERR:no successful $(DEPLOY_WF) run on $(MAIN_BRANCH)"; exit 64; }; \
	dir="$(ARTDIR)/run-$$rid"; rm -rf "$$dir"; mkdir -p "$$dir"; \
	
	gh run download "$$rid" --repo '$(REPO)' -n '$(ARTNAME)' -D "$$dir"; \
	
	f="$$(find "$$dir" -type f -name 'events.ndjson' -print -quit)"; \
	test -n "$$f" || { echo "ERR:artifact missing events.ndjson"; exit 65; }; \
	install -d "$$(dirname '$(EVENTS)')"; cp "$$f" '$(EVENTS)'; \
	jq -s '{pr:map(select(.type=="pr_merged"))|length,dep:map(select(.type=="deployment"))|length}' '$(EVENTS)'

wf/fetch-by-sha: | $(ARTDIR)
	$(Q)$(E) test -n "$${SHA:-}" || { echo "ERR:set SHA=<merge_commit_sha>"; exit 64; }; \
	rid="$$(gh run list --repo '$(REPO)' --workflow '$(DEPLOY_WF)' --branch '$(MAIN_BRANCH)' -L 50 \
	  --json databaseId,headSha,conclusion,createdAt \
	  | jq -r --arg s "$$SHA" 'map(select(.conclusion=="success" and .headSha==$s))|sort_by(.createdAt)|(last//{})|(.databaseId//empty)')"; \
	test -n "$$rid" || { echo "ERR:run not found for SHA"; exit 64; }; \
	dir="$(ARTDIR)/run-$$rid"; rm -rf "$$dir"; mkdir -p "$$dir"; \
	
	gh run download "$$rid" --repo '$(REPO)' -n '$(ARTNAME)' -D "$$dir"; \
	
	f="$$(find "$$dir" -type f -name 'events.ndjson' -print -quit)"; \
	test -n "$$f" || { echo "ERR:artifact missing events.ndjson"; exit 65; }; \
	install -d "$$(dirname '$(EVENTS)')"; cp "$$f" '$(EVENTS)'; \
	jq -s '{pr:map(select(.type=="pr_merged"))|length,dep:map(select(.type=="deployment"))|length}' '$(EVENTS)'

# ---------------- merge PRs ------------
wf/merge-prs:
	$(Q)$(E) test -s '$(EVENTS)' || { echo "ERR: missing $(EVENTS)"; exit 64; }; \
	since="$$(python3 -c 'from datetime import datetime,timedelta,timezone; import os; wd=int(os.getenv("WINDOW_DAYS","14")); print((datetime.now(timezone.utc)-timedelta(days=wd)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"; \
	before_pr="$$(jq -s 'map(select(.type=="pr_merged"))|length' '$(EVENTS)')"; \
	before_dep="$$(jq -s 'map(select(.type=="deployment"))|length' '$(EVENTS)')"; \
	gh pr list --repo '$(REPO)' --state merged --base '$(MAIN_BRANCH)' --limit 500 --search "merged:>=$$since" --json number \
	| jq -r '.[].number' \
	| while read -r n; do OUT='$(EVENTS)' bash ci/dora/event-append.sh pr-merged "$$n"; done; \
	after_pr="$$(jq -s 'map(select(.type=="pr_merged"))|length' '$(EVENTS)')"; \
	after_dep="$$(jq -s 'map(select(.type=="deployment"))|length' '$(EVENTS)')"; \
	[ "$$before_dep" = "$$after_dep" ] || { echo "ERR: deployment count changed ($$before_dep -> $$after_dep)"; exit 65; }; \
	echo "OK: PRs $$before_pr -> $$after_pr; Deployments $$after_dep"

wf/guard-pairing:
	@test -s '$(EVENTS)' || { echo "ERR: missing $(EVENTS)"; exit 64; }
	@jq -s -f ci/jq/guard_pairing.jq '$(EVENTS)' \
	| jq -e '.missing|length==0' >/dev/null \
	|| { echo "PAIRING_FAIL"; exit 66; }

# ---------------- probe/compute -------
wf/probe:
	$(Q)bash ci/probe.sh --kind=events '$(EVENTS)'

wf/compute-dora:
 
LT_PAIR_MODE=both python3 ci/dora/dora-renfactor/main.py '$(EVENTS)' | tee dora.out.txt



# ---------------- chains --------------
wf/prepare-events: wf/fetch-window wf/merge-prs wf/guard-pairing
	$(Q)echo "prepared $(EVENTS)"

wf/all: wf/prepare-events wf/probe wf/compute-dora
wf/all-by-sha: wf/fetch-by-sha wf/merge-prs wf/probe wf/compute-dora
