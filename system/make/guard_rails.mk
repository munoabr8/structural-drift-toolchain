# system/make/guard_rails.mk

guard-rails:
	@echo "Checking for forbidden commands..."
	@if grep -nE '\b(stat|find|ls|cat|grep|sed|awk|readlink|file|du|wc|ps|date|kill|read\s*-t)\b' lib/predicates.sh; then \
        echo "Forbidden commands found in predicates.sh"; exit 1; \
    fi
	@if grep -nE '\b(>|>>|rm|mv|cp|mkdir|touch|tee|truncate)\b' lib/queries.sh; then \
        echo "Forbidden commands found in queries.sh"; exit 1; \
    fi
	@echo "All clear."
