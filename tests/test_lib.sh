# Tests for scripts/lib.sh: sync_load_config

load_lib() { source "$PLUGIN_DIR/scripts/lib.sh"; }

test_config_ok() {
  load_lib; p="$(mk_project)"; write_config "$p" o/m impl
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_REPO" "o/m"
  assert_eq "$SYNC_MAILBOX_ROLE" "impl"
}

test_config_missing_file() {
  load_lib; p="$(mk_project)"
  if sync_load_config "$p"; then fail "expected non-zero"; fi
  assert_empty "${SYNC_MAILBOX_REPO:-}"
}

test_config_missing_key() {
  load_lib; p="$(mk_project)"
  printf 'SYNC_MAILBOX_REPO=o/m\n' > "$p/.claude/sync-mailbox.env"
  if sync_load_config "$p"; then fail "expected non-zero"; fi
  assert_empty "${SYNC_MAILBOX_REPO:-}"
}

test_config_crlf() {
  load_lib; p="$(mk_project)"
  printf 'SYNC_MAILBOX_REPO=o/m\r\nSYNC_MAILBOX_ROLE=impl\r\n' > "$p/.claude/sync-mailbox.env"
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_REPO" "o/m"
  assert_eq "$SYNC_MAILBOX_ROLE" "impl"
}

test_config_path_with_spaces() {
  load_lib; p="$(mk_project "with space")"; write_config "$p" o/m spec
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_ROLE" "spec"
}

test_config_comments() {
  load_lib; p="$(mk_project)"
  printf '# mailbox\n\nSYNC_MAILBOX_REPO = o/m \nSYNC_MAILBOX_ROLE=impl\n' > "$p/.claude/sync-mailbox.env"
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_REPO" "o/m"
}

test_scripts_lf() {
  bad=""
  for f in "$PLUGIN_DIR"/scripts/*.sh; do
    od -An -tx1 "$f" | grep -q ' 0d' && bad="$bad $f"
  done
  assert_empty "$bad"
}

test_config_quoted() {
  load_lib; p="$(mk_project)"
  printf 'SYNC_MAILBOX_REPO="o/m"\nSYNC_MAILBOX_ROLE='"'"'impl'"'"'\n' > "$p/.claude/sync-mailbox.env"
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_REPO" "o/m"
  assert_eq "$SYNC_MAILBOX_ROLE" "impl"
}

test_config_export_prefix() {
  load_lib; p="$(mk_project)"
  printf 'export SYNC_MAILBOX_REPO=o/m\nexport SYNC_MAILBOX_ROLE=impl\n' > "$p/.claude/sync-mailbox.env"
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_REPO" "o/m"
}

test_config_default_provider() {
  load_lib; p="$(mk_project)"; write_config "$p" o/m impl
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_PROVIDER" "github"
  assert_empty "$SYNC_MAILBOX_HOST"
}

test_config_gitlab() {
  load_lib; p="$(mk_project)"; write_gitlab_config "$p" grp/sub/proj impl git.corp.example
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_PROVIDER" "gitlab"
  assert_eq "$SYNC_MAILBOX_HOST" "git.corp.example"
  assert_eq "$SYNC_MAILBOX_REPO" "grp/sub/proj"
}

test_config_gitlab_default_host() {
  load_lib; p="$(mk_project)"
  printf 'SYNC_MAILBOX_PROVIDER=gitlab\nSYNC_MAILBOX_REPO=g/p\nSYNC_MAILBOX_ROLE=impl\n' > "$p/.claude/sync-mailbox.env"
  sync_load_config "$p" || fail "returned non-zero"
  assert_eq "$SYNC_MAILBOX_HOST" "gitlab.com"
}

test_config_bad_provider() {
  load_lib; p="$(mk_project)"
  printf 'SYNC_MAILBOX_PROVIDER=bitbucket\nSYNC_MAILBOX_REPO=g/p\nSYNC_MAILBOX_ROLE=impl\n' > "$p/.claude/sync-mailbox.env"
  if sync_load_config "$p"; then fail "expected non-zero"; fi
}
