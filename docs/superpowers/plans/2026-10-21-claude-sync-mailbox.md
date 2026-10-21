# Claude Sync Mailbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Claude Code plugin that lets two developers' Claude instances exchange human-approved, structured questions and answers through GitHub Issues in a private "mailbox" repo.

**Architecture:** A marketplace repo (this folder, later pushed to the mailbox repo) that contains one plugin, `sync-mailbox`. Deterministic behavior lives in small bash scripts: config loading, the inbox query, the session-start notice, the write guard, and label setup. The scripts are tested with a stub `gh`. Judgment-heavy behavior (drafting, triage, the approval dialogue) lives in one skill plus five slash-command prompts. Hooks: `SessionStart` posts the inbox notice, and `PreToolUse` on Bash forces a permission prompt for mailbox writes.

**Tech Stack:** Bash (Git Bash on Windows), `gh` CLI with its built-in `--jq`, Claude Code plugin format (`.claude-plugin/plugin.json`, `marketplace.json`, `hooks/hooks.json`, `skills/`, `commands/`). Dev-only: the standalone `jq` binary (used by the test stub to emulate `gh --jq`).

**Spec:** `docs/specs/2026-10-21-claude-sync-mailbox-design.md`

## Global Constraints

- Runtime needs only bash and `gh`. No node, python, or standalone jq at runtime; JSON filtering uses `gh ... --jq`.
- Must run on Windows (Git Bash), macOS, and Linux. All `*.sh` files are LF (enforced by `.gitattributes`).
- Labels exactly: `for:<role>`, `from:<role>`, `status:awaiting-answer`, `status:needs-info`, `status:answered`, `blocking`. Resolved = closed issue.
- Inbox for role R = open issues with (`for:R` AND `status:awaiting-answer`) OR (`from:R` AND (`status:answered` OR `status:needs-info`)).
- Per-project config file: `<project>/.claude/sync-mailbox.env` with `SYNC_MAILBOX_REPO=<owner/name>` and `SYNC_MAILBOX_ROLE=<slug>`. Never committed: `/sync-setup` adds it to `.git/info/exclude`.
- No config in the project means the hooks exit 0 with no output and no `gh` call.
- The SessionStart hook never fails the session: always exit 0, print nothing when the inbox is empty, and print at most one warning line when `gh` fails. Timeout is 10 s in `hooks.json`.
- No `gh` write against the mailbox repo happens without the human approving the exact text and action (in the skill) AND a forced permission prompt (the guard hook).
- Code evidence = permalinks pinned to a commit SHA plus short previews; never whole files, never secrets.

## Review Focus

- **CRLF on Windows:** checking out or editing scripts or the config file on Windows adds `\r`, which breaks bash and makes the repo name mismatch. Expect them to still work. Tests: the `.gitattributes` check in Task 1, plus `test_config_crlf` in Task 1.
- **Paths with spaces or backslashes:** `CLAUDE_PROJECT_DIR` or `CLAUDE_PLUGIN_ROOT` like `C:\Users\a b\proj`. Expect config to still load. Test: `test_config_path_with_spaces` in Task 1.
- **Chained or prefixed commands:** `cd x && gh issue comment 3 --repo o/m --body "..."`, or `GH_REPO=o/m gh issue close 3`. Expect the guard to still ask. Tests: `test_guard_chained`, `test_guard_env_repo` in Task 4.
- **`gh` failing** (offline, not authenticated, missing): expect the session to start normally with one warning line. Tests: `test_session_gh_fails`, `test_session_gh_missing` in Task 3.
- **Titles with quotes or tabs,** e.g. `Is "null" allowed?`. Expect the inbox output and the session JSON to stay valid. Test: `test_inbox_title_quotes` in Task 2 (the session notice uses only numbers, never titles).

---

## File Structure

