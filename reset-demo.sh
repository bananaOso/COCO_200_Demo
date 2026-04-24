#!/bin/bash
echo "=== Resetting Demo Environment ==="

cd "$(dirname "$0")"

git checkout main 2>/dev/null
for branch in $(git branch | grep 'feature/'); do
    git branch -D $(echo $branch | tr -d ' ') 2>/dev/null
done
echo "[OK] Git branches cleaned"

git checkout -- . 2>/dev/null
git clean -fd 2>/dev/null
echo "[OK] Working directory restored"

rm -rf target/ dbt_packages/ logs/ 2>/dev/null
echo "[OK] dbt artifacts removed"

if [ -f AGENTS.md.bak ]; then
    mv AGENTS.md.bak AGENTS.md
fi
echo "[OK] AGENTS.md restored"

if [ -f ~/.snowflake/cortex/hooks.json.bak ]; then
    cp ~/.snowflake/cortex/hooks.json.bak ~/.snowflake/cortex/hooks.json
fi
echo "[OK] Hooks restored"

echo ""
echo "=== Demo Reset Complete ==="
echo "To start a demo scenario, see DEMO_GUIDE.md"
