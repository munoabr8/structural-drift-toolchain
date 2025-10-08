# === Main Makefile - "The Conductor" ===

#Make root file


# I can even show you
# 🔹 how to auto-discover all .mk files and include dynamically,
# 🔹 how to document targets,
# 🔹 how to prevent naming collisions across partials.

# Just say:

#     "Show me the dynamic include upgrade!"

# Next update:

# # 🧠 Logical aliases (semantic grouping)

# query:
# 	@echo "📚 Available Query Targets:"
# 	@grep -h -A1 '^# === Queries ===' mk/*.mk | grep -v '^#' | sed 's/:.*//'

# command:
# 	@echo "🚀 Available Command Targets:"
# 	@grep -h -A1 '^# === Commands ===' mk/*.mk | grep -v '^#' | sed 's/:.*//'



# 👉 Make all Make targets atomic, idempotent, and visibly grouped.

# These override lines are currently required because there is some other file
# that is setting the incorrect path!!!

 
 
 
# Global Variables
 
CONTEXT_CHECK=./attn/context-status.sh

DOCTOR=./tools/doctor.sh
AUTO_README_GEN=./tools/gen_readme.sh



# Dynamically include all make partials
#    MAKEFILES := $(wildcard ./system/make/*.mk)
# #  $(info 🔍 Including: $(MAKEFILES))

#   include $(MAKEFILES)

 include ./system/make/preflight.mk
 include ./system/make/structure.mk
  include ./system/make/test.mk
 #include ./system/make/hooks.mk
 #include ./system/make/modules.mk
 #include ./system/make/test.mk
 include ./system/make/health.mk
 #include ./system/make/garbage.mk
 include ./system/make/help.mk
 include ./system/make/guard_rails.mk

 include ./system/make/obs.mk
 include ./system/make/pipeline.mk
 include ./system/make/observe.pipeline.mk
 include ./system/make/workflows.mk
 include ./system/make/env_iso.mk
 include ./system/make/vm.mk
 include ./system/make/whereami.mk
 include ./system/make/isoANDdora.mk
 include ./system/make/contracts.mk
 include ./system/make/isolation.mk
 include ./system/make/env.mk

#test-structure-generator:
	#@echo "🧪 Testing structure spec generation..."
	#@bats --show-output-of-passing-temsts system-test/structure_generator/

execute-main-help:
	@bash ./bin/main.sh help


execute-main-integrity:
	@bash ./bin/main.sh self-test

execute-main-context:
	@bash ./bin/main.sh context		

execute-main-init:
	@bash ./bin/main.sh init

execute-main-start:
	@bash ./bin/main.sh start

test-accept:
	bash ./test/acceptance/run_acceptance.sh 

.DEFAULT_GOAL := help




# Colors if terminal
COLOR ?= $(shell test -t 1 && tput setaf 6 2>/dev/null || true)
BOLD  ?= $(shell test -t 1 && tput bold      2>/dev/null || true)
OFF   ?= $(shell test -t 1 && tput sgr0      2>/dev/null || true)

help: ## Welcome + show common targets
	@echo "$(BOLD)Welcome to the Structural Drift Toolchain$(OFF)"
	@echo "----------------------------------------------------"
	@echo "Repository root:  $$(git rev-parse --show-toplevel 2>/dev/null || echo n/a)"
	@echo "Current branch:   $$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
	@echo "Last commit:      $$(git log -1 --pretty=format:%h -s 2>/dev/null || echo n/a)"
	@echo
	@echo "This project uses Make targets to run workflows and pipelines."
	@echo "Artifacts are written to ./artifacts/, manifests under ./artifacts/runs."
	@echo
	@echo "Common tasks:"
	@awk 'BEGIN {FS ":.*##"; OFS=""} \
	  /^[a-zA-Z0-9_\/\.\%-]+:.*##/ { \
	    tgt=$$1; gsub(/^ +| +$$/,"",tgt); \
	    desc=$$2; gsub(/^ +| +$$/,"",desc); \
	    printf "  $(COLOR)%-24s$(OFF) %s\n", tgt, desc \
	  }' $(MAKEFILE_LIST) | sort
	@echo
	@echo "Try: make wf/compute-dora      # run DORA metrics"
	@echo "     MODE=vm bin/run-wf wf/probe  # run in a VM"



