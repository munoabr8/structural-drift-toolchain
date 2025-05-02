STRUCT_VAL_TEST=system-test/structure_validator

STRUCT_NEG_VAL_TEST=system-test/structure_negative_tests

TEST_GARBAGE=system-test/garbage_detector



test-all: test-structure #test-garbage-detector test-negative-structure



test-structure:
	@bats $(STRUCT_VAL_TEST)

#test-negative-structure:
	#@bats $(STRUCT_NEG_VAL_TEST)

#test-garbage-detector:
	#@bats $(TEST_GARBAGE)