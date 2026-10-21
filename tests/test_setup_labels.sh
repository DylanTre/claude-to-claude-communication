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

test_labels_gitlab_all() {
  use_stub_glab
  bash "$PLUGIN_DIR/scripts/setup-labels.sh" grp/proj impl spec gitlab git.corp >/dev/null || fail "non-zero exit"
  calls="$(grep '^glab label create' "$GLAB_LOG")"
  assert_eq "$(printf '%s\n' "$calls" | grep -c '')" "8"
  assert_eq "$(printf '%s\n' "$calls" | grep -c -- '-R https://git.corp/grp/proj')" "8"
  assert_contains "$calls" "--name status:needs-info"
  assert_contains "$calls" "--color #"
}

test_labels_gitlab_existing_ok() {
  use_stub_glab; export GLAB_LABEL_EXISTS=1
  bash "$PLUGIN_DIR/scripts/setup-labels.sh" grp/proj impl spec gitlab git.corp >/dev/null 2>&1 || fail "existing labels should be ok"
}

test_labels_gitlab_fail() {
  use_stub_glab; export GLAB_EXIT=1
  if bash "$PLUGIN_DIR/scripts/setup-labels.sh" grp/proj impl spec gitlab git.corp >/dev/null 2>&1; then fail "expected non-zero"; fi
}
