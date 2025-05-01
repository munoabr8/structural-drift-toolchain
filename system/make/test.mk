STRUCT_VAL_TEST=system-test/structure_validator

STRUCT_NEG_VAL_TEST=system-test/structure_negative_tests

TEST_GARBAGE=system-test/garbage_detector



test-all:
	@make test-structure
	@make test-garbage-detector
	@make test-negative-structure



test-structure:
	@echo "🧪 Running structure validation tests..."
	@bats $(STRUCT_VAL_TEST)

test-negative-structure:
	@echo "❗ Running negative structure validation tests..."
	@bats $(STRUCT_NEG_VAL_TEST)

test-garbage-detector:
	@echo "🧪 Running garbage_detector validation tests..."
	@bats $(TEST_GARBAGE)