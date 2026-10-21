#!/usr/bin/env bash
# SessionStart hook: tells Claude when the sync mailbox has items waiting.
# Silent when the project has no mailbox config or the inbox is empty.
# Never fails the session: always exits 0.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

project="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$project/.claude/sync-mailbox.env" ] || exit 0

invalid_config() {
  echo "Sync mailbox: .claude/sync-mailbox.env is invalid (needs SYNC_MAILBOX_REPO=owner/name and a SYNC_MAILBOX_ROLE slug). Run /sync-setup to fix."
  exit 0
}
sync_load_config "$project" || invalid_config
case "$SYNC_MAILBOX_REPO$SYNC_MAILBOX_ROLE$SYNC_MAILBOX_HOST" in *'"'*|*'\'*) invalid_config;; esac
case "$SYNC_MAILBOX_ROLE" in *[!A-Za-z0-9_-]*) invalid_config;; esac

if ! items="$(bash "$here/inbox.sh" "$SYNC_MAILBOX_REPO" "$SYNC_MAILBOX_ROLE" "$SYNC_MAILBOX_PROVIDER" "$SYNC_MAILBOX_HOST" 2>/dev/null)"; then
  if [ "$SYNC_MAILBOX_PROVIDER" = gitlab ]; then
    echo "Sync mailbox: could not reach GitLab ($SYNC_MAILBOX_HOST) via glab (offline, VPN, or not logged in?). Run /sync-setup to check."
  else
    echo "Sync mailbox: could not reach GitHub via gh (offline or not logged in?). Run /sync-setup to check."
  fi
  exit 0
fi
where="$SYNC_MAILBOX_REPO"
[ "$SYNC_MAILBOX_PROVIDER" = gitlab ] && where="$SYNC_MAILBOX_HOST/$SYNC_MAILBOX_REPO"
[ -n "$items" ] || exit 0

# numbers_for <kind>: "#3, #7" for items of that kind
numbers_for() { printf '%s\n' "$items" | awk -F'\t' -v k="$1" '$2 == k { printf "%s#%s", (n++ ? ", " : ""), $1 }'; }

parts=()
for spec in "answer|to answer" "review|answers to review" "followup|follow-ups from the other side"; do
  kind="${spec%%|*}"; label="${spec#*|}"
  nums="$(numbers_for "$kind")"
  [ -n "$nums" ] || continue
  count="$(printf '%s' "$nums" | awk -F', ' '{print NF}')"
  parts+=("$count $label [$nums]")
done

summary="$(IFS='|'; printf '%s' "${parts[*]}")"
summary="${summary//|/, }"
msg="Sync mailbox ($where, role $SYNC_MAILBOX_ROLE): $summary. Tell the user briefly and offer /sync-inbox."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
