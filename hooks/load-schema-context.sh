#!/bin/bash
# ============================================================
# Hook 4: Schema & dbt Docs Loader (SessionStart)
# Fires when a Cortex Code session begins.
# Automatically loads database schemas and dbt documentation
# into the agent's context, preventing table name hallucinations.
#
# Outputs to stdout — content is injected into the agent context.
# Matcher: (none — SessionStart hooks don't use matchers)
# ============================================================

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi

OUTPUT=""

# ---------------------------------------------------------
# 1. Load dbt manifest (table names, descriptions, columns)
# ---------------------------------------------------------
DBT_PROJECT=""
SEARCH="$CWD"
while [ "$SEARCH" != "/" ]; do
  if [ -f "$SEARCH/dbt_project.yml" ]; then
    DBT_PROJECT="$SEARCH"
    break
  fi
  SEARCH=$(dirname "$SEARCH")
done

if [ -n "$DBT_PROJECT" ]; then
  MANIFEST="$DBT_PROJECT/target/manifest.json"
  CATALOG="$DBT_PROJECT/target/catalog.json"

  if [ -f "$MANIFEST" ]; then
    MODEL_SUMMARY=$(jq -r '
      .nodes | to_entries[]
      | select(.value.resource_type == "model")
      | "\(.value.schema).\(.value.name): \(.value.description // "no description") | columns: \([.value.columns | to_entries[].value.name] | join(", "))"
    ' "$MANIFEST" 2>/dev/null | head -100)

    if [ -n "$MODEL_SUMMARY" ]; then
      OUTPUT="${OUTPUT}
## dbt Models (from manifest.json)
These are the ONLY valid model names in this project. Do NOT hallucinate table names.

\`\`\`
${MODEL_SUMMARY}
\`\`\`
"
    fi

    SOURCE_SUMMARY=$(jq -r '
      .sources | to_entries[]
      | "\(.value.schema).\(.value.name) (source: \(.value.source_name)): \(.value.description // "no description") | columns: \([.value.columns | to_entries[].value.name] | join(", "))"
    ' "$MANIFEST" 2>/dev/null | head -50)

    if [ -n "$SOURCE_SUMMARY" ]; then
      OUTPUT="${OUTPUT}
## dbt Sources
These are the upstream source tables. Reference them using \`{{ source('name', 'table') }}\` syntax.

\`\`\`
${SOURCE_SUMMARY}
\`\`\`
"
    fi
  else
    OUTPUT="${OUTPUT}
## dbt Project Detected (no manifest)
A dbt project exists at: ${DBT_PROJECT}
No compiled manifest found. Run 'dbt compile' or 'dbt docs generate' to populate target/manifest.json.
"
  fi

  # ---------------------------------------------------
  # 2. Load dbt schema YAML files (model definitions)
  # ---------------------------------------------------
  SCHEMA_FILES=$(find "$DBT_PROJECT/models" -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -20)
  if [ -n "$SCHEMA_FILES" ]; then
    SCHEMA_MODELS=""
    for f in $SCHEMA_FILES; do
      MODELS_IN_FILE=$(grep -E '^\s+- name:' "$f" 2>/dev/null | sed 's/.*- name:\s*//' | tr '\n' ', ')
      if [ -n "$MODELS_IN_FILE" ]; then
        SCHEMA_MODELS="${SCHEMA_MODELS}  $(basename "$f"): ${MODELS_IN_FILE}\n"
      fi
    done
    if [ -n "$SCHEMA_MODELS" ]; then
      OUTPUT="${OUTPUT}
## dbt Schema Files
$(echo -e "$SCHEMA_MODELS")
"
    fi
  fi
fi

# ---------------------------------------------------------
# 3. Load Snowflake schema context via snow CLI or SQL
# ---------------------------------------------------------
SNOWFLAKE_CONTEXT=""

if command -v snow > /dev/null 2>&1; then
  DB_SCHEMA=$(snow sql -q "SELECT CURRENT_DATABASE() || '.' || CURRENT_SCHEMA()" --format json 2>/dev/null | jq -r '.[0][]' 2>/dev/null)
  
  if [ -n "$DB_SCHEMA" ]; then
    TABLES=$(snow sql -q "SHOW TABLES IN SCHEMA" --format json 2>/dev/null | jq -r '.[] | "\(.name) (\(.kind // "TABLE"), \(.rows // "?") rows)"' 2>/dev/null | head -50)
    VIEWS=$(snow sql -q "SHOW VIEWS IN SCHEMA" --format json 2>/dev/null | jq -r '.[] | .name' 2>/dev/null | head -50)

    if [ -n "$TABLES" ] || [ -n "$VIEWS" ]; then
      SNOWFLAKE_CONTEXT="
## Snowflake Objects in ${DB_SCHEMA}
These are the actual tables and views available. Use ONLY these names.

### Tables
\`\`\`
${TABLES:-No tables found}
\`\`\`

### Views
\`\`\`
${VIEWS:-No views found}
\`\`\`
"
    fi
  fi
fi

if [ -n "$SNOWFLAKE_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${SNOWFLAKE_CONTEXT}"
fi

# ---------------------------------------------------------
# 4. Load any project-level context file
# ---------------------------------------------------------
if [ -f "$CWD/.cortex/context.md" ]; then
  CONTEXT_CONTENT=$(head -100 "$CWD/.cortex/context.md")
  OUTPUT="${OUTPUT}
## Project Context (.cortex/context.md)
${CONTEXT_CONTENT}
"
fi

# ---------------------------------------------------------
# Output to agent
# ---------------------------------------------------------
if [ -n "$OUTPUT" ]; then
  echo "# Auto-loaded Project Context (SessionStart Hook)"
  echo "The following schemas, tables, and model definitions were loaded automatically."
  echo "Use ONLY these object names. Do NOT guess or hallucinate table/column names."
  echo ""
  echo "$OUTPUT"
fi

exit 0
