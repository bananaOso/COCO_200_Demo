#!/bin/bash
# rule-staging-layer-purity.sh
# PreToolUse hook — Blocks joins and aggregations in staging models
#
# Why: Staging models should be thin wrappers over source tables.
# They rename, cast, and filter — nothing else. Joins and business
# logic belong in intermediate models. This keeps the DAG clean
# and each layer testable in isolation.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.code // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check staging model files
if [ -z "$FILE" ] || ! echo "$FILE" | grep -qE 'models/staging/.*\.sql$'; then
    exit 0
fi

if [ -z "$CONTENT" ]; then
    exit 0
fi

# Block JOINs in staging
if echo "$CONTENT" | grep -qiE '\bJOIN\b'; then
    echo "BLOCKED: JOIN detected in a staging model." >&2
    echo "" >&2
    echo "Staging models must NOT contain joins." >&2
    echo "Move join logic to an intermediate model:" >&2
    echo "  models/intermediate/int_<entity>__<verb>.sql" >&2
    echo "" >&2
    echo "Staging = rename, cast, filter ONLY." >&2
    exit 2
fi

# Block GROUP BY in staging
if echo "$CONTENT" | grep -qiE '\bGROUP\s+BY\b'; then
    echo "BLOCKED: GROUP BY detected in a staging model." >&2
    echo "" >&2
    echo "Staging models must NOT contain aggregations." >&2
    echo "Move aggregation logic to an intermediate or marts model." >&2
    exit 2
fi

# Block window functions in staging
if echo "$CONTENT" | grep -qiE '\bOVER\s*\('; then
    echo "BLOCKED: Window function detected in a staging model." >&2
    echo "" >&2
    echo "Staging models must NOT contain window functions." >&2
    echo "Move this logic to an intermediate model." >&2
    exit 2
fi

exit 0
