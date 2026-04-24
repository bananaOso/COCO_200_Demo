# Cortex Code Hooks Demo Guide

**Repo:** `https://github.com/bananaOso/COCO_200_Demo.git`
**Source Data:** `DBT_TASTY_BYTES.RAW_DBT` (8 tables: COUNTRY, CUSTOMER_LOYALTY, FRANCHISE, LOCATION, MENU, ORDER_DETAIL, ORDER_HEADER, TRUCK)

This demo showcases how hooks and rules transform vibe coding into agentic development using a real dbt + Snowflake pipeline built on the Tasty Bytes food truck dataset.

---

## Prerequisites

### Software
- Cortex Code CLI installed (`cortex` or via Snowflake VS Code extension)
- dbt-core + dbt-snowflake (`pip install dbt-core dbt-snowflake`)
- jq (`brew install jq`)
- git
- GitHub CLI (`gh`) — optional, for PR creation demos

### Snowflake
- Access to `DBT_TASTY_BYTES.RAW_DBT` schema
- A database for dbt output (e.g., `COCO_DEMO_DB`) — the setup script creates this
- A warehouse (e.g., `COMPUTE_WH`)

### dbt Profile
Ensure `~/.dbt/profiles.yml` has a profile named `coco_demo` (or update `dbt_project.yml` to match your existing profile):
```yaml
coco_demo:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: <your_user>
      authenticator: externalbrowser   # or password, keypair, etc.
      role: ACCOUNTADMIN               # or your dbt role
      database: COCO_DEMO_DB
      warehouse: COMPUTE_WH
      schema: DBT_DEV
      threads: 4
```

---

## Initial Setup (Run Once)

### 1. Create the Snowflake target database
```sql
CREATE DATABASE IF NOT EXISTS COCO_DEMO_DB;
CREATE SCHEMA IF NOT EXISTS COCO_DEMO_DB.DBT_DEV;
```

### 2. Clone and initialize the repo
```bash
git clone https://github.com/bananaOso/COCO_200_Demo.git
cd COCO_200_Demo
```

### 3. Initialize the dbt project
```bash
dbt init tasty_bytes_pipeline --skip-profile-setup
# Or manually create the structure:
```

Create the dbt project structure:
```
COCO_200_Demo/
├── AGENTS.md                      # <-- Rules for agents
├── DEMO_GUIDE.md                  # <-- This file
├── dbt_project.yml
├── hooks/
│   ├── hooks.json                 # <-- Hook wiring config
│   ├── feature-branch-enforcer.sh
│   ├── block-push-to-main.sh
│   ├── dbt-test-on-stop.sh
│   └── load-schema-context.sh
├── rules/
│   ├── rule-no-hardcoded-tables.sh
│   ├── rule-no-select-star.sh
│   ├── rule-staging-layer-purity.sh
│   ├── rule-no-secrets-in-code.sh
│   ├── rule-block-destructive-sql.sh
│   └── rule-require-schema-yml.sh
├── models/
│   ├── staging/
│   │   ├── _sources.yml
│   │   ├── stg_tasty_bytes__orders.sql
│   │   ├── stg_tasty_bytes__customers.sql
│   │   ├── stg_tasty_bytes__menu.sql
│   │   ├── stg_tasty_bytes__trucks.sql
│   │   └── stg_tasty_bytes__locations.sql
│   ├── intermediate/
│   │   └── (agent builds these during demo)
│   └── marts/
│       └── (agent builds these during demo)
└── packages.yml
```

### 4. Install hooks for Cortex Code
Copy the hooks.json to your Cortex Code config:
```bash
cp hooks/hooks.json ~/.snowflake/cortex/hooks.json
```

Or for project-level hooks, place in `.cortex/hooks.json`.

### 5. Verify dbt connection
```bash
dbt debug
```

---

## Seed Files for the Demo

### dbt_project.yml
```yaml
name: 'tasty_bytes_pipeline'
version: '1.0.0'
config-version: 2

profile: 'coco_demo'

model-paths: ["models"]
test-paths: ["tests"]
macro-paths: ["macros"]
seed-paths: ["seeds"]

clean-targets:
  - "target"
  - "dbt_packages"
```

