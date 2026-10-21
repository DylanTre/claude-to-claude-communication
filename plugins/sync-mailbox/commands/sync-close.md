---
description: Close a sync mailbox question once its answer has been applied
argument-hint: "<issue number>"
---

Close sync mailbox issue #$ARGUMENTS, following the `sync-mailbox` skill.

1. Load config (missing: point to `/sync-setup` and stop). View issue $ARGUMENTS with its comments (see the skill's provider commands).
2. Only the asker closes: if the issue is not `from:<me>`, say so and stop. If it is not `status:answered`, warn and ask whether to close anyway.
3. Ask the user to confirm the answer has been applied, summarising what was decided and what changed.
4. Show the one-line closing comment (for example "Applied in <commit/PR or short description>.") and the exact close-with-comment command(s) for the provider. Wait for explicit approval, then run them.
