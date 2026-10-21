#!/usr/bin/env bash
# PreToolUse hook (Bash): forces a permission prompt for any gh write that
# targets the mailbox repo, whatever the user's allow-list or permission mode.
# Matches text in the raw hook JSON, so it needs no JSON parser. Errs towards
# asking: a gh command naming the repo asks if a write verb appears anywhere in
# it, regardless of flag order. Always exits 0.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

sync_load_config "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
input="$(cat)"
# Only the command matters (not e.g. the description); fall back to everything.
command="$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"')"
[ -n "$command" ] || command="$input"
# Turn JSON escapes (\n, \t, \r: line continuations, tabs) into spaces.
command="$(printf '%s' "$command" | sed 's/\\[ntr]/ /g' | tr '[:upper:]' '[:lower:]')"
repo="$(printf '%s' "$SYNC_MAILBOX_REPO" | tr '[:upper:]' '[:lower:]')"

printf '%s' "$command" | grep -qF -- "$repo" || exit 0
printf '%s' "$command" | grep -qE '(^|[^a-z0-9_.-])gh(\.exe)?[[:space:]]' || exit 0
printf '%s' "$command" | grep -qwE 'create|comment|edit|close|reopen|delete|transfer|lock|unlock|pin|unpin|develop|clone|api|archive|unarchive|rename' || exit 0

echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"sync-mailbox: posting to the shared mailbox needs your explicit approval"}}'
exit 0
