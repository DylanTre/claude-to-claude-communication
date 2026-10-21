#!/usr/bin/env bash
# PreToolUse hook (Bash): forces a permission prompt for any gh write that
# targets the mailbox repo, whatever the user's allow-list or permission mode.
# Matches against the raw hook JSON, so it needs no JSON parser. Always exits 0.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

sync_load_config "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
input="$(cat | tr '[:upper:]' '[:lower:]')"
repo="$(printf '%s' "$SYNC_MAILBOX_REPO" | tr '[:upper:]' '[:lower:]')"

printf '%s' "$input" | grep -qF -- "$repo" || exit 0
printf '%s' "$input" | grep -qE 'gh[[:space:]]+(issue[[:space:]]+(create|comment|edit|close|reopen|delete|transfer|lock|unlock|pin|unpin)|label[[:space:]]+(create|edit|delete|clone)|api)' || exit 0

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"sync-mailbox: posting to the shared mailbox needs your explicit approval"}}'
exit 0
