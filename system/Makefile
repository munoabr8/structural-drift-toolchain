# Makefile – Structural Enforcement

# Config
STRUCTURE_SPEC=./system/structure.spec
VALIDATOR=./system/validate_structure.sh
CONTEXT_CHECK=./attn/context-status.sh

# Run all structure checks
enforce-structure:
	@echo "🔍 Enforcing structure from $(STRUCTURE_SPEC)..."
	@bash $(VALIDATOR) $(STRUCTURE_SPEC)

# Health check: structure + context
health:
	@echo "🩺 Running full system health check..."
	@bash $(CONTEXT_CHECK)




# Example testable action for CI or pre-push
#prepush-check:
#	make enforce-structure

#.PHONY: enforce-structure prepush-check
