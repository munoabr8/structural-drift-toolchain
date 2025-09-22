# system/make/pipeline.mk — run tests + observations in one shot
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.PHONY: pipeline test-only obs-only artifacts

# Reuse your existing includes:
# include ./system/make/dora.mk      # exposes: exact
# include ./system/make/obs.mk       # exposes: snapshot, metrics, clean, probe

# Where observation artifacts land
OBS_DIR ?= obs
# Auto-pick latest dora.json in obs/
LATEST_DORA := $(shell ls -1t $(OBS_DIR)/dora.*.json 2>/dev/null | head -1 || echo)

pipeline: test-only obs-only artifacts
	@echo "OK: pipeline completed"

test-only:
	@echo "== TESTS =="
	$(MAKE) exact

obs-only:
	@echo "== OBSERVATIONS =="
	# collect+compute and stash artifacts
	$(MAKE) snapshot

artifacts:
	@echo "== METRICS =="
	@if [ -n "$(LATEST_DORA)" ]; then \
	  $(MAKE) metrics FILE="$(LATEST_DORA)"; \
	else \
	  echo "no dora.json snapshots yet"; \
	fi
