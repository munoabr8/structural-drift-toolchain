# === Config ===

#STRUCTURE_SPEC=./system/structure.spec
VALIDATOR_RF=./system/structure_validator.rf.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN_RF=./tools/structure/structure_snapshot_gen.sh


include system/make/preflight_shared.mk
# === Preflight ===

.PHONY: regen-readme
 
test-ignore:
	@echo "🧪 Running .structure.ignore validation tests..."
	@bats system-test/structure_ignore/

check-trash:
	@bash tools/check_git_trash.sh

regen-readme:
	@bash tools/gen_readme.rf.sh


regen-and-fix:
	@make regen-readme
	@if [ -f .missing_module_specs ]; then \
	  echo "⚙️  Fixing missing module specs..."; \
	  $(MAKE) fix-missing-specs; \
	else \
	  echo "✅ All specs present — no fix needed."; \
	fi

fix-missing-specs:
	@bash tools/fix_missing_specs.sh


# Use make preflight for local development.

preflight: validate-ignore preflight-drift preflight-enforce preflight-context regen-and-fix
		@echo "✅ Preflight checks passed!"


#  Use make preflight-ci as your CI check in .github/workflows, Git hooks, or pre-push hooks.

preflight-ci: validate-ignore preflight-drift preflight-enforce preflight-context regen-readme
	@echo "🚨 Checking for missing module specs..."
	@if [ -f .missing_module_specs ]; then \
	  echo "❌ Missing structure.spec files detected in some modules."; \
	  echo "    Run \`make fix-missing-specs\` locally before pushing."; \
	  exit 1; \
	else \
	  echo "✅ All module specs present. CI-safe."; \
	fi
 

# (Optional, if module validation polished later:)
# preflight-modules:
# 	@echo "📦 Validating individual modules..."
# 	@$(MAKE) validate-modules
