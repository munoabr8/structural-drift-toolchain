# garbage.mk — Detects garbage files or uncommitted changes before push

.PHONY: test-garbage

test-garbage:
	@echo "🧪 Running garbage_detector validation tests..."
	@bats system-test/garbage_detector