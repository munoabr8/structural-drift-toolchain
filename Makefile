# === Main Makefile - "The Conductor" ===

#Make root file


# I can even show you
# 🔹 how to auto-discover all .mk files and include dynamically,
# 🔹 how to document targets,
# 🔹 how to prevent naming collisions across partials.

# Just say:

#     "Show me the dynamic include upgrade!"





# Global Variables
STRUCTURE_SPEC=./system/structure.spec
VALIDATOR=./system/validate_structure.sh
CONTEXT_CHECK=./attn/context-status.sh
SNAPSHOT_GEN=../debugtools/structureDebugging.sh
DOCTOR=./tools/doctor.sh
AUTO_README_GEN=./tools/gen_readme.sh



# Dynamically include all make partials
MAKEFILES := $(wildcard system/make/*.mk)
include $(MAKEFILES)

test-structure-generator:
	@echo "🧪 Testing structure spec generation..."
	@bats --show-output-of-passing-tests system-test/structure_generator/


# Import Partials
# include ./system/make/health.mk
# include ./system/make/structure.mk
# include ./system/make/test.mk
# include ./system/make/modules.mk
# include ./system/make/hooks.mk
# include ./system/make/preflight.mk

# regen-readme:
# 	@bash tools/gen_readme.sh


.DEFAULT_GOAL := health


