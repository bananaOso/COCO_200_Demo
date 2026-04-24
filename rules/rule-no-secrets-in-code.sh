#!/bin/bash
# rule-no-secrets-in-code.sh
# PreToolUse hook — Blocks writes containing secrets, API keys, or credentials
#
# Why: Secrets in source code end up in git history permanently.
# Even if removed later, they're recoverable from past commits.
# Use environment variables, Snowflake connections.toml, or a secrets manager.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.code // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip known safe files
if [ -n "$FILE" ]; then
    case "$FILE" in
        *.md|*.txt|*.pptx|*.png|*.jpg)
            exit 0
            ;;
    esac
fi

check_secrets() {
    local text="$1"

    # Common secret patterns
    PATTERNS=(
        '[A-Za-z0-9]{20,}["\x27]\s*#?\s*(secret|key|token|password)'
        'AKIA[0-9A-Z]{16}'                    # AWS Access Key
        'sk-[a-zA-Z0-9]{20,}'                 # OpenAI / Stripe secret key
        'ghp_[a-zA-Z0-9]{36}'                 # GitHub personal access token
        'xoxb-[0-9]{11}-[0-9]{11}-'           # Slack bot token
        'password\s*=\s*["\x27][^"\x27]{4,}'  # password = "..."
        'api_key\s*=\s*["\x27][^"\x27]{4,}'   # api_key = "..."
        'secret\s*=\s*["\x27][^"\x27]{4,}'    # secret = "..."
        'token\s*=\s*["\x27][^"\x27]{4,}'     # token = "..."
        'BEGIN\s+(RSA\s+)?PRIVATE\s+KEY'       # Private key blocks
    )

    for pattern in "${PATTERNS[@]}"; do
        if echo "$text" | grep -qiE "$pattern"; then
            echo "BLOCKED: Potential secret or credential detected." >&2
            echo "" >&2
            echo "Do NOT hardcode secrets in source code. Instead:" >&2
            echo "  - Use environment variables: os.getenv('MY_API_KEY')" >&2
            echo "  - Use Snowflake connections.toml for DB credentials" >&2
            echo "  - Use a secrets manager (AWS SSM, Vault, etc.)" >&2
            echo "" >&2
            echo "Why: Secrets in code end up in git history permanently," >&2
            echo "even after deletion. This is a security incident." >&2
            exit 2
        fi
    done
}

case "$TOOL" in
    Write|Edit)
        [ -n "$CONTENT" ] && check_secrets "$CONTENT"
        ;;
esac

exit 0
