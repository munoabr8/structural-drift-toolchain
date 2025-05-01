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

# Import Partials
include ./system/make/health.mk
include ./system/make/structure.mk
include ./system/make/test.mk
include ./system/make/modules.mk
include ./system/make/hooks.mk
include ./system/make/preflight.mk


.DEFAULT_GOAL := health


