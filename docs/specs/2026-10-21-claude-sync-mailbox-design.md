# Claude Sync Mailbox: Design

Date: 2026-10-21
Status: draft, awaiting approval

## Intent

Two developers work on the same feature in two roles:

- **Spec side:** writes the high-level specification with their own Claude Code instance.
- **Implementation side:** owns architecture and code with their own Claude Code instance.

The implementation-side Claude reads the codebase, so it is the first to notice when the spec allows wrong or ambiguous behavior. Today that finding passes through four hand-offs (Claude → dev → colleague → Claude). The humans' judgment is not the bottleneck. The daily syncing on *what to ask* each other's Claude is, along with the detail lost on each retelling.

The mailbox lets one Claude post a structured, human-approved question that the other Claude picks up, triages for its human, and answers once its human approves. Humans stay in the loop on every outgoing message but no longer act as couriers.

## Goals

- A question that one human approves reaches the other Claude with full context: observation, root cause, code evidence, spec reference, options, and a recommendation.
- The receiving Claude can draft a useful answer, and any spec change, from the message alone, without the humans syncing separately.
- The answer returns to the asking Claude in a form it can act on.
- No hosting, no open ports, no VPN. Free.
- Both developers can install it in a few minutes and get the same version.

## Non-goals

- Two Claudes negotiating with each other autonomously.
- Real-time chat.
- Applying spec or code changes automatically; that happens in each side's normal workflow, with their human.
- A custom server or web UI (a possible later step, see "Future").

## Anti-goals (failure even if it "works")

- A Claude posts, comments, relabels, or closes anything without explicit approval from its human for that exact action and text.
- Messages are so terse that the humans have to talk to decode them, which recreates the current problem.
- Inbox noise: reminders that interrupt work when nothing is waiting.
- Leaking more than needed: secrets, credentials, or whole files pasted when an excerpt and a link would do.

## Constraints

- The spec-side developer is usually remote, the implementation side is usually on the office LAN. No inbound ports and no company VPN.
- The spec sometimes lives in the code repo and sometimes in a separate source (another repo or a document). Messages must be able to reference either.
- At least one participant runs Windows (PowerShell plus Git Bash). The other's OS is unknown, so every script must work on Windows, macOS, and Linux.
- Putting code excerpts and spec text on a private hosted git service is acceptable (the user confirmed choosing this option).
- Both developers can read the code repo, including the spec-side developer working remotely without a VPN (confirmed by the user). Permalinks are therefore the primary evidence. Excerpts are only short previews so a reader doesn't have to click through, never a substitute for the link. Permalinks follow the code host's URL format, pinned to a commit SHA.

## Decided

### Transport: a private GitHub repo used as a mailbox

- One private repo per collaboration (e.g. `<org-or-user>/feature-x-sync`) with both developers as collaborators. The mailbox repo holds no code; Issues are the mailbox.
- **One issue = one question thread.** The question is the issue body, and replies and follow-ups are comments.
- All Claude access goes through the `gh` CLI, authenticated as each developer.
- GitHub's own email and mobile notifications cover the case where Claude Code isn't running. Nothing extra is built for that.

### Roles and routing (symmetric)

Either side can ask. Each install is configured with:

- `mailbox_repo`: e.g. `acme/feature-x-sync`
- `my_role`: a short slug, e.g. `impl` or `spec`

Labels:

| Label | Meaning |
|---|---|
| `for:<role>` | who must answer (e.g. `for:spec`) |
| `from:<role>` | who asked |
| `status:awaiting-answer` | waiting on the addressee |
| `status:needs-info` | addressee asked a follow-up; waiting on the asker |
| `status:answered` | answer posted; asker should review and apply |
| `blocking` | optional; asker is blocked until this is answered |
| closed issue | resolved; the asker closes it after applying the answer |

**My inbox** is the union of:
1. open issues labeled `for:<me>` + `status:awaiting-answer` (questions to answer), and
2. open issues labeled `from:<me>` + (`status:answered` or `status:needs-info`) (replies to act on).

### Message templates

**Question (issue body)**, title `[<area>] <one-line question>`:

- **Question:** the exact decision needed, phrased so it can be answered directly
- **What we observed:** the concrete behavior or scenario the spec allows
- **Root cause:** why the spec permits it (the human-validated analysis)
- **Code evidence:** permalinks pinned to a commit SHA, plus short excerpts (a few lines each, never whole files)
- **Spec reference:** location (`repo/path@sha#section`, or doc URL plus section name) and the quoted passage
- **Options:** each option with its consequences
- **Recommendation:** what the asker suggests, and why
- **Blocking?** yes/no, and what is blocked

**Answer (comment):**

- **Decision**
- **Rationale**
- **Spec change:** the new or changed text, and where it lives / will live (or "none")
- **Follow-ups:** anything the asker must do or watch for

Follow-up questions in either direction are plain comments that end with a clear question, plus a status label change.

### Human approval (hard rule, enforced twice)

