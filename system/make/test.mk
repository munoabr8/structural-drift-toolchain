STRUCT_VAL_TEST=test/e2e/structure_validator

STRUCT_NEG_VAL_TEST=test/e2e/structure_negative_tests




test-all: test-structure   test-negative-structure



test-structure:
	@bats $(STRUCT_VAL_TEST)

test-negative-structure:
	@bats $(STRUCT_NEG_VAL_TEST)
