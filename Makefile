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

# #   include $(MAKEFILES)

  include ./system/make/preflight.mk
   include ./system/make/structure.mk
   include ./system/make/test.mk
#  #include ./system/make/hooks.mk
#  #include ./system/make/modules.mk

#  include ./system/make/health.mk
#  #include ./system/make/garbage.mk
#  include ./system/make/help.mk
#  include ./system/make/guard_rails.mk

#  include ./system/make/obs.mk
#  include ./system/make/pipeline.mk
#  include ./system/make/observe.pipeline.mk
  include ./system/make/workflows.mk
#  include ./system/make/env_iso.mk
  include ./system/make/vm.mk
#  include ./system/make/whereami.mk
#  include ./system/make/isoANDdora.mk
#   include ./system/make/contracts.mk

# #test-structure-generator:
# 	#@echo "🧪 Testing structure spec generation..."
# 	#@bats --show-output-of-passing-temsts system-test/structure_generator/

# execute-main-help:
# 	@bash ./bin/main.sh help


# execute-main-integrity:
# 	@bash ./bin/main.sh self-test

# execute-main-context:
# 	@bash ./bin/main.sh context		

# execute-main-init:
# 	@bash ./bin/main.sh init

# execute-main-start:
# 	@bash ./bin/main.sh start

# test-accept:
# 	bash ./test/acceptance/run_acceptance.sh 


MAKE_BIN ?= gmake          # macOS: brew install make (provides gmake)
COMPLEXITY_FILES ?= Makefile

# === configuration section ===
MAKEFLAGS += -I config

-include system/make/includes/common.mk
#-include system/config/env.mk


-include local.mk
-include system/make/workflows.mk
-include config/vars.mk
-include local.mk
 
ART_DIR := $(CURDIR)/artifacts/complexity
EVIDENCE_ROOT ?= tools/evidence-kit/artifacts

TS            := $(shell date -u +%Y%m%dT%H%M%SZ)
MAKE_BIN      ?= $(MAKE)
 
# === normal targets below ===
.PHONY: all
all: build

build:
	@echo "Building..."

 

.PHONY: complexity/make complexity/check complexity/golden-update
 

.PHONY: complexity/log complexity/plot


complexity/log:
	@mkdir -p "$(ART_DIR)"
	@python3 system/complexity/make_indirection_complexity.py \
	  --make-bin "$(MAKE_BIN)" -f Makefile \
	  | tee "$(ART_DIR)/complexity.$(TS).json" >/dev/null
	@echo "wrote $(ART_DIR)"

complexity/log2:
	@mkdir -p $(ART_DIR)
	@python3 system/complexity/make_indirection_complexity.py \
	  --make-bin $(MAKE_BIN) -f Makefile \
	  | tee $(ART_DIR)/complexity.$(shell date -u +%Y%m%dT%H%M%SZ).json >/dev/null
	@echo "wrote $(ART_DIR)"


complexity/make:
	@python3 system/complexity/make_indirection_complexity.py \
	  --make-bin $(MAKE_BIN) \
	  $(foreach f,$(COMPLEXITY_FILES),-f $(f)) \
	  --threshold 40

complexity/check:
	@python3 system/complexity/make_indirection_complexity.py -f tests/complexity/mk/minimal.mk | jq -S . > /tmp/complexity.out.json
	@jq -S . tests/complexity/golden.ndjson > /tmp/complexity.golden.json
	@diff -u /tmp/complexity.golden.json /tmp/complexity.out.json

complexity/golden-update:
	@python3 system/complexity/make_indirection_complexity.py -f tests/complexity/mk/minimal.mk --pretty > tests/complexity/golden.ndjson


complexity/plot:
	@jq -r '.C_indirection' artifacts/complexity/*.json | gnuplot ...

.PHONY: radon/log
radon/log:
	@mkdir -p artifacts/complexity/radon

	@radon hal system/   > artifacts/complexity/radon/halstead.txt
	@radon mi -s system/ > artifacts/complexity/radon/maintainability.txt
	@radon cc -j system/ > artifacts/complexity/radon/cc.json


include ./tools/evidence-kit/hunchly.mk


ROOT ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ART_DIR ?= $(abspath $(ROOT)/artifacts)
CAPTURE_DEST ?= $(abspath $(ART_DIR)/capture)
PROBE ?= $(ROOT)/bin/env_probe

.PHONY: env-before env-after env-diff env-guard capture capture+env-diff

env-before:
	@mkdir -p '$(ART_DIR)/env'
	@'$(PROBE)' --print-env > '$(ART_DIR)/env/before.ndjson'

 
env-after:
	@'$(PROBE)' --print-env > '$(ART_DIR)/env/after.ndjson'

env-diff:
	@diff -u '$(ART_DIR)/env/before.ndjson' '$(ART_DIR)/env/after.ndjson' || true

#env-guard:
#@./bin/env_delta_guard.sh \
	 # '$(ART_DIR)/env/before.ndjson' '$(ART_DIR)/env/after.ndjson' \
	 # PATH,HOME,SHELL,ROOT,ART_DIR



.DEFAULT_GOAL := help