1. **In the skill:** before any `gh` write (`issue create`, `issue comment`, `issue edit`, label changes, `issue close`), Claude shows the human the exact text and action and waits for an explicit yes. Edits mean showing it again.
2. **In a hook:** the plugin ships a `PreToolUse` hook on Bash that returns `permissionDecision: "ask"` for any `gh` write (`issue create|comment|edit|close|reopen`, label add/remove) that targets the mailbox repo. Permission rules can't be relied on, since a user may have `Bash(gh:*)` allowed or run in auto/bypass mode, and a plugin can't set user permission rules. The hook is scoped to the mailbox repo so other `gh` work is untouched. The builder must verify the forced prompt actually appears in default, auto, and bypass modes, and document any mode where it doesn't. The README also recommends keeping `gh` writes off the allow-list.

### Workflow

**Asking side:**
1. Claude spots a spec issue during normal work and tells its human.
2. The human investigates with Claude and validates the root cause.
3. The human says "ask the spec side" (or runs the ask command). Claude drafts the question from the template, using the session context.
4. The human reviews and edits, then approves. Claude creates the issue with the `for:`, `from:` and `status:awaiting-answer` labels.

**Answering side:**
5. Claude learns of the question (see "Checking for new messages") and gives its human a short summary: what's asked, how urgent, and Claude's draft answer after reading the relevant spec. If needed, it also drafts a spec change.
6. The human edits and approves. Claude posts the answer comment and sets `status:answered`, or asks a follow-up and sets `status:needs-info`.
7. Any spec edit happens in that side's normal workflow, with the human's approval.

**Back on the asking side:**
8. Claude reports the answer. Once the human confirms, Claude applies it to its work, then closes the issue (another approved write).

### Checking for new messages

- **At session start:** a `SessionStart` hook runs a read-only `gh issue list` query for "my inbox". If anything is waiting, it injects a one-line context note ("Sync mailbox: 2 questions to answer, 1 reply to review: #12, #14, #9") so Claude brings it up. If the inbox is empty, it prints nothing.
- **While working:** opt-in. The developer runs e.g. `/loop 30m /sync-inbox` when they want periodic checks.
- **When Claude Code is closed:** GitHub notifications.
- The hook must never block or slow a session noticeably. If `gh` is missing, offline, or unauthenticated, it fails silently (or emits one short warning line) and exits 0. It needs a short timeout.

### Packaging: one Claude Code plugin, built in this folder

Contents:

- **Skill `sync-mailbox`:** the rules (templates, labels, inbox definition, the approval rule, evidence and confidentiality guidance) and when to use them.
- **Commands:**
  - `/sync-setup`: one-time. Checks that `gh` is installed and authenticated, creates the labels in the mailbox repo (idempotently), and writes or explains the per-user config.
  - `/sync-ask`: drafts a question from the current context, shows it, and posts it after approval.
  - `/sync-inbox`: lists the inbox, then summarizes and triages each item.
  - `/sync-reply <n>`: drafts an answer or follow-up for issue n, shows it, and posts it after approval.
  - `/sync-close <n>`: confirms the answer was applied, then closes the issue after approval.
- **SessionStart hook:** as above.
- **README:** install, `gh auth login`, config, a first-run walkthrough, and the recommended permission settings.

### Config scope: per project

- The plugin is installed user-wide, but it does nothing in a project unless that project has mailbox config (`mailbox_repo`, `my_role`) in an uncommitted per-project location (e.g. `.claude/settings.local.json`). With no config, the SessionStart hook exits immediately with no network call, so unrelated work never sees inbox noise.
- `/sync-setup` writes this config for the current project. A developer whose spec lives in several places, or who works on several features, runs it once per project. A project maps to exactly one mailbox.

### Distribution: the plugin lives in the mailbox repo

- The private mailbox repo also holds the plugin and a `.claude-plugin/marketplace.json`. Both developers already have access to it, so they install with `/plugin marketplace add <org>/<mailbox-repo>`, using the `gh`/git credentials they already have. No public repo is needed.
- Updates go through version bumps in the plugin manifest. Both sides pull with the plugin update command.
- Development happens in `claudeComm` (turned into a git repo) and gets pushed to the mailbox repo.

## Left to the builder

- Exactly where the per-project config is stored, as long as it's per project, set once by `/sync-setup`, and never committed to the code repo.
- The hook's implementation language, as long as it is cross-platform with no extra runtime beyond what Claude Code and `gh` need (a single `gh ... --jq` call is ideal).
- Command names and wording, the label colors, the exact `--jq` filters.
- Whether `/sync-ask` also works when asked in plain language ("post this to the spec side"); preferred, via the skill description.

## Calls made by Claude (not explicitly confirmed by the user)

- Symmetric routing (either side can ask), not a one-way impl → spec flow.
- GitHub as the host (GitLab would work the same way with `glab`; not built now).
- The check cadence: at session start, opt-in `/loop` while working, GitHub notifications otherwise.
- Packaging as a plugin in `claudeComm`.
- The asker closes the issue.
- Approval enforced by a PreToolUse hook scoped to the mailbox repo, not just by permission settings.
- Config is per project; the plugin stays silent in projects without it.
- The plugin is distributed from the private mailbox repo itself.

## Success looks like

A spec gap found in the morning gets one approved question and one approved answer through the mailbox, and the asking Claude applies it, with the two developers never having to talk about how to phrase things for each other's Claude.

## Future (not now)

If the issues-based flow is too clunky, the same templates and states can move behind a small free-tier remote MCP server (e.g. a Cloudflare Worker) exposing `post_question`, `inbox`, `reply` and `close` as native tools.
