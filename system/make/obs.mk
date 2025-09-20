# system/make/obs.mk — minimal observation harness
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.PHONY: probe snapshot metrics clean

OBS_DIR := obs
STAMP   := $(shell date -u +%Y%m%dT%H%M%SZ)

# Run a single probe script
# Usage: make probe P=t/probes/foo.sh
#   make probe P=t/probes/foo.sh
#   make probe P=t/probes/foo.sh ARGS="input.json --verbose"
P ?=
ARGS ?=
probe:
	@test -n "$(P)" || { echo "need P=probe_path"; exit 64; }
	mkdir -p $(OBS_DIR)
	"$(P)" $(ARGS) | tee "$(OBS_DIR)/$$(basename $(P)).$(STAMP).out"

# Snapshot: collect + compute + stash results
snapshot:
	mkdir -p $(OBS_DIR)
	env WINDOW_DAYS=14 bash ci/dora/collect-events.sh events.ndjson
	python3 ci/dora/compute-dora.py events.ndjson > "$(OBS_DIR)/compute.$(STAMP).log" 2>&1 || true
	@test -f dora.json && cp dora.json "$(OBS_DIR)/dora.$(STAMP).json" || true
	@test -f leadtime.csv && cp leadtime.csv "$(OBS_DIR)/leadtime.$(STAMP).csv" || true

# Quick metrics extractor
# Usage: make metrics FILE=obs/dora.<stamp>.json
FILE ?=
metrics:
	@test -n "$(FILE)" && test -f "$(FILE)" || { echo "need FILE=dora.json"; exit 64; }
	jq '{deploys:.metrics.deploys_total, lead_n:.lead_time.samples, median:.lead_time.median_h}' "$(FILE)"

# Clean observations
clean:
	rm -rf $(OBS_DIR)
