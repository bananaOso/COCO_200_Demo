#!/bin/bash
# ============================================================
# Hook 1: Feature Branch Enforcer (PreToolUse)
# Blocks dbt commands and destructive SQL on main/master.
# All work must happen on a feature branch.
#
# Matcher: Bash
# Exit 0 = allow, Exit 2 = block
# ============================================================

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  exit 0
fi

if echo "$CMD" | grep -qE 'dbt (run|build|test|seed|snapshot|compile)'; then
  echo "BLOCKED: Cannot run dbt commands on '$BRANCH'." >&2
  echo "Create a feature branch first:" >&2
  echo "  git checkout -b feature/your-change-name" >&2
  exit 2
fi

if echo "$CMD" | grep -qiE '(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|MERGE|TRUNCATE|REPLACE).*(TABLE|VIEW|SCHEMA|DATABASE|TASK|STREAM|PIPE|STAGE|PROCEDURE|FUNCTION)'; then
  echo "BLOCKED: Cannot execute DDL/DML on '$BRANCH'." >&2
  echo "Create a feature branch first:" >&2
  echo "  git checkout -b feature/your-change-name" >&2
  exit 2
fi

if echo "$CMD" | grep -qE 'snow sql'; then
  if echo "$CMD" | grep -qiE '(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|MERGE|TRUNCATE)'; then
    echo "BLOCKED: Cannot execute destructive SQL via snow CLI on '$BRANCH'." >&2
    echo "Create a feature branch first:" >&2
    echo "  git checkout -b feature/your-change-name" >&2
    exit 2
  fi
fi

exit 0
