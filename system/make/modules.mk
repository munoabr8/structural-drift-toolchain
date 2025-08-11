VALIDATOR_RF=./system/validate_structure.sh
MODULE_SPEC_GEN=tools/generate_all_module_specs.sh
STRUCT_AGG=tools/aggregate_structure.sh
GARBAGE_DETECT=./tools/detect_garbage.sh

.PHONY: generate-module-specs aggregate-spec detect-garbage

#generate-module-specs:
	#@bash $(MODULE_SPEC_GEN)

#aggregate-spec:
	#@bash $(STRUCT_AGG) $(STRUCTURE_SPEC)


detect-garbage:
	@bash $(GARBAGE_DETECT) $(STRUCTURE_SPEC)

# # validate-modules:
# # 	@echo "🔍 Validating modules (excluding .structure.ignore)..."
# # 	@IGNORE=$(shell cat .structure.ignore 2>/dev/null | xargs) && \
# # 	for mod in $(shell find . -maxdepth 1 -type d ! -name "." ! -name ".git" ! -name "system" | sed 's|^\./||'); do \
# # 	  echo $$IGNORE | grep -wq "$$mod" && echo "⏭️  Skipping ignored module: $$mod" && continue; \
# # 	  echo "🔍 Validating $$mod..."; \
# # 	  bash $(VALIDATOR) "$$mod/structure.spec"; \
# # 	done	
