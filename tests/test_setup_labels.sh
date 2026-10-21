# Tests for scripts/setup-labels.sh <repo> <role_a> <role_b>

test_labels_all() {
  use_stub_gh
  bash "$PLUGIN_DIR/scripts/setup-labels.sh" o/m impl spec >/dev/null || fail "non-zero exit"
  calls="$(grep '^gh label create' "$GH_LOG")"
  assert_eq "$(printf '%s\n' "$calls" | grep -c '')" "8"
  assert_eq "$(printf '%s\n' "$calls" | grep -c -- '--repo o/m')" "8"
  assert_eq "$(printf '%s\n' "$calls" | grep -c -- '--force')" "8"
  names="$(printf '%s\n' "$calls" | awk '{print $4}' | sort | tr '\n' ' ')"
  assert_eq "$names" "blocking for:impl for:spec from:impl from:spec status:answered status:awaiting-answer status:needs-info "
}

test_labels_fail() {
  use_stub_gh; export GH_EXIT=1
  if bash "$PLUGIN_DIR/scripts/setup-labels.sh" o/m impl spec >/dev/null 2>&1; then fail "expected non-zero"; fi
}
