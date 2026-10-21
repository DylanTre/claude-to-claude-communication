---
description: Draft an answer or follow-up on a sync mailbox issue and post it after your approval
argument-hint: "<issue number>"
---

Reply on sync mailbox issue #$ARGUMENTS, following the `sync-mailbox` skill.

1. Load config (missing: point to `/sync-setup` and stop). View issue $ARGUMENTS with its comments (see the skill's provider commands) and read the referenced spec and code as needed.
2. Work out the situation from the labels:
   - `for:<me>` + `status:awaiting-answer`: I answer. Draft in the answer template, or, if it cannot be answered yet, draft a follow-up question instead.
   - `from:<me>` + `status:needs-info`: the other side asked me something; draft the reply.
   - anything else: explain the state and ask the user what they want.
3. Show the exact comment text and the exact commands (comment, then label change), and wait for explicit approval (re-show after edits). The label change is:
   - answer: remove `status:awaiting-answer`, add `status:answered`
   - follow-up from the answerer: remove `status:awaiting-answer`, add `status:needs-info`
   - asker replying to needs-info: remove `status:needs-info`, add `status:awaiting-answer`
4. Post the comment from a temp file, apply the label change, and print the issue URL.
5. If the answer implies a spec change on this side, offer to make it now in the normal workflow (approved separately).
