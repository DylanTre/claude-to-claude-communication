---
description: Check the sync mailbox and triage what is waiting for you
---

Check the sync mailbox, following the `sync-mailbox` skill. This command never posts anything.

1. Load config from `.claude/sync-mailbox.env` (missing: point to `/sync-setup` and stop).
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/inbox.sh" <repo> <role> <provider> <host>` with the config values. Exit code 2: tell the user the mailbox is unreachable (CLI missing, not logged in, or off the network). Empty output: say the inbox is empty and stop.
3. For each item, view it with its comments (see the skill's provider commands).
4. Report `blocking` items first, one short block each:
   - **answer** (a question for you): what is asked, why it matters, urgency. Read the referenced spec and code, then offer a draft answer in the answer template, plus a proposed spec change if one is needed. Suggest `/sync-reply <n>`.
   - **review** (your question was answered): the decision and follow-ups, and how you propose to apply it to the current work. Suggest applying it, then `/sync-close <n>`.
   - **followup** (the other side asked you something back): what they need. Suggest `/sync-reply <n>`.
