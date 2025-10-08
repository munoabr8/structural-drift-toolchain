# system/make/isolation.mk
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# Allowlist: comma or space separated, e.g. ALLOW="EVENTS,DEPLOY_ENV"
ALLOW="EVENTS,DEPLOY_ENV"
WF     ?=  env/ci 
#PIPE_CMD ?= bin/run-wf $(WF)
PIPE_CMD ?= $(if $(strip $(WF)),bin/run-wf $(WF),/bin/false)

# helper: transform ALLOW into VAR="value" pairs
define _ALLOW_EXPORTS
$(foreach v,$(subst $(comma), ,$(ALLOW)),$(if $(strip $(v)),$(v)="$($(strip $(v)))",))
endef
comma := ,

# Isolated run with clean env
 
run-env:
	@[ -n "$(strip $(WF))" ] || { echo "ERR: WF required"; exit 64; }
	@echo "[iso] WF=$(WF)"; 
	echo "[iso] ALLOW=$(ALLOW)"
	@echo "[iso] CMD=$(PIPE_CMD)"
	@env -i $(call _ALLOW_EXPORTS)  \
		PATH="$$PATH" HOME="$$HOME" SHELL="$$SHELL" \
	  	bash --noprofile --norc -lc 'umask 0022; $(PIPE_CMD)'