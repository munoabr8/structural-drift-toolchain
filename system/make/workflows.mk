# ci/workflows.mk
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# ---------------- cfg ----------------
MAIN_BRANCH ?= main
ENV         ?= production
SHA         ?=
# robust: prefer gh, fall back to git remote URL
REPO ?= $(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
          || git config --get remote.origin.url \
             | sed -E 's|.*github.com[:/]([^/]+/[^/.]+)(\.git)?|\1|')


WF_DIR      := .github/workflows
DEPLOY_WF   := Deploy
DORA_WF     := DORA

REPO ?= $(shell gh repo view -q .nameWithOwner --json nameWithOwner)



DEPLOY_WF_PATH ?= .github/workflows/deploy2.yml
DORA_WF_PATH   ?= .github/workflows/dora2.yml

DEPLOY_WF_PATH_N := $(patsubst ./%,%,$(DEPLOY_WF_PATH))
DORA_WF_PATH_N   := $(patsubst ./%,%,$(DORA_WF_PATH))
DEPLOY_WF_FILE   := $(notdir $(DEPLOY_WF_PATH_N))
DORA_WF_FILE     := $(notdir $(DORA_WF_PATH_N))



 ARTDIR ?= artifacts

# ---- cache IDs once, don’t recompute at parse time
-include $(ARTDIR)/workflow_ids.env

# ---- selectors: ID > normalized path
DEPLOY_SEL := $(or $(DEPLOY_WF_ID),$(DEPLOY_WF_PATH_N))
DORA_SEL   := $(or $(DORA_WF_ID),$(DORA_WF_PATH_N))


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
        wf/prepare-events wf/all wf/all-by-sha wf/obs wf/env wf/resolve-ids \
        wf/resolve wf/clear-ids
 
# ---------------- info -----------------
wf/help:
	$(Q)echo "Targets:"
	$(Q)echo "  wf/run-deploy [ENV=.. SHA=..]     trigger Deploy"
	$(Q)echo "  wf/obs                            prepare → probe → compute"
	$(Q)echo "  wf/run-dora                       trigger DORA"
	$(Q)echo "  wf/status                         recent runs"
	$(Q)echo "  wf/fetch-latest                   copy latest Deploy artifact → $(EVENTS)"
	$(Q)echo "  wf/fetch-by-sha SHA=<merge>       copy Deploy artifact for specific merge"
	$(Q)echo "  wf/merge-prs                      append PR merges (last $(WINDOW_DAYS)d)"
	$(Q)echo "  wf/probe                          validate $(EVENTS)"
	$(Q)echo "  wf/compute-dora                   compute metrics"
	$(Q)echo "  wf/all                            fetch-latest → merge-prs → probe → compute"
	$(Q)echo "  wf/all-by-sha SHA=<merge>         fetch-by-sha → merge-prs → probe → compute"
	$(Q)echo "  wf/env                            print key env"
	$(Q)echo "  wf/resolve-ids                    map workflow names → IDs (preferred)"


wf/resolve: $(ARTDIR)/workflow_ids.env
	@echo "ok: $<"; cat '$<'
	@set -a; . $<; set +a; \
	  test -n "$$DEPLOY_WF_ID" || { echo "ERR: bad DEPLOY_WF_PATH=$(DEPLOY_SEL)"; exit 65; }; \
	  test -n "$$DORA_WF_ID"   || { echo "ERR: bad DORA_WF_PATH=$(DORA_SEL)"; exit 65; }

 

$(ARTDIR)/workflow_ids.env:
	@mkdir -p '$(ARTDIR)'; r='$(REPO)'; \
	  dep_id="$$(gh api repos/$$r/actions/workflows/$(DEPLOY_WF_FILE) -q .id 2>/dev/null || true)"; \
	  dora_id="$$(gh api repos/$$r/actions/workflows/$(DORA_WF_FILE)   -q .id 2>/dev/null || true)"; \
	  [ -n "$$dep_id" ]  || { echo "ERR: deploy file not found: $(DEPLOY_WF_FILE)"; exit 65; }; \
	  [ -n "$$dora_id" ] || { echo "ERR: dora file not found: $(DORA_WF_FILE)";   exit 65; }; \
	  { echo "export REPO=$$r"; echo "export DEPLOY_WF_ID=$$dep_id"; echo "export DORA_WF_ID=$$dora_id"; } >'$@'

wf/clear-ids:
	@rm -f $(ARTDIR)/workflow_ids.env