```
.gitattributes                                  *.sh text eol=lf; *.env text eol=lf
.claude-plugin/marketplace.json                 marketplace "claude-sync", one plugin entry
plugins/sync-mailbox/.claude-plugin/plugin.json manifest (name, version 0.1.0, description)
plugins/sync-mailbox/hooks/hooks.json           SessionStart + PreToolUse(Bash) registrations
plugins/sync-mailbox/scripts/lib.sh             sync_load_config
plugins/sync-mailbox/scripts/inbox.sh           inbox query → TSV
plugins/sync-mailbox/scripts/session-start.sh   SessionStart hook
plugins/sync-mailbox/scripts/guard-writes.sh    PreToolUse hook
plugins/sync-mailbox/scripts/setup-labels.sh    idempotent label creation
plugins/sync-mailbox/skills/sync-mailbox/SKILL.md
plugins/sync-mailbox/commands/sync-setup.md
plugins/sync-mailbox/commands/sync-ask.md
plugins/sync-mailbox/commands/sync-inbox.md
plugins/sync-mailbox/commands/sync-reply.md
plugins/sync-mailbox/commands/sync-close.md
tests/run.sh                                    runs every tests/test_*.sh, prints PASS/FAIL, exits non-zero on failure
tests/helpers.sh                                assert_eq, assert_contains, assert_empty, mk_project, use_stub_gh
tests/stub/gh                                   fake gh: logs argv to $GH_LOG, prints $GH_FIXTURE (through jq -r when --jq given), exits $GH_EXIT (default 0)
tests/fixtures/issues.json                      sample `gh issue list --json` output
tests/test_lib.sh, test_inbox.sh, test_session.sh, test_guard.sh, test_setup_labels.sh
README.md
```

---

### Task 1: Repo scaffold, test harness, config loader

**Files:**
- Create: `.gitattributes`, `.claude-plugin/marketplace.json`, `plugins/sync-mailbox/.claude-plugin/plugin.json`, `plugins/sync-mailbox/scripts/lib.sh`, `tests/run.sh`, `tests/helpers.sh`, `tests/stub/gh`, `tests/test_lib.sh`

**Interfaces:**
- Produces: `sync_load_config <project_dir>`. It returns 0 and exports `SYNC_MAILBOX_REPO` and `SYNC_MAILBOX_ROLE` (with `\r` and surrounding whitespace stripped) when `<project_dir>/.claude/sync-mailbox.env` exists and both keys are non-empty. Otherwise it returns 1 and sets nothing. It reads the file line by line (`KEY=value`, ignoring `#` comments) and never `source`s it.
- Produces: the test helpers `mk_project` (prints a temp dir path, optionally with a space in it via `mk_project "with space"`), `write_config <dir> <repo> <role>`, and `use_stub_gh` (prepends `tests/stub` to PATH and sets `GH_LOG`).

- [ ] **Step 1:** `git init` in the repo root. Create `.gitattributes`, both manifests (marketplace `name: "claude-sync"`, plugin entry `{"name":"sync-mailbox","source":"./plugins/sync-mailbox"}`; plugin `name: "sync-mailbox"`, `version: "0.1.0"`), and `tests/run.sh`, `tests/helpers.sh`, `tests/stub/gh`.
- [ ] **Step 2: Write failing tests** in `tests/test_lib.sh`:
  - `test_config_ok`: config `o/m` + `impl` → returns 0, `SYNC_MAILBOX_REPO=o/m`, `SYNC_MAILBOX_ROLE=impl`
  - `test_config_missing_file` → returns 1
  - `test_config_missing_key` (only REPO set) → returns 1
  - `test_config_crlf`: file written with `\r\n` → values equal `o/m` / `impl` exactly
  - `test_config_path_with_spaces`: project dir containing a space → returns 0
  - `test_config_comments`: a `# comment` line and a blank line are ignored
  - `test_scripts_lf`: no file under `plugins/` matching `*.sh` contains `\r`
- [ ] **Step 3:** Run `bash tests/run.sh`. Expected: the `test_lib` cases FAIL (`sync_load_config` not found).
- [ ] **Step 4:** Implement `sync_load_config` in `plugins/sync-mailbox/scripts/lib.sh`.
- [ ] **Step 5:** Run `bash tests/run.sh`. Expected: all PASS. Then run `claude plugin validate .`. Expected: no errors.
- [ ] **Step 6:** Commit: `feat: scaffold marketplace, plugin manifest, config loader`

### Task 2: Inbox query

