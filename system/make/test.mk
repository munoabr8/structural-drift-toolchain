STRUCT_VAL_TEST=system-test/structure_validator

STRUCT_NEG_VAL_TEST=system-test/structure_negative_tests

TEST_GARBAGE=system-test/garbage_detector



test-all: test-structure  test-garbage  test-negative-structure



test-structure:
	@bats $(STRUCT_VAL_TEST)

test-negative-structure:
	@bats $(STRUCT_NEG_VAL_TEST)

test-garbage:
	@echo "🧪 Running garbage_detector validation tests..."
	@bats system-test/garbage_detector


# test-garbage:
# 	@echo "🔍 Running garbage detection..."
# 	@git status --porcelain | grep -v '^??' > /dev/null && \
# 	  { echo "❌ Garbage detected — push blocked."; exit 1; } || \
# 	  echo "✅ No garbage detected."