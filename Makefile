# Makefile – Structural Enforcement

STRUCTURE_SPEC=./system/structure.spec
VALIDATOR=./system/validate_structure.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=../debugtools/structureDebugging.sh

.PHONY: health precommit-check check-structure-drift snapshot-structure enforce-structure context-health snapshot-and-promote

health:
	@echo "🩺 Running full system health check..."
	@make check-structure-drift
	@make enforce-structure
	@make context-health

precommit-check:
	@make check-structure-drift

check-structure-drift:
	@echo "🚨 Enforcing structure integrity..."
	@test -f $(SNAPSHOT_GEN) || (echo "❌ Missing: $(SNAPSHOT_GEN)" && exit 1)
	@bash $(SNAPSHOT_GEN) generate_structure_spec > .structure.snapshot
	@diff -u $(STRUCTURE_SPEC) .structure.snapshot
	# @rm -f .structure.snapshot

enforce-structure:
	@test -f $(STRUCTURE_SPEC) || (echo "❌ Missing spec file: $(STRUCTURE_SPEC)" && exit 1)
	@test -x $(VALIDATOR) || (echo "❌ Validator not executable: $(VALIDATOR)" && exit 1)
	@echo "🔍 Enforcing structure from $(STRUCTURE_SPEC)..."
	@bash $(VALIDATOR) $(STRUCTURE_SPEC)

context-health:
	@echo "🧠 Validating project context..."
	@bash $(CONTEXT_CHECK)

snapshot-and-promote:
	@test -f .structure.snapshot || (echo "❌ Missing snapshot file: .structure.snapshot" && exit 1)
	@echo "🚀 Promoting snapshot to enforced structure.spec..."
	@cp .structure.snapshot $(STRUCTURE_SPEC)
	@echo "✅ structure.spec has been updated."

snapshot-structure:
	@test -f $(SNAPSHOT_GEN) || (echo "❌ Missing: $(SNAPSHOT_GEN)" && exit 1)
	@echo "📸 Generating current structure snapshot..."
	@bash $(SNAPSHOT_GEN) generate_structure_spec > .structure.snapshot
