#!/bin/bash
# rule-block-destructive-sql.sh
# PreToolUse hook — Blocks DROP, TRUNCATE, DELETE without WHERE
#
# Why: Destructive SQL in production is irreversible. Even in dev,
# accidental drops waste time rebuilding. Force explicit confirmation
# patterns instead of allowing unguarded destructive operations.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ "$TOOL" != "Bash" ] || [ -z "$CMD" ]; then
    exit 0
fi

# Block DROP TABLE/VIEW/SCHEMA/DATABASE
if echo "$CMD" | grep -qiE 'DROP\s+(TABLE|VIEW|SCHEMA|DATABASE)\s'; then
    echo "BLOCKED: DROP statement detected." >&2
    echo "" >&2
    echo "Destructive DDL is not allowed via agent." >&2
    echo "If you need to drop an object:" >&2
    echo "  1. Add it to a migration script in /migrations/" >&2
    echo "  2. Have a human review and execute it" >&2
    echo "" >&2
    echo "For development, use CREATE OR REPLACE instead." >&2
    exit 2
fi

# Block TRUNCATE
if echo "$CMD" | grep -qiE 'TRUNCATE\s+TABLE\s'; then
    echo "BLOCKED: TRUNCATE TABLE detected." >&2
    echo "Use a filtered DELETE or recreate the table instead." >&2
    exit 2
fi

# Block DELETE without WHERE clause
if echo "$CMD" | grep -qiE 'DELETE\s+FROM\s' && ! echo "$CMD" | grep -qiE 'WHERE\s'; then
    echo "BLOCKED: DELETE without WHERE clause." >&2
    echo "" >&2
    echo "Unfiltered DELETE removes all rows. Add a WHERE clause:" >&2
    echo "  BAD:  DELETE FROM my_table" >&2
    echo "  GOOD: DELETE FROM my_table WHERE created_at < '2024-01-01'" >&2
    exit 2
fi

exit 0
