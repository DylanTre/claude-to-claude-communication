---
description: One-time setup of the sync mailbox for this project (config, labels, smoke test)
---

Set up the sync mailbox for this project, following the `sync-mailbox` skill.

1. Run `gh --version` and `gh auth status`. If gh is missing or not logged in, tell the user how to fix it (`gh auth login`) and stop.
2. If `.claude/sync-mailbox.env` exists, show it and ask whether to keep it. Otherwise ask for the mailbox repo (`owner/name`) and the user's role (offer `impl` or `spec`; a role is a slug of letters, digits, `-`, `_`). Also ask the other side's role (default: the other of `impl`/`spec`).
3. Check the repo is reachable: `gh repo view <repo> --json name`.
4. Write `.claude/sync-mailbox.env`:
   ```
   SYNC_MAILBOX_REPO=<repo>
   SYNC_MAILBOX_ROLE=<role>
   ```
5. Keep it out of git: if this is a git repo, append `.claude/sync-mailbox.env` to the file at `git rev-parse --git-path info/exclude` unless it is already there, and tell the user. If it is not a git repo, say so.
6. Labels are a write to the shared repo: say you will create or update 8 labels, wait for a yes, then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-labels.sh" <repo> <my role> <other role>`. It is safe to re-run and only needed once per mailbox.
7. Smoke test: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/inbox.sh" <repo> <role>` and report the result (empty is fine).
8. Remind the user to enable GitHub notifications on the mailbox repo, and that `/loop 30m /sync-inbox` gives periodic checks during a session.
