# === Config ===

STRUCTURE_SPEC=./system/structure.spec

CONTEXT_CHECK=./attn/context-status.sh

VALIDATOR=./system/validate_structure.sh

SNAPSHOT_GEN=../debugtools/structureDebugging.sh

DOCTOR=./tools/doctor.sh



# === Commands ===

context-health:
	@echo "🧠 Validating project context..."
	@bash $(CONTEXT_CHECK)


 
lock-structure: snapshot-structure enforce-structure
	@echo "🚀 Locking updated structure..."
	@test -f .structure.snapshot || (echo "❌ Missing snapshot — cannot lock structure!" && exit 1)
	@test -d .git || (echo "❌ Not inside a Git repo — cannot stage structure.spec" && exit 1)
	@{ cp .structure.snapshot $(STRUCTURE_SPEC) && git add $(STRUCTURE_SPEC); } || (echo "❌ Failed to lock structure" && exit 1)
	@echo "✅ structure.spec updated and staged."


health:
	@echo "🩺 Running full system health check..."
	@echo "🩺 Running full system health check..."
	@make diff-structure
	@echo "✅ Structure drift checked."
	@make enforce-structure
	@echo "✅ Structure enforced."
	@make context-health
	@echo "✅ Context health verified."

doctor:
	@test -x $(DOCTOR) || (echo "❌ Doctor script missing!" && exit 1)
	@bash $(DOCTOR) $(STRUCTURE_SPEC)
