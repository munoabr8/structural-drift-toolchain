# === Config ===

STRUCTURE_SPEC=./system/structure.spec
VALIDATOR=./system/validate_structure.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=../debugtools/structureDebugging.sh

# === Preflight ===


validate-ignore:
	@bash tools/validate_ignore.sh

test-ignore:
	@echo "🧪 Running .structure.ignore validation tests..."
	@bats system-test/structure_ignore/

check-trash:
	@bash tools/check_git_trash.sh


preflight: validate-ignore preflight-drift preflight-enforce preflight-context
	@echo "✅ Preflight checks passed!"

preflight-drift:
	@echo "🔍 Checking for structure drift..."
	@bash $(SNAPSHOT_GEN) generate_structure_spec . > .structure.snapshot
	@diff -u $(STRUCTURE_SPEC) .structure.snapshot || (echo "❌ Drift detected. Run make diff-structure!" && exit 1)

preflight-enforce:
	@echo "🔒 Validating enforced structure..."
	@bash $(VALIDATOR) $(STRUCTURE_SPEC)

preflight-context:
	@echo "🧠 Validating project context sanity..."
	@bash $(CONTEXT_CHECK)

# (Optional, if module validation polished later:)
# preflight-modules:
# 	@echo "📦 Validating individual modules..."
# 	@$(MAKE) validate-modules