### models/staging/_sources.yml
```yaml
version: 2

sources:
  - name: tasty_bytes
    database: DBT_TASTY_BYTES
    schema: RAW_DBT
    tables:
      - name: ORDER_HEADER
        description: "Raw order headers from Tasty Bytes food trucks"
        columns:
          - name: ORDER_ID
            description: "Unique order identifier"
            tests:
              - unique
              - not_null
      - name: ORDER_DETAIL
        description: "Line-level order details"
        columns:
          - name: ORDER_DETAIL_ID
            tests:
              - unique
              - not_null
      - name: CUSTOMER_LOYALTY
        description: "Customer loyalty program data"
        columns:
          - name: CUSTOMER_ID
            tests:
              - unique
              - not_null
      - name: MENU
        description: "Food truck menu items and pricing"
        columns:
          - name: MENU_ITEM_ID
            tests:
              - not_null
      - name: TRUCK
        description: "Food truck fleet information"
        columns:
          - name: TRUCK_ID
            tests:
              - unique
              - not_null
      - name: FRANCHISE
        description: "Franchise owner details"
      - name: LOCATION
        description: "Truck serving locations"
        columns:
          - name: LOCATION_ID
            tests:
              - unique
              - not_null
      - name: COUNTRY
        description: "Country and city reference data"
```

### models/staging/stg_tasty_bytes__orders.sql
```sql
with source as (
    select * from {{ source('tasty_bytes', 'ORDER_HEADER') }}
),

renamed as (
    select
        order_id,
        truck_id,
        location_id::int as location_id,
        customer_id,
        shift_id,
        order_channel,
        order_ts,
        order_currency,
        order_amount,
        order_total
    from source
)

select * from renamed
```

### AGENTS.md (place at project root)
```markdown
# Tasty Bytes dbt Pipeline

dbt 1.9, Snowflake, sqlfluff. Source: DBT_TASTY_BYTES.RAW_DBT.

## Commands
- `dbt build --select state:modified+`: Build changed models
- `dbt test --select <model>`: Test one model
- `dbt compile --select <model>`: Check SQL compiles
- `sqlfluff lint models/`: Lint SQL

## Architecture
- models/staging/        1:1 with source, rename + cast only
- models/intermediate/   Joins and business logic
- models/marts/          Final tables for BI

## Rules — CRITICAL
- ALWAYS use {{ ref('model') }} and {{ source('tasty_bytes', 'TABLE') }}
  Never hardcode DBT_TASTY_BYTES.RAW_DBT.table_name
- ALWAYS use explicit column lists, never SELECT *
- Every model MUST have a schema.yml with description + tests
- Staging models: ONLY rename, cast, filter. NO joins, NO GROUP BY
- Intermediate: where joins happen
- Marts: aggregations and final metrics
- NEVER modify models/staging/ once created — build on top of them
- Run sqlfluff fix before committing

## Naming Conventions
- Staging: stg_tasty_bytes__<table>.sql
- Intermediate: int_<entity>__<verb>.sql
- Facts: fct_<entity>.sql
- Dimensions: dim_<entity>.sql

## Source Tables (DBT_TASTY_BYTES.RAW_DBT)
- ORDER_HEADER: order_id, truck_id, location_id, customer_id, order_ts, order_amount, order_total
- ORDER_DETAIL: order_detail_id, order_id, menu_item_id, quantity, unit_price, price
- CUSTOMER_LOYALTY: customer_id, first_name, last_name, city, country, sign_up_date, e_mail
- MENU: menu_id, menu_type, truck_brand_name, menu_item_name, item_category, cost_of_goods_usd, sale_price_usd
- TRUCK: truck_id, primary_city, region, country, make, model, franchise_id, truck_opening_date
- FRANCHISE: franchise_id, first_name, last_name, city, country
- LOCATION: location_id, location, city, region, country
- COUNTRY: country_id, country, iso_currency, city, city_population

## Git Workflow
- Feature branches only: feature/<description>
- All changes via PR to main
```

---

## Demo Scenarios

Each scenario demonstrates a specific hook in action. Run them in order for the best narrative flow — they tell the story of going from vibe coding to agentic development.

---

### SCENARIO 1: "Vibe Coding" Baseline (No Hooks)

**Purpose:** Show what happens without guardrails — the agent vibe codes freely.

**Setup:** Temporarily disable hooks:
```bash
# Back up hooks
cp ~/.snowflake/cortex/hooks.json ~/.snowflake/cortex/hooks.json.bak
# Remove hooks
rm ~/.snowflake/cortex/hooks.json
# Also remove AGENTS.md temporarily
mv AGENTS.md AGENTS.md.bak
```

