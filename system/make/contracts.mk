# ---- paths
CONTRACT_DIR := ci/contract/
NORMALIZER   := $(CONTRACT_DIR)/jq/normalize_v1.jq


CONTRACT_SRC := $(wildcard $(CONTRACT_DIR)/*.contract.json)
CONTRACT_OUT := $(CONTRACT_SRC:.contract.json=.norm.json)

.PHONY: contracts contracts-check clean
contracts: $(CONTRACT_OUT)

# Normalize each *.contract.json -> *.norm.json
$(CONTRACT_DIR)/%.norm.json: $(CONTRACT_DIR)/%.contract.json $(NORMALIZER)
	jq -f $(NORMALIZER) $< > $@

# Basic structural checks on normalized files
contracts-check: contracts
	@set -e; \
	for f in $(CONTRACT_OUT); do \
	  jq -e '
	    .schema=="ir/v1" and
	    (.args|type=="array") and
	    (.env|type=="object") and
	    (.tools|type=="array") and
	    (.exit.ok==0) and
	    (.writes|type=="array")
	  ' "$$f" >/dev/null || { echo "FAIL $$f"; exit 64; }; \
	  echo "OK  $$f"; \
	done

clean:
	rm -f $(CONTRACT_OUT)
