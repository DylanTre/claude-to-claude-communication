# Tests for scripts/inbox.sh <repo> <role>

TAB=$'\t'

test_inbox_spec() {
  use_stub_gh
  out="$(bash "$PLUGIN_DIR/scripts/inbox.sh" o/m spec)" || fail "non-zero exit"
  assert_eq "$out" "3${TAB}answer${TAB}Retry limit undefined
5${TAB}review${TAB}Answered for spec
7${TAB}followup${TAB}Needs more info"
}

test_inbox_impl() {
  use_stub_gh
  out="$(bash "$PLUGIN_DIR/scripts/inbox.sh" o/m impl)" || fail "non-zero exit"
  assert_eq "$out" "8${TAB}review${TAB}Answered by spec
9${TAB}answer${TAB}Is \"null\" allowed?"
}

test_inbox_title_quotes() {
  use_stub_gh
  out="$(bash "$PLUGIN_DIR/scripts/inbox.sh" o/m impl)"
  fields="$(printf "%s" "$out" | grep "^9" | awk -F'\t' '{print NF}')"
  assert_eq "$fields" "3"
  assert_contains "$out" '"null"'
}

test_inbox_gh_fails() {
  use_stub_gh; export GH_EXIT=1
  out="$(bash "$PLUGIN_DIR/scripts/inbox.sh" o/m spec 2>/dev/null)"; rc=$?
  assert_eq "$rc" "2"
  assert_empty "$out"
}

test_inbox_calls_once() {
  use_stub_gh
  bash "$PLUGIN_DIR/scripts/inbox.sh" o/m spec >/dev/null
  assert_eq "$(grep -c "^gh " "$GH_LOG")" "1"
  assert_contains "$(cat "$GH_LOG")" "gh issue list --repo o/m"
}
