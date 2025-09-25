# whereami.mk
.PHONY: where files vars targets plan

where: ## Print locus and parity hints
	@echo "PWD=$$(pwd)"
	@echo "GIT_SHA=$$(git rev-parse --short HEAD 2>/dev/null || echo none)"
	@echo "UTC=$$(date -u +%FT%TZ)"
	@echo "VM?=$${VM:-iso}  OUT?=$${OUT:-events.ndjson}"
	@echo "Makefiles included:"; \
	  make -pn | sed -n '1,/^# Variables/ s/^#\s*.*Makefile.*//p' | sed 's/^# //;/^$$/d' | sed -n '1,20p'

files: ## Show core artifacts if present
	@ls -lh events.ndjson leadtime.csv dora.json 2>/dev/null || echo "no core artifacts"

vars: ## Print key variables
	@printf "WINDOW_DAYS=%s\n" "$${WINDOW_DAYS:-unset}"
	@printf "MAIN_BRANCH=%s\n" "$${MAIN_BRANCH:-unset}"
	@printf "DEPLOY_WORKFLOW_NAME=%s\n" "$${DEPLOY_WORKFLOW_NAME:-unset}"
	@printf "DEPLOY_WORKFLOW_ID=%s\n" "$${DEPLOY_WORKFLOW_ID:-unset}"
	@printf "OUT=%s\n" "$${OUT:-events.ndjson}"

targets: ## List first 80 targets
	@make -qp | awk -F: '/^[a-zA-Z0-9][^$$#\/\t=]*:([^=]|$$)/{print $$1}' | sort -u | sed -n '1,80p'

plan: ## Show what 'obs' would do without running it
	@make -n obs || echo "no 'obs' target"
