#./system/make/structure.mk


STRUCTURE_SPEC=./structure.spec
VALIDATOR=./system/structure_validator.rf.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=./tools/structure/structure_snapshot_gen.sh

#.PHONY: aggregate-spec lock-structure doctor health validate-modules test-garbage-detector test-negative-structure precommit-check check-structure-drift snapshot-structure enforce-structure context-health snapshot-and-promote detect
   


check-structure-drift:
	@echo "🚨 Enforcing structure integrity..."
	@test -f $(SNAPSHOT_GEN) || (echo "❌ Missing: $(SNAPSHOT_GEN)" && exit 1)

	@bash $(SNAPSHOT_GEN) generate_structure_spec . > .structure.snapshot || echo "⚠️ Snapshot generation non-critical failure (check manually)"
	@diff -u $(STRUCTURE_SPEC) .structure.snapshot || echo "❗ Structure drift detected — please snapshot-and-promote if intended."


# diff-structure manual drift review
diff-structure:
	@echo "🔍 Diffing current structure against system/structure.spec..."
	@test -f $(SNAPSHOT_GEN) || (echo "❌ Missing: $(SNAPSHOT_GEN)" && exit 1)		
	@bash $(SNAPSHOT_GEN) generate_structure_spec . > .structure.snapshot
	@diff -u $(STRUCTURE_SPEC) .structure.snapshot || echo "⚠️  Drift detected — review above diff."


diff-structure2:
	@echo "🔍 Diffing ${STRUCTURE_SPEC} ⟷ .structure.snapshot"
	@bash ./tools/structure_compare.sh "${STRUCTURE_SPEC}" .structure.snapshot \
	|| { echo "Error"; exit 1; }
	@echo "Testing"

enforce-structure:
	@test -f $(STRUCTURE_SPEC) || (echo "❌ Missing spec file: $(STRUCTURE_SPEC)" && exit 1)
	@test -x $(VALIDATOR) || (echo "❌ Validator not executable: $(VALIDATOR)" && exit 1)
	@echo "🔍 Enforcing structure from $(STRUCTURE_SPEC)..."
	@bash $(VALIDATOR) $(STRUCTURE_SPEC)



###############################################################
#####################COMMANDS###############################
###############################################################
snapshot-structure:
	@test -f $(SNAPSHOT_GEN) || (echo "❌ Missing: $(SNAPSHOT_GEN)" && exit 1)
	@echo "📸 Generating current structure snapshot..."
	@bash $(SNAPSHOT_GEN) generate_structure_snapshot . > .structure.snapshot; \
 	EXIT_CODE=$$?; \
 	echo "🔁 Return code from generate_structure_snapshot: $$EXIT_CODE";  \
 
	 


snapshot-and-promote:
	@test -f .structure.snapshot || (echo "❌ Missing snapshot file: .structure.snapshot" && exit 1)
	@echo "🚀 Promoting snapshot to enforced structure.spec..."
	@cp .structure.snapshot $(STRUCTURE_SPEC)
	@echo "✅ structure.spec has been updated."



 


	
