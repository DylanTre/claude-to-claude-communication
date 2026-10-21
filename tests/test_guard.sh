# Tests for scripts/guard-writes.sh (PreToolUse hook on Bash)

ASK='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"sync-mailbox: posting to the shared mailbox needs your explicit approval"}}'

# guard <command> : runs the hook with a Bash tool payload, config repo o/m
guard() {
  export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(mk_project)}"
  [ -f "$CLAUDE_PROJECT_DIR/.claude/sync-mailbox.env" ] || write_config "$CLAUDE_PROJECT_DIR" o/m impl
  local cmd="${1//\"/\\\"}"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" | bash "$PLUGIN_DIR/scripts/guard-writes.sh"
}

test_guard_comment() { assert_eq "$(guard 'gh issue comment 3 --repo o/m --body-file x.md')" "$ASK"; }
test_guard_create()  { assert_eq "$(guard 'gh issue create --repo o/m --title t --label for:spec')" "$ASK"; }
test_guard_close()   { assert_eq "$(guard 'gh issue close 3 -R o/m')" "$ASK"; }
test_guard_api()     { assert_eq "$(guard 'gh api repos/o/m/issues/3/comments -f body=x')" "$ASK"; }
test_guard_chained() { assert_eq "$(guard 'cd /x && gh issue edit 3 --repo o/m --add-label status:answered')" "$ASK"; }
test_guard_env_repo() { assert_eq "$(guard 'GH_REPO=o/m gh issue close 3')" "$ASK"; }
test_guard_case()    { assert_eq "$(guard 'gh issue comment 3 --repo O/M --body x')" "$ASK"; }

test_guard_read() {
  assert_empty "$(guard 'gh issue list --repo o/m')"
  assert_empty "$(guard 'gh issue view 3 --repo o/m --comments')"
}

test_guard_other_repo() { assert_empty "$(guard 'gh issue comment 3 --repo o/code --body x')"; }

test_guard_no_config() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"
  out="$(printf '{"tool_name":"Bash","tool_input":{"command":"gh issue close 3 --repo o/m"}}' | bash "$PLUGIN_DIR/scripts/guard-writes.sh")"; rc=$?
  assert_eq "$rc" "0"; assert_empty "$out"
}

test_guard_flag_before_verb() {
  assert_eq "$(guard 'gh issue -R o/m close 3')" "$ASK"
  assert_eq "$(guard 'gh issue --repo=o/m comment 3 --body-file x')" "$ASK"
  assert_eq "$(guard 'gh -R o/m issue close 3')" "$ASK"
}

test_guard_line_continuation() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m impl
  out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue \\n  comment 3 --repo o/m --body-file x"}}' | bash "$PLUGIN_DIR/scripts/guard-writes.sh")"
  assert_eq "$out" "$ASK"
}

test_guard_repo_admin() {
  assert_eq "$(guard 'gh repo edit o/m --visibility public')" "$ASK"
  assert_eq "$(guard 'gh repo archive o/m')" "$ASK"
}

test_guard_description_ignored() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m impl
  out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue list --repo o/m","description":"List issues to close or comment on"}}' | bash "$PLUGIN_DIR/scripts/guard-writes.sh")"
  assert_empty "$out"
}

test_guard_quoted_config() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"
  printf 'export SYNC_MAILBOX_REPO="o/m"\nSYNC_MAILBOX_ROLE=impl\n' > "$CLAUDE_PROJECT_DIR/.claude/sync-mailbox.env"
  assert_eq "$(guard 'gh issue close 3 --repo o/m')" "$ASK"
}

# guard_gl <command>: like guard, with a GitLab mailbox grp/proj on git.corp
guard_gl() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"; write_gitlab_config "$CLAUDE_PROJECT_DIR" grp/proj impl git.corp
  guard "$1"
}

test_guard_glab_note()   { assert_eq "$(guard_gl 'glab issue note 3 -R https://git.corp/grp/proj -m hi')" "$ASK"; }
test_guard_glab_update() { assert_eq "$(guard_gl 'glab issue update 3 -R grp/proj -u status:awaiting-answer -l status:answered')" "$ASK"; }
test_guard_glab_create() { assert_eq "$(guard_gl 'glab issue create -R https://git.corp/grp/proj -t t --description-file f -l for:spec -y')" "$ASK"; }
test_guard_glab_api()    { assert_eq "$(guard_gl 'glab api --hostname git.corp -X POST projects/grp%2Fproj/issues')" "$ASK"; }

test_guard_glab_read() {
  assert_empty "$(guard_gl 'glab issue view 3 -R https://git.corp/grp/proj --comments')"
  assert_empty "$(guard_gl 'glab issue list -R grp/proj')"
}
