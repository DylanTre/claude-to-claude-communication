# Shared helpers for sync-mailbox scripts. Source this file; do not execute it.

# sync_load_config <project_dir>
# Reads <project_dir>/.claude/sync-mailbox.env (KEY=value lines, # comments).
# On success exports SYNC_MAILBOX_REPO and SYNC_MAILBOX_ROLE and returns 0.
# Returns 1 and sets nothing when the file is missing or a key is empty.
sync_load_config() {
  local file="$1/.claude/sync-mailbox.env" line key value repo="" role=""
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    case "$line" in ''|'#'*) continue;; *=*) ;; *) continue;; esac
    key="${line%%=*}"; value="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    key="${key#export}"
    value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$value" in \"*\"|\'*\') value="${value:1:${#value}-2}";; esac
    case "$key" in
      SYNC_MAILBOX_REPO) repo="$value";;
      SYNC_MAILBOX_ROLE) role="$value";;
    esac
  done < "$file"
  [ -n "$repo" ] && [ -n "$role" ] || return 1
  export SYNC_MAILBOX_REPO="$repo" SYNC_MAILBOX_ROLE="$role"
}
