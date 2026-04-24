#!/bin/bash
# ============================================================
# Hook 3: dbt Test-and-Fix Loop (Stop)
# Runs on the Stop event — fires when the agent tries to finish.
# Executes dbt build (or dbt test) on modified models.
# If tests fail, blocks the agent from stopping and feeds
# the failure output back, forcing a fix-and-retry loop.
#
# Matcher: (none — Stop hooks don't use matchers)
# Output: JSON with "continue": false + "stopReason" to keep agent alive
# Exit 0 = allow stop, special stdout JSON = block stop
# ============================================================

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

DBT_PROJECT=""
if [ -f "$CWD/dbt_project.yml" ]; then
  DBT_PROJECT="$CWD"
else
  SEARCH="$CWD"
  while [ "$SEARCH" != "/" ]; do
    if [ -f "$SEARCH/dbt_project.yml" ]; then
      DBT_PROJECT="$SEARCH"
      break
    fi
    SEARCH=$(dirname "$SEARCH")
  done
fi

if [ -z "$DBT_PROJECT" ]; then
  exit 0
fi

CHANGED_MODELS=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
  
  CHANGED_MODELS=$(echo "$CHANGED_FILES" | grep -E '\.sql$' | grep -E '(models|snapshots|seeds)/' | sed 's|.*/||' | sed 's|\.sql$||' | sort -u | tr '\n' ' ')
fi

SELECTOR=""
if [ -n "$CHANGED_MODELS" ]; then
  SELECTOR=$(echo "$CHANGED_MODELS" | tr ' ' '\n' | grep -v '^$' | sed 's/^/--select /' | head -20 | tr '\n' ' ')
fi

cd "$DBT_PROJECT"

if [ -n "$SELECTOR" ]; then
  DBT_CMD="dbt build $SELECTOR 2>&1"
else
  DBT_CMD="dbt build 2>&1"
fi

DBT_OUTPUT=$(eval "$DBT_CMD")
DBT_EXIT=$?

if [ $DBT_EXIT -eq 0 ]; then
  PASS_COUNT=$(echo "$DBT_OUTPUT" | grep -c 'PASS')
  echo "$DBT_OUTPUT" | tail -20 >&2
  echo "dbt build passed ($PASS_COUNT tests). Agent may stop." >&2
  exit 0
fi

FAILURES=$(echo "$DBT_OUTPUT" | grep -E '(FAIL|ERROR|Compilation Error|Runtime Error)' | head -30)
FAIL_COUNT=$(echo "$DBT_OUTPUT" | grep -cE '(FAIL|ERROR)')

ESCAPED_OUTPUT=$(echo "$DBT_OUTPUT" | tail -80 | jq -Rs '.')
ESCAPED_FAILURES=$(echo "$FAILURES" | jq -Rs '.')

cat <<EOF
{
  "continue": false,
  "stopReason": "dbt build failed with $FAIL_COUNT error(s). You must fix these before completing the task.\n\nFailed tests/models:\n$(echo "$FAILURES" | head -15)\n\nFull output (last 80 lines):\n$(echo "$DBT_OUTPUT" | tail -80)\n\nInstructions:\n1. Read the error messages above carefully\n2. Fix the failing models or tests\n3. The hook will re-run dbt build automatically when you try to finish again\n4. Do NOT skip tests or mark the task as complete until all pass"
}
EOF
