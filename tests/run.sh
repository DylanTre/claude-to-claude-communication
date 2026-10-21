#!/usr/bin/env bash
# Runs every test_* function in tests/test_*.sh, each in its own subshell.
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
export TESTS_DIR
export PLUGIN_DIR="$TESTS_DIR/../plugins/sync-mailbox"
pass=0; fail=0
for file in "$TESTS_DIR"/test_*.sh; do
  for t in $(grep -oE '^test_[A-Za-z0-9_]+' "$file"); do
    if ( source "$TESTS_DIR/helpers.sh"; source "$file"; "$t" ) >"$TESTS_DIR/.last_out" 2>&1; then
      echo "PASS $(basename "$file") $t"; pass=$((pass+1))
    else
      echo "FAIL $(basename "$file") $t"; sed 's/^/    /' "$TESTS_DIR/.last_out"; fail=$((fail+1))
    fi
  done
done
rm -f "$TESTS_DIR/.last_out"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
