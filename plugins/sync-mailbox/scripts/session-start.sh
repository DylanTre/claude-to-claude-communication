#!/usr/bin/env bash
# SessionStart hook: tells Claude when the sync mailbox has items waiting.
# Silent when the project has no mailbox config or the inbox is empty.
# Never fails the session: always exits 0.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

sync_load_config "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
case "$SYNC_MAILBOX_REPO$SYNC_MAILBOX_ROLE" in *'"'*|*'\'*) exit 0;; esac

if ! items="$(bash "$here/inbox.sh" "$SYNC_MAILBOX_REPO" "$SYNC_MAILBOX_ROLE" 2>/dev/null)"; then
  echo "Sync mailbox: could not reach GitHub via gh (offline or not logged in?). Run /sync-setup to check."
  exit 0
fi
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
msg="Sync mailbox ($SYNC_MAILBOX_REPO, role $SYNC_MAILBOX_ROLE): $summary. Tell the user briefly and offer /sync-inbox."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
