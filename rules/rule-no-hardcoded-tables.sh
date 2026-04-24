#!/bin/bash
# rule-no-hardcoded-tables.sh
# PreToolUse hook — Blocks hardcoded database.schema.table references in dbt SQL
#
# Why: Hardcoded table references break dbt's DAG lineage, prevent incremental
# builds, and fail when promoting across environments (dev -> staging -> prod).
# Always use {{ ref('model') }} or {{ source('src', 'table') }}.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.code // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check SQL files in the dbt models directory
if [ -n "$FILE" ]; then
    if ! echo "$FILE" | grep -qE 'models/.*\.sql$'; then
        exit 0
    fi
fi

check_hardcoded_refs() {
    local text="$1"
    # Match patterns like: FROM database.schema.table or JOIN schema.table
    # But ignore jinja ref() and source() calls
    if echo "$text" | grep -vE '\{\{' | grep -qiE '(FROM|JOIN)\s+[A-Za-z_]+\.[A-Za-z_]+\.[A-Za-z_]+'; then
        echo "BLOCKED: Hardcoded table reference detected in dbt model." >&2
        echo "" >&2
        echo "Use dbt ref() or source() instead:" >&2
        echo "  BAD:  FROM analytics.public.dim_customers" >&2
        echo "  GOOD: FROM {{ ref('dim_customers') }}" >&2
        echo "  GOOD: FROM {{ source('stripe', 'payments') }}" >&2
        echo "" >&2
        echo "Why: Hardcoded refs break DAG lineage, CI/CD, and environment promotion." >&2
        exit 2
    fi
}

case "$TOOL" in
    Write|Edit)
        [ -n "$CONTENT" ] && check_hardcoded_refs "$CONTENT"
        ;;
esac

exit 0