**Demo Steps:**
1. Open Cortex Code in the project directory
2. Prompt: `"Create a dbt model that shows total revenue by truck brand"`
3. **Watch what happens WITHOUT hooks/rules:**
   - Agent likely writes `SELECT * FROM DBT_TASTY_BYTES.RAW_DBT.ORDER_HEADER` (hardcoded)
   - May put JOINs directly in a staging model
   - May skip schema.yml and tests entirely
   - May name the file incorrectly (not following conventions)
   - May try to run `dbt build` on main branch
4. **Point out to the audience:** "This is vibe coding. It works, but it breaks lineage, skips tests, and isn't maintainable."

**Undo:**
```bash
# Restore hooks and AGENTS.md
mv AGENTS.md.bak AGENTS.md
cp ~/.snowflake/cortex/hooks.json.bak ~/.snowflake/cortex/hooks.json
# Delete any files the agent created
git checkout -- .
git clean -fd
```

---

### SCENARIO 2: Feature Branch Enforcer

**Purpose:** Show that the agent can't run dbt on main — must create a feature branch first.

**Hook:** `hooks/feature-branch-enforcer.sh` (PreToolUse → Bash)

**Setup:** Make sure you're on main:
```bash
git checkout main
```

**Demo Steps:**
1. Open Cortex Code
2. Prompt: `"Run dbt build to test the staging models"`
3. **The hook fires and BLOCKS the command:**
   ```
   BLOCKED: Cannot run dbt commands on 'main'.
   Create a feature branch first:
     git checkout -b feature/your-change-name
   ```
4. **Watch the agent self-correct:** It reads the error, creates a feature branch, and retries.
5. **Talking point:** "Same branch protection policy your team already has — now enforced for AI."

**Undo:**
```bash
git checkout main
git branch -D feature/your-change-name 2>/dev/null
```

---

### SCENARIO 3: Push-to-Main Blocker

**Purpose:** Show that the agent can't push directly to main — must use a PR.

**Hook:** `hooks/block-push-to-main.sh` (PreToolUse → Bash)

**Demo Steps:**
1. Create a feature branch with a small change:
   ```bash
   git checkout -b feature/demo-push-test
   echo "-- test" >> models/staging/stg_tasty_bytes__orders.sql
   git add . && git commit -m "test change"
   ```
2. Prompt: `"Push this change to main and deploy it"`
3. **The hook fires and BLOCKS:**
   ```
   BLOCKED: Cannot push directly to main/master.
   All changes to main must go through a pull request:
     git push origin feature/demo-push-test
     gh pr create --base main
   ```
4. **Watch the agent self-correct:** Pushes to the feature branch and creates a PR instead.
5. **Talking point:** "GitHub branch protection catches the push server-side AFTER the attempt. This hook catches it BEFORE — the agent never even tries."

**Undo:**
```bash
git checkout main
git branch -D feature/demo-push-test 2>/dev/null
git checkout -- models/staging/stg_tasty_bytes__orders.sql
```

---

### SCENARIO 4: The Agent Builds a Real Pipeline (With Hooks Active)

**Purpose:** The main demo — the agent builds intermediate + marts models with all hooks enforcing quality.

**Hook:** All hooks active together.

**Setup:**
```bash
# Make sure hooks are installed
cp hooks/hooks.json ~/.snowflake/cortex/hooks.json
# Start on a feature branch
git checkout main
git checkout -b feature/revenue-pipeline
```

**Demo Steps:**
1. Prompt the agent:
   ```
   Build a dbt pipeline for Tasty Bytes revenue analytics:
   1. Create an intermediate model int_orders__enriched that joins orders with menu items and trucks
   2. Create a marts model fct_daily_revenue that aggregates daily revenue by truck brand and city
   3. Create a dimension model dim_customers from the customer loyalty data
   4. Add schema.yml files with descriptions and tests for all new models
   5. Run dbt build to verify everything works
   ```

2. **Watch the hooks in action:**

   **a) Feature Branch Enforcer** — If the agent somehow tries `dbt build` before branching, it gets blocked and auto-corrects.

   **b) AGENTS.md Rules** — The agent reads AGENTS.md and:
   - Uses `{{ ref('stg_tasty_bytes__orders') }}` instead of hardcoded tables
   - Names files correctly: `int_orders__enriched.sql`, `fct_daily_revenue.sql`, `dim_customers.sql`
   - Keeps staging models thin (no joins in staging)
   - Creates schema.yml alongside every model

   **c) dbt Test-and-Fix Loop (Stop hook)** — When the agent tries to finish:
   - The Stop hook runs `dbt build --select` on changed models
   - If any test fails, the agent gets blocked with the error
   - Agent reads the failure, fixes the model, and retries
   - This loops until ALL tests pass
   - **This is the money shot** — the agent literally cannot say "done" until it proves the code works

