# Shared helpers for sync-mailbox scripts. Source this file; do not execute it.

# sync_load_config <project_dir>
# Reads <project_dir>/.claude/sync-mailbox.env (KEY=value lines, # comments).
# On success exports SYNC_MAILBOX_REPO, SYNC_MAILBOX_ROLE, SYNC_MAILBOX_PROVIDER
# (github|gitlab, default github) and SYNC_MAILBOX_HOST (gitlab only, default
# gitlab.com; empty for github) and returns 0.
# Returns 1 and sets nothing when the file is missing, a key is empty, or the
# provider is unknown.
sync_load_config() {
  local file="$1/.claude/sync-mailbox.env" line key value repo="" role="" provider="github" host=""
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
      SYNC_MAILBOX_PROVIDER) [ -n "$value" ] && provider="$value";;
      SYNC_MAILBOX_HOST) host="$value";;
    esac
  done < "$file"
  [ -n "$repo" ] && [ -n "$role" ] || return 1
  case "$provider" in
    github) host="";;
    gitlab) [ -n "$host" ] || host="gitlab.com";;
    *) return 1;;
  esac
  export SYNC_MAILBOX_REPO="$repo" SYNC_MAILBOX_ROLE="$role"
  export SYNC_MAILBOX_PROVIDER="$provider" SYNC_MAILBOX_HOST="$host"
}