**Files:**
- Create: `plugins/sync-mailbox/scripts/inbox.sh`, `tests/fixtures/issues.json`, `tests/test_inbox.sh`

**Interfaces:**
- Consumes: `sync_load_config`.
- Produces: `inbox.sh <repo> <role>`. It runs one call: `gh issue list --repo <repo> --state open --limit 200 --json number,title,labels --jq <filter>`, and prints one line per item as `<number>\t<kind>\t<title>`. `kind` is `answer` (for:R + awaiting-answer), `review` (from:R + answered), or `followup` (from:R + needs-info). Lines are sorted by number ascending. Exit 0 on success (empty output for an empty inbox); exit 2 if `gh` fails or is missing, with nothing on stdout.

- [ ] **Step 1: Write the fixture.** Issues: #3 `for:spec,status:awaiting-answer,from:impl`; #5 `from:spec,status:answered,for:impl`; #7 `from:spec,status:needs-info,for:impl`; #8 `for:impl,status:answered,from:spec`; #9 `for:impl,status:awaiting-answer,from:spec,blocking`, title `Is "null"	allowed?` (with a literal tab).
- [ ] **Step 2: Write failing tests:**
  - `test_inbox_spec`: role `spec` → exactly `3\tanswer\t…`, `5\treview\t…`, `7\tfollowup\t…` (#8 is excluded)
  - `test_inbox_impl`: role `impl` → exactly `9\tanswer\t…` (#3, #5, #7, #8 excluded)
  - `test_inbox_title_quotes`: #9's line has 3 tab-separated fields, with the title's tab replaced by a space and its quotes kept
  - `test_inbox_gh_fails`: `GH_EXIT=1` → exit code 2, stdout empty
  - `test_inbox_calls_once`: `GH_LOG` shows exactly one `gh issue list --repo o/m` call
- [ ] **Step 3:** Run `bash tests/run.sh`. Expected: the inbox tests FAIL.
- [ ] **Step 4:** Implement `inbox.sh`. The jq filter maps label names to an array, selects per the Global Constraints rule, applies `gsub("\t";" ")` to the title, and emits `@tsv`-style lines.
- [ ] **Step 5:** Run the tests. Expected: all PASS.
- [ ] **Step 6:** Commit: `feat: inbox query`

### Task 3: SessionStart hook

**Files:**
- Create: `plugins/sync-mailbox/scripts/session-start.sh`, `plugins/sync-mailbox/hooks/hooks.json`, `tests/test_session.sh`

**Interfaces:**
- Consumes: `sync_load_config "$CLAUDE_PROJECT_DIR"`, `inbox.sh`.
- Produces: the hook registration `SessionStart` → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"`, `timeout: 10`.
- Output when items exist (stdout, one JSON object): `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<msg>"}}`, where `<msg>` is exactly `Sync mailbox (<repo>, role <role>): <A> to answer [#n, ...], <B> answers to review [#n, ...], <C> follow-ups from the other side [#n, ...]. Tell the user briefly and offer /sync-inbox.`. A zero-count group is omitted along with its comma. The message contains only numbers and the repo/role, so no escaping is needed beyond the config values. Reject a config whose repo/role contains `"` or `\` by treating it as invalid config.
- Warning when `gh` fails (stdout, plain text, one line): `Sync mailbox: could not reach GitHub via gh (offline or not logged in?). Run /sync-setup to check.`

- [ ] **Step 1: Write failing tests:**
  - `test_session_no_config` → no stdout, exit 0, `GH_LOG` empty
  - `test_session_empty_inbox` → no stdout, exit 0
  - `test_session_items`: role `spec` with the fixture → valid JSON (check with dev `jq -e .`), `additionalContext` equals `Sync mailbox (o/m, role spec): 1 to answer [#3], 1 answers to review [#5], 1 follow-ups from the other side [#7]. Tell the user briefly and offer /sync-inbox.`
  - `test_session_only_answers`: role `impl` → message contains `1 to answer [#9]` and neither "review" nor "follow-ups"
  - `test_session_gh_fails`: `GH_EXIT=1` → exactly the warning line, exit 0
  - `test_session_gh_missing`: PATH without gh → exactly the warning line, exit 0
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `session-start.sh` and `hooks.json` (the PreToolUse entry is added in Task 4).
- [ ] **Step 4:** Run the tests. Expected: all PASS. Run `claude plugin validate .`. Expected: no errors.
- [ ] **Step 5:** Commit: `feat: session-start inbox notice`

### Task 4: Write guard (PreToolUse)

**Files:**
- Create: `plugins/sync-mailbox/scripts/guard-writes.sh`, `tests/test_guard.sh`
- Modify: `plugins/sync-mailbox/hooks/hooks.json` (add `PreToolUse`, matcher `Bash`, `bash "${CLAUDE_PLUGIN_ROOT}/scripts/guard-writes.sh"`, `timeout: 5`)

**Interfaces:**
- Consumes: `sync_load_config "$CLAUDE_PROJECT_DIR"`. Reads the hook JSON from stdin, matching against the raw stdin text, so it doesn't need jq.
- Produces: when the stdin text contains the mailbox repo string (case-insensitive) AND matches `gh[[:space:]]+(issue[[:space:]]+(create|comment|edit|close|reopen|delete|transfer|lock|unlock|pin|unpin)|label[[:space:]]+(create|edit|delete|clone)|api)`, it prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"sync-mailbox: posting to the shared mailbox needs your explicit approval"}}`. Otherwise it prints nothing. Always exit 0.

- [ ] **Step 1: Write failing tests** (stdin = `{"tool_name":"Bash","tool_input":{"command":"<cmd>"}}`, config repo `o/m`):
  - `test_guard_comment`: `gh issue comment 3 --repo o/m --body-file x.md` → ask JSON
  - `test_guard_create`: `gh issue create --repo o/m --title t --label for:spec` → ask
  - `test_guard_close`: `gh issue close 3 -R o/m` → ask
  - `test_guard_api`: `gh api repos/o/m/issues/3/comments -f body=x` → ask
  - `test_guard_chained`: `cd /x && gh issue edit 3 --repo o/m --add-label status:answered` → ask
  - `test_guard_env_repo`: `GH_REPO=o/m gh issue close 3` → ask
  - `test_guard_read`: `gh issue list --repo o/m` and `gh issue view 3 --repo o/m` → no output
  - `test_guard_other_repo`: `gh issue comment 3 --repo o/code` → no output
  - `test_guard_no_config` → no output, exit 0
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `guard-writes.sh`.
- [ ] **Step 4:** Run the tests. Expected: all PASS. Run `claude plugin validate .`. Expected: no errors.
- [ ] **Step 5:** Commit: `feat: force approval prompt on mailbox writes`

### Task 5: Label setup script

**Files:**
- Create: `plugins/sync-mailbox/scripts/setup-labels.sh`, `tests/test_setup_labels.sh`

**Interfaces:**
- Produces: `setup-labels.sh <repo> <role_a> <role_b>`. It runs `gh label create <name> --repo <repo> --color <hex> --description <text> --force` for each of: `for:<a>`, `for:<b>`, `from:<a>`, `from:<b>`, `status:awaiting-answer`, `status:needs-info`, `status:answered`, `blocking`. It exits non-zero on the first failure, naming the label. Colors are the builder's choice.

- [ ] **Step 1: Write failing tests:**
  - `test_labels_all`: `o/m impl spec` → `GH_LOG` has 8 `label create` calls, each with `--repo o/m` and `--force`, and exactly the 8 names above
  - `test_labels_fail`: `GH_EXIT=1` → non-zero exit
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `setup-labels.sh`.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: idempotent label setup`

### Task 6: Skill and slash commands

**Files:**
- Create: `plugins/sync-mailbox/skills/sync-mailbox/SKILL.md` and `plugins/sync-mailbox/commands/{sync-setup,sync-ask,sync-inbox,sync-reply,sync-close}.md`

**Interfaces:**
- Consumes: `inbox.sh`, `setup-labels.sh`, the config file, and the label set. Commands reference scripts as `${CLAUDE_PLUGIN_ROOT}/scripts/...`.

Required content (the wording is the builder's):
- **SKILL.md.** Frontmatter `description` triggers on "ask the spec/impl side", "post to the mailbox", "check the sync inbox", "answer the question from …". The body holds:
  - the question and answer templates copied verbatim from the spec's "Message templates" section
  - the label table and the inbox rule
  - the approval rule: show the exact text and command, wait for an explicit yes, and re-show after any edit
  - always pass `--repo $SYNC_MAILBOX_REPO`, never rely on cwd
  - post bodies via `--body-file` on a temp file (avoids shell quoting and CRLF problems)
  - evidence: permalinks at `git rev-parse HEAD` in the code host's URL format plus previews of at most ~15 lines; no secrets or whole files
  - if config is missing, point to `/sync-setup`
- **`/sync-setup`:** checks `gh --version` and `gh auth status`. Asks for the mailbox repo and the role (offering `impl`/`spec`). Writes `.claude/sync-mailbox.env`, then appends `.claude/sync-mailbox.env` to `.git/info/exclude` if it isn't already there (and says so if the project isn't a git repo). Runs `setup-labels.sh` (a write: confirm first). Finishes by running the inbox once as a smoke test.
- **`/sync-ask [topic]`:** drafts from the session context using the question template, picks the `for:` role (the other side), and offers `blocking`. Shows the draft and posts on approval with `for:<other>`, `from:<me>`, `status:awaiting-answer`. Prints the issue URL.
- **`/sync-inbox`:** runs `inbox.sh`. For each item, `gh issue view <n> --repo … --comments`. Gives a short summary per item (blocking items first). For `answer` items, reads the referenced spec and code and offers a draft answer. Never posts on its own.
- **`/sync-reply <n>`:** drafts an answer (answer template) or a follow-up comment. On approval, posts it and switches the status label: answer → `status:answered`; follow-up → `status:needs-info` when asking the asker, or `status:awaiting-answer` when the asker is replying to a needs-info. Remove the old status label in the same `gh issue edit`.
- **`/sync-close <n>`:** confirms the answer was applied, then on approval closes it with a one-line closing comment.

- [ ] **Step 1:** Write `SKILL.md` and the five command files.
- [ ] **Step 2:** Run `claude plugin validate .`. Expected: no errors. Run `bash tests/run.sh`. Expected: all PASS.
- [ ] **Step 3:** Commit: `feat: sync-mailbox skill and commands`

### Task 7: README and end-to-end check

**Files:**
- Create: `README.md`

**README covers:**
- what it is (2 lines)
- prerequisites: `gh`, and `gh auth login`
- create the private mailbox repo and add the colleague as a collaborator
- push this repo's contents to it
- `/plugin marketplace add <owner>/<mailbox-repo>`, then `/plugin install sync-mailbox@claude-sync`
- `/sync-setup` once per project
- the daily flow (ask → inbox → reply → close)
- the opt-in `/loop 30m /sync-inbox`
- enable GitHub notifications on the repo
- recommended permissions: allow only `Bash(gh issue list:*)` and `Bash(gh issue view:*)`, never `gh` writes
- updating: bump `version` in plugin.json, push, then `/plugin update sync-mailbox`
- the modes table from Step 3 below

- [ ] **Step 1:** Write the README.
- [ ] **Step 2: Manual end-to-end** on a throwaway private repo `<you>/sync-mailbox-test`, using two project folders configured with roles `impl` and `spec`:
  1. Install from a local marketplace path, then run `/sync-setup` in both folders.
  2. In `impl`, run `/sync-ask`. Verify the guard prompt appears and the issue has the right labels.
  3. Start a new session in `spec`. Verify the notice names the issue.
  4. Run `/sync-reply`, then verify the labels changed.
  5. Start a new session in `impl`. Verify the notice shows "answers to review".
  6. Run `/sync-close`.
  7. Start a session in a folder without config. Verify there's no notice and the guard stays silent.
- [ ] **Step 3: Verify the forced prompt per mode.** Repeat a `gh issue comment` to the test repo in default mode, auto mode, and bypass-permissions mode. Record whether the prompt appears in each, and write the result into the README's permissions section (spec: "document any mode where it doesn't").
- [ ] **Step 4:** Commit: `docs: README and verified setup`