3. **Talking point:** "Same prompt, same agent, completely different outcome. The hooks enforce feature branches, correct naming, proper testing, and the agent can't finish until tests pass. That's agentic development."

**Expected Models Created:**
```
models/
├── staging/
│   ├── _sources.yml           (pre-created)
│   └── stg_tasty_bytes__orders.sql   (pre-created)
├── intermediate/
│   ├── int_orders__enriched.sql      (joins orders + menu + trucks)
│   └── schema.yml
└── marts/
    ├── fct_daily_revenue.sql         (daily revenue by brand/city)
    ├── dim_customers.sql             (customer dimension)
    └── schema.yml
```

**Undo:**
```bash
git checkout main
git branch -D feature/revenue-pipeline 2>/dev/null
git checkout -- .
git clean -fd
# Drop any dbt-created objects in Snowflake:
# snow sql -q "DROP SCHEMA IF EXISTS COCO_DEMO_DB.DBT_DEV CASCADE;"
# snow sql -q "CREATE SCHEMA COCO_DEMO_DB.DBT_DEV;"
```

---

### SCENARIO 5: Rule Hooks — Hardcoded Tables + SELECT *

**Purpose:** Show the rule hooks catching specific anti-patterns in real time.

**Hooks:** `rules/rule-no-hardcoded-tables.sh`, `rules/rule-no-select-star.sh` (PreToolUse → Write|Edit)

**Setup:** Add rule hooks to your hooks.json (or use the rules/hooks.json):
```bash
# Merge the rule hooks into your hooks config
# Or replace: cp rules/hooks.json ~/.snowflake/cortex/hooks.json
```

**Demo Steps:**
1. Start on a feature branch:
   ```bash
   git checkout -b feature/rule-demo
   ```

2. Prompt: `"Create a quick model that shows all orders from the ORDER_HEADER table in DBT_TASTY_BYTES.RAW_DBT"`

3. **Watch rule hooks fire:**
   - If the agent writes `SELECT * FROM DBT_TASTY_BYTES.RAW_DBT.ORDER_HEADER`:
     - `rule-no-select-star.sh` blocks: "BLOCKED: SELECT * detected. Use explicit column lists."
     - `rule-no-hardcoded-tables.sh` blocks: "BLOCKED: Hardcoded table reference. Use {{ ref() }} or {{ source() }}."
   - Agent self-corrects to use `{{ source('tasty_bytes', 'ORDER_HEADER') }}` with explicit columns

4. **Talking point:** "The agent wrote the code it thought was right. The hook caught it before it ever hit disk. The agent read the error, understood the convention, and fixed it — all in one turn."

**Undo:**
```bash
git checkout main
git branch -D feature/rule-demo 2>/dev/null
git checkout -- .
git clean -fd
```

---

### SCENARIO 6: Staging Layer Purity

**Purpose:** Show the agent being blocked from putting joins in a staging model.

**Hook:** `rules/rule-staging-layer-purity.sh` (PreToolUse → Write|Edit)

**Demo Steps:**
1. Start on a feature branch:
   ```bash
   git checkout -b feature/staging-purity-demo
   ```

2. Prompt: `"Create a staging model stg_tasty_bytes__order_details that joins ORDER_DETAIL with MENU to get item names and prices"`

3. **Watch the hook fire:**
   ```
   BLOCKED: JOIN detected in a staging model.
   Staging models must NOT contain joins.
   Move join logic to an intermediate model:
     models/intermediate/int_<entity>__<verb>.sql
   Staging = rename, cast, filter ONLY.
   ```

4. **Watch the agent self-correct:** Creates:
   - `stg_tasty_bytes__order_details.sql` (thin: just rename/cast from ORDER_DETAIL)
   - `int_order_details__enriched.sql` (the join with MENU happens here)

5. **Talking point:** "The agent tried to be helpful and put everything in one model. The hook enforced our architecture — staging is thin, joins happen in intermediate. The agent learned the pattern."

**Undo:**
```bash
git checkout main
git branch -D feature/staging-purity-demo 2>/dev/null
git checkout -- .
git clean -fd
```

---

### SCENARIO 7: Destructive SQL Blocker

**Purpose:** Quick, dramatic demo — agent tries to DROP TABLE and gets blocked.

**Hook:** `rules/rule-block-destructive-sql.sh` (PreToolUse → Bash)

**Demo Steps:**
1. Prompt: `"Drop the old stg_orders table from Snowflake, it's been replaced"`

