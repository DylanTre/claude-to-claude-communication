---
description: One-time setup of the sync mailbox for this project (config, labels, smoke test)
---

Set up the sync mailbox for this project, following the `sync-mailbox` skill.

1. If `.claude/sync-mailbox.env` exists, show it and ask whether to keep it. Otherwise ask:
   - where the mailbox lives: **GitHub** or **GitLab**; for GitLab also the host (e.g. `gitlab.example.com`, default `gitlab.com`),
   - the mailbox repo (`owner/name` on GitHub, `group/subgroup/project` on GitLab),
   - the user's role (offer `impl` or `spec`; a slug of letters, digits, `-`, `_`) and the other side's role (default: the other of `impl`/`spec`).
2. Check the CLI for that provider:
   - GitHub: `gh --version` and `gh auth status`; fix with `gh auth login`.
   - GitLab: `glab --version` and `glab auth status --hostname <host>`; fix with `glab auth login --hostname <host>` (install: https://gitlab.com/gitlab-org/cli#installation). A self-hosted server may need the company network or VPN.
   If it is missing or not logged in, tell the user how to fix it and stop.
3. Write `.claude/sync-mailbox.env`:
   ```
   SYNC_MAILBOX_PROVIDER=<github|gitlab>
   SYNC_MAILBOX_HOST=<gitlab host; omit for github>
   SYNC_MAILBOX_REPO=<repo>
   SYNC_MAILBOX_ROLE=<role>
   ```
4. Keep it out of git: if this is a git repo, append `.claude/sync-mailbox.env` to the file at `git rev-parse --git-path info/exclude` unless it is already there, and tell the user. If it is not a git repo, say so.
5. Check the mailbox is reachable: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/inbox.sh" <repo> <role> <provider> <host>`. Exit 2 means it is unreachable (wrong name, no access, not logged in, or off the network): report it and stop. Otherwise report the result (empty is fine).
6. Labels are a write to the shared repo: say you will create (or update) 8 labels, wait for a yes, then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-labels.sh" <repo> <my role> <other role> <provider> <host>`. It is safe to re-run and only needed once per mailbox.
7. Remind the user to turn on notifications for the mailbox repo (GitHub: Watch → All activity; GitLab: the bell → Watch), and that `/loop 30m /sync-inbox` gives periodic checks during a session.
