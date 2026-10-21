# Tests for scripts/session-start.sh (SessionStart hook)

run_session() { bash "$PLUGIN_DIR/scripts/session-start.sh"; }

INVALID="Sync mailbox: .claude/sync-mailbox.env is invalid (needs SYNC_MAILBOX_REPO=owner/name and a SYNC_MAILBOX_ROLE slug). Run /sync-setup to fix."

test_session_no_config() {
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"
  out="$(run_session)"; rc=$?
  assert_eq "$rc" "0"; assert_empty "$out"
  assert_empty "$(cat "$GH_LOG")"
}

test_session_empty_inbox() {
  printf '[]' > "$TESTS_DIR/.empty.json"; export GH_FIXTURE="$TESTS_DIR/.empty.json"
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m spec
  out="$(run_session)"; rc=$?
  rm -f "$TESTS_DIR/.empty.json"
  assert_eq "$rc" "0"; assert_empty "$out"
}

test_session_items() {
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m spec
  out="$(run_session)" || fail "non-zero exit"
  printf '%s' "$out" | jq -e . >/dev/null || fail "invalid JSON: $out"
  assert_eq "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName | tr -d '\r')" "SessionStart"
  assert_eq "$(printf '%s' "$out" | jq -r .hookSpecificOutput.additionalContext | tr -d '\r')" \
    "Sync mailbox (o/m, role spec): 1 to answer [#3], 1 answers to review [#5], 1 follow-ups from the other side [#7]. Tell the user briefly and offer /sync-inbox."
}

test_session_only_answers() {
  printf '[{"number":9,"title":"t","labels":[{"name":"for:impl"},{"name":"status:awaiting-answer"}]},{"number":11,"title":"u","labels":[{"name":"for:impl"},{"name":"status:awaiting-answer"}]}]' > "$TESTS_DIR/.only.json"
  export GH_FIXTURE="$TESTS_DIR/.only.json"
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m impl
  out="$(run_session)"; rm -f "$TESTS_DIR/.only.json"
  assert_contains "$out" "2 to answer [#9, #11]"
  assert_not_contains "$out" "review"
  assert_not_contains "$out" "follow-ups"
}

test_session_gh_fails() {
  use_stub_gh; export GH_EXIT=1; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m spec
  out="$(run_session)"; rc=$?
  assert_eq "$rc" "0"
  assert_eq "$out" "Sync mailbox: could not reach GitHub via gh (offline or not logged in?). Run /sync-setup to check."
}

test_session_gh_missing() {
  export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m spec
  out="$(PATH=/usr/bin run_session)"; rc=$?
  assert_eq "$rc" "0"
  assert_eq "$out" "Sync mailbox: could not reach GitHub via gh (offline or not logged in?). Run /sync-setup to check."
}

test_session_bad_config() {
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" 'o/m"x' spec
  out="$(run_session)"; rc=$?
  assert_eq "$rc" "0"
  assert_eq "$out" "$INVALID"
  assert_empty "$(cat "$GH_LOG")"
}

test_session_bad_role() {
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"; write_config "$CLAUDE_PROJECT_DIR" o/m "a b"
  assert_eq "$(run_session)" "$INVALID"
}

test_session_incomplete_config() {
  use_stub_gh; export CLAUDE_PROJECT_DIR="$(mk_project)"
  printf 'SYNC_MAILBOX_REPO=o/m\n' > "$CLAUDE_PROJECT_DIR/.claude/sync-mailbox.env"
  assert_eq "$(run_session)" "$INVALID"
}
