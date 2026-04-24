#!/bin/bash
# ============================================================
# Hook 2: Push-to-Main Blocker (PreToolUse)
# Blocks any git push targeting main/master.
# All changes to main must go through a pull request.
# Catches: git push origin main, git push --force main,
#          git push -f origin main, git push --force-with-lease, etc.
#
# Matcher: Bash
# Exit 0 = allow, Exit 2 = block
# ============================================================

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

if ! echo "$CMD" | grep -qE 'git\s+push'; then
  exit 0
fi

if echo "$CMD" | grep -qE '\-\-force|\-f\b|\-\-force-with-lease'; then
  if echo "$CMD" | grep -qE '\b(main|master)\b'; then
    echo "BLOCKED: 'git push --force' to main/master is never allowed." >&2
    echo "This is a destructive operation that rewrites shared history." >&2
    echo "All changes to main must go through a pull request." >&2
    exit 2
  fi

  echo "WARNING: Force pushing to a feature branch. Proceed with caution." >&2
  exit 0
fi

if echo "$CMD" | grep -qE 'git\s+push\s+\S+\s+(main|master)\b'; then
  echo "BLOCKED: Cannot push directly to main/master." >&2
  echo "All changes to main must go through a pull request:" >&2
  echo "  git push origin $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'your-feature-branch')" >&2
  echo "  gh pr create --base main" >&2
  exit 2
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  if echo "$CMD" | grep -qE 'git\s+push\s*$' || echo "$CMD" | grep -qE 'git\s+push\s+origin\s*$'; then
    echo "BLOCKED: Cannot push from main/master." >&2
    echo "You are on '$BRANCH'. All changes to main must go through a pull request:" >&2
    echo "  git checkout -b feature/your-change-name" >&2
    echo "  git push origin feature/your-change-name" >&2
    echo "  gh pr create --base main" >&2
    exit 2
  fi
fi

exit 0
