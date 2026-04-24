#!/bin/bash
# rule-require-schema-yml.sh
# Stop hook — Blocks agent completion if new dbt models lack schema.yml entries
#
# Why: Models without schema.yml have no documentation, no tests, and no
# column descriptions. This creates invisible technical debt. Every model
# must be documented and tested before the agent can declare "done".

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

if [ ! -f "$CWD/dbt_project.yml" ]; then
    exit 0
fi

CHANGED_MODELS=$(git diff --name-only HEAD 2>/dev/null | grep -E 'models/.*\.sql$' | sed 's|.*/||;s|\.sql$||' | sort -u)

if [ -z "$CHANGED_MODELS" ]; then
    exit 0
fi

MISSING=""
for model in $CHANGED_MODELS; do
    # Search for the model name in any schema.yml / .yml file under models/
    if ! grep -rq "name: $model" "$CWD/models/" --include="*.yml" 2>/dev/null; then
        MISSING="$MISSING  - $model\n"
    fi
done

if [ -n "$MISSING" ]; then
    cat <<EOF
{
  "continue": false,
  "stopReason": "Missing schema.yml entries for new/changed models:\n${MISSING}\nEvery model MUST have a schema.yml entry with:\n  - description (what does this model do?)\n  - column descriptions (what does each column mean?)\n  - tests (at minimum: not_null and unique on primary key)\n\nCreate or update the appropriate schema.yml file under models/."
}
EOF
    exit 0
fi

exit 0
