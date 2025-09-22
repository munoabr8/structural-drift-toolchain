SHELL := /usr/bin/env bash
EVENTS ?= ci/dora/events.ndjson

.PHONY: probe-events probe-pairs audit-observability audit-identifiability compute-dora

## 1) Basic probes
probe-events:
	@bash ci/probe.sh "$(EVENTS)" --kind events

m:
	@bash ci/dora/probe_pairs.sh "$(EVENTS)"

## 2) Observability: do outputs exist to reconstruct targets?
#   Lead time needs BOTH pr_merged and deployment events.
: probe-events
	@jq -s '{
	  pr:   map(select(.type=="pr_merged"))     | length,
	  dep:  map(select(.type=="deployment"))    | length
	}' "$(EVENTS)" \
	| tee /dev/stderr \
	| jq -e '(.pr>0) and (.dep>0)' >/dev/null || { echo "OBSERVABILITY_FAIL"; exit 2; }

## 3) Identifiability: is mapping unique enough to estimate?
#   Require join keys and timestamps for pairing PR→Deploy, and >=$(MIN_SAMPLES).

audit-identifiability: probe-events probe-pairs
	@MIN_SAMPLES="$${MIN_SAMPLES:-2}"; \
	jq -s '{pr_ok: ([.[]|select(.type=="pr_merged")|select((.sha|type)=="string" and (.merged_at|type)=="string")]|length), dep_ok: ([.[]|select(.type=="deployment")|select((.sha|type)=="string" and (((.finished_at//.deploy_at)|type)=="string"))]|length)}' "$(EVENTS)" \
	| tee /dev/stderr \
	| jq -e --argjson n "$$MIN_SAMPLES" '.pr_ok>=$$n and .dep_ok>=$$n' >/dev/null \
	|| { echo "IDENTIFIABILITY_FAIL"; exit 3; }

	@jq -s '{
	  pr_ok:   [ .[] | select(.type=="pr_merged" ) | select((.sha|type)=="string" and (.merged_at|type)=="string") ] | length,
	  dep_ok:  [ .[] | select(.type=="deployment") | select((.sha|type)=="string" and ((.finished_at//.deploy_at)|type)=="string") ] | length
	}' "$(EVENTS)" \
	| tee /dev/stderr \
	| jq -e --argjson n $(MIN_SAMPLES) '(.pr_ok>=($n)) and (.dep_ok>=($n))' >/dev/null || { echo "IDENTIFIABILITY_FAIL"; exit 3; }

obs/show-rows:
	@echo "== pr_rows ==";  jq -c 'select(.type=="pr_merged")    | {pr,sha,merged_at}'     "$(EVENTS)" | head -20
	@echo "== dep_rows =="; jq -c 'select(.type=="deployment")  | {sha,finished_at,deploy_at,status}' "$(EVENTS)" | head -20

obs/show-bad-fields:
	@jq -s "to_entries[] | select(.value|type==\"object\") | select(.value.sha|type!=\"string\") | {i:.key, kind:(.value.type // \"unknown\"), sha_type:(.value.sha|type), row:.value}" "$(EVENTS)" | tee /dev/stderr

obs/show-bad-dep-ts:
	@jq -s "to_entries[] | select(.value|type==\"object\" and .value.type==\"deployment\") | select(((.value.finished_at // .value.deploy_at)|type)!=\"string\") | {i:.key, row:.value}" "$(EVENTS)" | tee /dev/stderr


obs/show-dep-rows:
	@jq -c 'select(.type=="deployment") | {sha,finished_at,deploy_at,status}' "$(EVENTS)" | head -20

obs/show-pr-rows:
	@jq -c 'select(.type=="pr_merged") | {pr,sha,merged_at}' "$(EVENTS)" | head -20

obs/why-identify:
	@jq -s 'to_entries[] | {i:.key, type:(.value|type)}' "$(EVENTS)" | sed -n '1,120p'
	@jq -s -f ci/jq/why_identify.jq "$(EVENTS)" | tee /dev/stderr

## 4) Compute metrics once gates pass
compute-dora2: audit-observability audit-identifiability
	@python3 ci/dora/compute-dora.py "$(EVENTS)"
