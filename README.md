# claude-sync: a mailbox between two Claude Code instances

`sync-mailbox` is a Claude Code plugin. It lets the spec author's Claude and the implementer's Claude exchange structured questions and answers through Issues in a private GitHub repo. A human approves every message before it is posted.

## How it works

- One private GitHub repo is the **mailbox**. Each question is one issue, and replies are comments.
- Labels route and track each question: `for:<role>`, `from:<role>`, `status:awaiting-answer | needs-info | answered`, `blocking`. A closed issue means the question is resolved.
- When you start a session, Claude tells you if anything is waiting for you. Nothing is posted, relabeled, or closed without your explicit OK, and the plugin also forces a permission prompt for those commands.

## Prerequisites (both developers)

- Claude Code
- GitHub CLI: install `gh`, then run `gh auth login`.
- Windows: Git Bash (already required by Claude Code).

## One-time setup

1. **Create the mailbox repo** (private), for example `acme/feature-x-sync`, and add your colleague as a collaborator.
2. **Publish this plugin into it.** From this folder, push this repository's contents to the mailbox repo:
   ```bash
   git remote add origin https://github.com/acme/feature-x-sync.git
   git push -u origin main
   ```
3. **Install, both of you,** in Claude Code:
   ```
   /plugin marketplace add acme/feature-x-sync
   /plugin install sync-mailbox@claude-sync
   ```
   Restart Claude Code.
4. **Configure each project** where you work on the feature (your code repo; your colleague's spec repo or folder):
   ```
   /sync-setup
   ```
   This asks for the mailbox repo and your role (`impl` or `spec`). It writes `.claude/sync-mailbox.env`, keeps that file out of git through `.git/info/exclude`, and creates the labels once you confirm. In projects without this file, the plugin does nothing.
5. **Turn on GitHub notifications** for the mailbox repo (Watch → All activity), so you hear about messages when Claude Code is closed.

## Daily flow

| You | Command |
|---|---|
| Found a spec gap with Claude, root cause understood: post it | `/sync-ask [topic]` (or just "ask the spec side about this") |
| See what's waiting for you, with draft answers | `/sync-inbox` |
| Answer, or ask back | `/sync-reply <n>` |
| The answer has been applied: close the question | `/sync-close <n>` |

At session start, Claude mentions waiting items automatically. For periodic checks during a long session, run `/loop 30m /sync-inbox`.

## Permissions

- It's fine to allow reads: `Bash(gh issue list:*)` and `Bash(gh issue view:*)`.
- **Don't** allow `gh` writes (`gh issue create/comment/edit/close`, `gh api`) in your settings.
- The plugin's `PreToolUse` hook returns "ask" for any `gh` write that targets the mailbox repo, even if your allow-list would permit it. Behavior per permission mode:

| Mode | Prompt appears? |
|---|---|
| default | _to verify_ |
| auto | _to verify_ |
| bypass permissions | _to verify_ |

## Updating

1. Bump `version` in `plugins/sync-mailbox/.claude-plugin/plugin.json`, commit, and push to the mailbox repo.
2. Both developers run `/plugin marketplace update claude-sync`, then `/plugin update sync-mailbox@claude-sync`, and restart.

## Development

- Tests: `bash tests/run.sh`. They need bash, plus the standalone `jq` binary, which the fake `gh` uses.
- Validate: `claude plugin validate .`
- Design and plan: `docs/specs/`, `docs/superpowers/plans/`.
