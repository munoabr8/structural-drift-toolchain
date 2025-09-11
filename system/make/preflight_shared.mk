STRUCTURE_SPEC=structure.spec
VALIDATOR_RF=./system/structure_validator.rf.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=./tools/structure/structure_snapshot_gen.sh





validate-ignore:
	@bash tools/validate_ignore.sh

preflight-drift:
	@echo "🔍 Checking for structure drift..."
	@bash $(SNAPSHOT_GEN) --root . --out .structure.snapshot


	#@bash $(SNAPSHOT_GEN) generate_structure_spec . > .structure.snapshot
	@diff -u $(STRUCTURE_SPEC) .structure.snapshot || (echo "❌ Drift detected. Run make diff-structure!" && exit 1)


preflight-enforce:
	@echo "🔒 Validating enforced structure..."
	@bash $(VALIDATOR) --quiet validate $(STRUCTURE_SPEC)

preflight-context:
	@echo "🧠 Validating project context sanity..."
	@bash $(CONTEXT_CHECK)