wf/echo:
	$(Q)echo "REPO=$(REPO) MAIN_BRANCH=$(MAIN_BRANCH) ENV=$(ENV) EVENTS=$(EVENTS) ARTDIR=$(ARTDIR) ARTNAME=$(ARTNAME)"


wf/env:
	@printf "REPO=%s\nMAIN_BRANCH=%s\nENV=%s\nWINDOW_DAYS=%s\nGH_TOKEN=%s\nDEPLOY_WF_ID=%s\nDORA_WF_ID=%s\n" \
	  "$(REPO)" "$(MAIN_BRANCH)" "$(ENV)" "$(WINDOW_DAYS)" "$${GH_TOKEN:+set}"\
	  "$(DEPLOY_WF_ID)" "$(DORA_WF_ID)"


# ---------------- hygiene ----------------

 

wf/install:
	@test -s "$(WF_DIR)/deploy2.yml" || { echo "ERR: missing $(WF_DIR)/deploy2.yml"; exit 64; }
	@test -s "$(WF_DIR)/dora2.yml" || { echo "ERR: missing $(WF_DIR)/dora-basics2.yml"; exit 64; }

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
	cmd=(gh workflow run "$${DEPLOY_WF_ID:-$(DEPLOY_WF)}" -f env="$(ENV)"); \
	if [ -n "$(SHA)" ]; then cmd+=(-f sha="$(SHA)"); fi; \
	printf '%q ' "$${cmd[@]}"; echo; \
	"$${cmd[@]}"

wf/run-dora:
	$(Q)gh workflow run "$${DORA_WF_ID:-$(DORA_WF)}"

# ---------------- fetch artifacts -------
$(ARTDIR):
	$(Q)install -d "$@"

wf/fetch-window:
	@test -x ci/dora/fetch_window_events.sh || { echo "ERR: missing ci/dora/fetch_window_events.sh"; exit 64; }
	@WINDOW_DAYS='$(WINDOW_DAYS)' REPO='$(REPO)' DEPLOY_WF_ID='$(DEPLOY_WF_ID)' DEPLOY_WF='$(DEPLOY_WF)' MAIN_BRANCH='$(MAIN_BRANCH)' \
	ARTDIR='$(ARTDIR)' EVENTS='$(EVENTS)' ARTNAME='$(ARTNAME)' \
	bash ci/dora/fetch_window_events.sh


wf/fetch-latest: | $(ARTDIR)
	$(Q)$(E) rid="$$(gh run list --repo '$(REPO)' --workflow "$${DEPLOY_WF_ID:-$(DEPLOY_WF)}" --branch '$(MAIN_BRANCH)' -L 50 \
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
	rid="$$(gh run list --repo '$(REPO)' --workflow "$${DEPLOY_WF_ID:-$(DEPLOY_WF)}" --branch '$(MAIN_BRANCH)' -L 50 \
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
 
$(Q)$(E) LT_PAIR_MODE=both python3 ci/dora/dora-refactor/main.py '$(EVENTS)' | tee dora.out.txt 


wf/obs: ## resolve → fetch → merge PRs → probe → compute
	@$(MAKE) wf/resolve DEPLOY_WF_PATH=$(DEPLOY_WF_PATH) DORA_WF_PATH=$(DORA_WF_PATH)
	@gh auth status >/dev/null 2>&1 || { [ -n "$$GH_TOKEN" ] || { echo "ERR: GH auth missing (set GH_TOKEN)"; exit 64; }; }
	@echo "[obs] repo=$(REPO) window=$(WINDOW_DAYS) deploy=$(DEPLOY_SEL) dora=$(DORA_SEL) sha=$(SHA)"
	@if [ -n "$(SHA)" ]; then \
		$(MAKE) wf/fetch-by-sha SHA=$(SHA); \
	else \
		$(MAKE) wf/fetch-latest; \
	fi
	@$(MAKE) wf/merge-prs
	@$(MAKE) wf/probe
	@$(MAKE) wf/compute-dora

# ---------------- chains --------------
wf/obs: wf/prepare-events wf/probe wf/compute-dora
wf/prepare-events: wf/fetch-window wf/merge-prs wf/guard-pairing
	$(Q)echo "prepared $(EVENTS)"

wf/all: wf/prepare-events wf/probe wf/compute-dora
wf/all-by-sha: wf/fetch-by-sha wf/merge-prs wf/probe wf/compute-dora
