# Makefile – Structural Enforcement

STRUCTURE_SPEC=./system/structure.spec
VALIDATOR=./system/validate_structure.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=../debugtools/structureDebugging.sh

.PHONY: doctor health test-garbage-detector test-negative-structure precommit-check check-structure-drift snapshot-structure enforce-structure context-health snapshot-and-promote detect

health:
	@echo "🩺 Running full system health check..."
	@make check-structure-drift
	@make enforce-structure
	@make context-health

precommit-check:
	@make check-structure-drift

test-all:
	@make test-structure
	@make test-garbage-detector
	@make test-negative-structure

install-hooks:
	@bash tools/install-hooks.sh

test-structure:
	@echo "🧪 Running structure validation tests..."
	@bats system-test/structure_validator

test-negative-structure:
	@echo "❗ Running negative structure validation tests..."
	@bats system-test/structure_negative_tests

test-garbage-detector:
	@echo "🧪 Running garbage_detector validation tests..."
	@bats system-test/garbage_detector
	

doctor:
	@bash ./tools/doctor.sh $(STRUCTURE_SPEC)
 
detect-garbage:
	@bash ./tools/detect_garbage.sh $(STRUCTURE_SPEC)

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
