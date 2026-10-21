---
description: Draft a question for the other side and post it to the sync mailbox after your approval
argument-hint: "[topic]"
---

Draft a question for the other side about: $ARGUMENTS (if empty, use the issue we have been discussing in this session).

Follow the `sync-mailbox` skill:

1. Load config from `.claude/sync-mailbox.env` (missing: point to `/sync-setup` and stop).
2. Gather what the question template needs from this session and the code: the observation, the root cause as validated with the user, permalinks at the current pushed commit with short previews, the exact spec passage and its location, options with consequences, and your recommendation. If something essential is unknown (for example the root cause is not yet validated), ask the user rather than guess.
3. Ask whether it is blocking.
4. Show the full draft: title, body, labels (`for:<other>`, `from:<me>`, `status:awaiting-answer`, optional `blocking`) and the exact create command for the provider (see the skill's provider commands). Wait for explicit approval; re-show after edits.
5. Post it, then print the issue URL.
