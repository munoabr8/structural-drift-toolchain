# garbage.mk — Detects garbage files or uncommitted changes before push

.PHONY: test-garbage

test-garbage:
	@echo "🧪 Running garbage_detector validation tests..."
	@bats ./test/e2e/garbage_detector