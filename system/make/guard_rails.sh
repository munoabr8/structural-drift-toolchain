# ./system/guard_rails.mk

guardrails:
    @grep -nE '\b(stat|find|ls|cat|grep|sed|awk|readlink|file|du|wc|ps|date|kill|read\s*-t)\b' lib/predicates.sh && exit 1
    @grep -nE '\b(>|>>|rm|mv|cp|mkdir|touch|tee|truncate)\b' lib/queries.sh && exit 1