2. **Hook fires immediately:**
   ```
   BLOCKED: DROP statement detected.
   Destructive DDL is not allowed via agent.
   If you need to drop an object:
     1. Add it to a migration script in /migrations/
     2. Have a human review and execute it
   For development, use CREATE OR REPLACE instead.
   ```

3. **Talking point:** "Five lines of bash just prevented a production incident. The agent can create, build, and test — but it can't destroy. That's the guardrail."

**Undo:** Nothing to undo — the command was blocked before execution.

---

## Complete Reset Procedure

Run this to completely reset the demo environment back to its starting state:

```bash
#!/bin/bash
# reset-demo.sh — Run from the COCO_200_Demo directory

echo "=== Resetting Demo Environment ==="

# 1. Git: return to main branch, delete all feature branches
git checkout main 2>/dev/null
for branch in $(git branch | grep 'feature/'); do
    git branch -D $(echo $branch | tr -d ' ') 2>/dev/null
done
echo "[OK] Git branches cleaned"

# 2. Restore working directory
git checkout -- . 2>/dev/null
git clean -fd 2>/dev/null
echo "[OK] Working directory restored"

# 3. Remove dbt artifacts
rm -rf target/ dbt_packages/ logs/ 2>/dev/null
echo "[OK] dbt artifacts removed"

# 4. Restore AGENTS.md if backed up
if [ -f AGENTS.md.bak ]; then
    mv AGENTS.md.bak AGENTS.md
fi
echo "[OK] AGENTS.md restored"

# 5. Restore hooks if backed up
if [ -f ~/.snowflake/cortex/hooks.json.bak ]; then
    cp ~/.snowflake/cortex/hooks.json.bak ~/.snowflake/cortex/hooks.json
fi
echo "[OK] Hooks restored"

# 6. Optionally reset Snowflake schema (uncomment to use)
# snow sql -q "DROP SCHEMA IF EXISTS COCO_DEMO_DB.DBT_DEV CASCADE;"
# snow sql -q "CREATE SCHEMA COCO_DEMO_DB.DBT_DEV;"
# echo "[OK] Snowflake schema reset"

echo ""
echo "=== Demo Reset Complete ==="
echo "To start a demo scenario, see DEMO_GUIDE.md"
```

Save this as `reset-demo.sh` and run `chmod +x reset-demo.sh`.

---

## Demo Cheat Sheet (Quick Reference)

| # | Scenario | Hook | Event | What Happens | Time |
|---|----------|------|-------|-------------|------|
| 1 | Vibe Coding Baseline | None | — | Agent vibe codes freely, bad patterns | 3 min |
| 2 | Feature Branch Enforcer | `feature-branch-enforcer.sh` | PreToolUse | Agent blocked from dbt on main, self-corrects | 2 min |
| 3 | Push-to-Main Blocker | `block-push-to-main.sh` | PreToolUse | Agent blocked from push, creates PR instead | 2 min |
| 4 | Full Pipeline Build | All hooks + AGENTS.md | All | Agent builds pipeline, can't finish until tests pass | 8 min |
| 5 | Hardcoded Tables + SELECT * | Rule hooks | PreToolUse | Agent rewrites to ref() and explicit columns | 3 min |
| 6 | Staging Layer Purity | `rule-staging-layer-purity.sh` | PreToolUse | Agent splits model into staging + intermediate | 3 min |
| 7 | Destructive SQL Blocker | `rule-block-destructive-sql.sh` | PreToolUse | DROP TABLE blocked instantly | 1 min |

**Recommended demo flow for a 20-minute slot:** Scenarios 1 → 2 → 4 → 7

**Recommended demo flow for a 30-minute slot:** Scenarios 1 → 2 → 5 → 6 → 4 → 7

---

## Tips for a Smooth Demo

1. **Pre-warm dbt:** Run `dbt debug` and `dbt compile` before the demo to cache connections
2. **Pre-build staging:** Have the staging models already built in Snowflake so intermediate/marts demos are fast
3. **Use a small warehouse:** `COMPUTE_WH` (XS) is fine — staging tables are small except ORDER_HEADER (248M rows) and ORDER_DETAIL (673M rows)
4. **Consider filtering:** Add `WHERE order_ts >= '2022-01-01'` in staging models to reduce data volume for faster demo builds
5. **Have the reset script ready:** Run `./reset-demo.sh` between demos
6. **Keep a terminal with `git log --oneline` visible** to show the agent creating branches and commits
7. **Resize Cortex Code** to show both the chat and the file tree — audience can see files being created in real-time
