#!/bin/bash
# rule-no-select-star.sh
# PreToolUse hook — Blocks SELECT * in any SQL command
#
# Why: SELECT * causes schema drift. If upstream adds a column,
# it silently flows into downstream models. Explicit column lists
# make changes intentional and reviewable.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.code // empty')

check_select_star() {
    local text="$1"
    if echo "$text" | grep -qiE 'SELECT\s+\*\s+FROM'; then
        echo "BLOCKED: SELECT * detected." >&2
        echo "" >&2
        echo "Use explicit column lists instead:" >&2
        echo "  BAD:  SELECT * FROM {{ ref('stg_orders') }}" >&2
        echo "  GOOD: SELECT order_id, customer_id, amount FROM {{ ref('stg_orders') }}" >&2
        echo "" >&2
        echo "Why: SELECT * causes silent schema drift when upstream tables change." >&2
        exit 2
    fi
}

case "$TOOL" in
    Bash)
        [ -n "$CMD" ] && check_select_star "$CMD"
        ;;
    Write|Edit)
        [ -n "$CONTENT" ] && check_select_star "$CONTENT"
        ;;
esac

exit 0
