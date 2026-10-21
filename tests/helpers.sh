# Shared test helpers. Assertions exit the test's subshell on failure.
fail() { echo "ASSERT: $*"; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected [$2] got [$1]${3:+ ($3)}"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "[$1] does not contain [$2]";; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "[$1] contains [$2]";; esac; }
assert_empty() { [ -z "$1" ] || fail "expected empty, got [$1]"; }

# mk_project [suffix]: prints a fresh temp project dir (suffix may contain spaces)
mk_project() {
  local d
  d="$(mktemp -d)/proj${1:+ $1}"
  mkdir -p "$d/.claude"
  printf '%s' "$d"
}

# write_config <dir> <repo> <role>
write_config() {
  printf 'SYNC_MAILBOX_REPO=%s\nSYNC_MAILBOX_ROLE=%s\n' "$2" "$3" > "$1/.claude/sync-mailbox.env"
}

# use_stub_gh: put the fake gh first on PATH, log its calls to $GH_LOG
use_stub_gh() {
  export PATH="$TESTS_DIR/stub:$PATH"
  export GH_LOG
  GH_LOG="$(mktemp)"
  export GH_FIXTURE="${GH_FIXTURE:-$TESTS_DIR/fixtures/issues.json}"
}
