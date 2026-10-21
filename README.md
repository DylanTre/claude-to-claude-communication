# claude-sync: a mailbox between two Claude Code instances

`sync-mailbox` is a Claude Code plugin. It lets two developers' Claude instances exchange structured questions and answers through a private GitHub repo or GitLab project. A human approves every message before it is posted.

It was built for a common split:

- the **spec side** writes the high-level specification with their Claude;
- the **implementation side** owns architecture and code with their Claude.

The implementation-side Claude reads the code, so it's usually the first to notice when the spec allows something it shouldn't. Without this plugin, that finding goes Claude → developer → colleague → colleague's Claude, and details get lost at every hand-off. With it, the finding goes straight from one Claude to the other in full, and each human reviews and approves what is said on their behalf.

---

## Contents

1. [How it works](#how-it-works)
2. [Prerequisites](#prerequisites)
3. [Setup from scratch](#setup-from-scratch)
   - [Path A: GitHub mailbox](#path-a-github-mailbox)
   - [Path B: GitLab mailbox](#path-b-gitlab-mailbox) (incl. self-hosted)
   - [One-time setup: details](#one-time-setup-details)
4. [Daily usage](#daily-usage)
5. [Commands in detail](#commands-in-detail)
6. [Checking the inbox periodically](#checking-the-inbox-periodically)
7. [What a good question looks like](#what-a-good-question-looks-like)
8. [Labels and the life of a question](#labels-and-the-life-of-a-question)
9. [Safety: approvals and permissions](#safety-approvals-and-permissions)
10. [Configuration reference](#configuration-reference)
11. [Updating the plugin](#updating-the-plugin)
12. [Troubleshooting](#troubleshooting)
13. [FAQ](#faq)
14. [Development](#development)

---

## How it works

```
 implementation side               GitHub or GitLab (private)                  spec side
 ───────────────────                   ─────────────────────                    ─────────
 Claude finds a spec gap
 you validate the root cause
 /sync-ask ──(you approve)──────────▶  issue #12  for:spec
                                       status:awaiting-answer
                                                                ◀── session start: "1 to answer [#12]"
                                                                    /sync-inbox  (summary + draft answer)
                                       comment: Decision…       ◀── /sync-reply 12 ──(colleague approves)
                                       status:answered
 session start: "1 answer to review"
 Claude applies the answer (you agree)
 /sync-close 12 ──(you approve)─────▶  issue closed
```

- **The mailbox** is one private GitHub repo or GitLab project (gitlab.com or your own server). It holds no code. Its **Issues** are the messages.
- **One issue is one question thread.** The question is the issue body, and answers and follow-ups are comments.
- **Labels** say who has to act and what state the question is in (see [Labels](#labels-and-the-life-of-a-question)).
- **Either side can ask.** The spec side can also ask the implementation side, for example "is this feasible?".
- Claude does all mailbox access through the official command-line tool, `gh` for GitHub or `glab` for GitLab, logged in as you.

---

## Prerequisites

The mailbox can live on **GitHub** or on a **GitLab** server, including your company's own self-hosted GitLab. Both developers need:

| What | GitHub mailbox | GitLab mailbox |
|---|---|---|
| An account | on github.com | on your GitLab server |
| Claude Code | ✓ | ✓ |
| Git (on Windows: Git for Windows, which includes Git Bash) | ✓ | ✓ |
| The command-line tool, logged in | GitHub CLI, `gh` | GitLab CLI, `glab` |
| Access to the mailbox | collaborator on the repo | project member, **Reporter** or higher |
| Network | internet | must reach the GitLab server (office network or VPN if it's internal) |

[Setup from scratch](#setup-from-scratch) walks through every step for both.

---

## Setup from scratch

### The two repos

| Repo | What it holds | Where |
|---|---|---|
| **Plugin repo**: [`DylanTre/claude-to-claude-communication`](https://github.com/DylanTre/claude-to-claude-communication) | this plugin's code; Claude Code installs from it | public on GitHub, so anyone can install it, even GitLab-only teams; no GitHub account is needed |
| **Mailbox** | only the issues (the messages) for one collaboration | **private**, on GitHub *or* GitLab: your choice |

Create one mailbox per collaboration, for example per feature or per pair of people. Each project on your machine points to one mailbox, so you can have some on GitHub and some on GitLab.

### Overview: pick a path

| Step | Who | GitHub mailbox | GitLab mailbox |
|---|---|---|---|
| 1. Common tools | both | [Part 1](#part-1-common-tools-both-developers) | [Part 1](#part-1-common-tools-both-developers) |
| 2. CLI and mailbox | both, plus the owner | [Path A: GitHub](#path-a-github-mailbox) | [Path B: GitLab](#path-b-gitlab-mailbox) |
| 3. Plugin and configuration | both | [Part 3](#part-3-install-the-plugin-and-configure-both-developers) | [Part 3](#part-3-install-the-plugin-and-configure-both-developers) |

Both developers must use the **same** mailbox, so agree on the path first.

### Part 1. Common tools (both developers)

**1.1 Git.**
- Windows: install *Git for Windows* from https://git-scm.com/download/win with the default options. This also installs **Git Bash**, which Claude Code and this plugin use.
- macOS: run `xcode-select --install`, or `brew install git`.
- Linux: use your package manager, for example `sudo apt install git`.

**1.2 Claude Code.**
- Windows (PowerShell): `irm https://claude.ai/install.ps1 | iex`
- macOS / Linux: `curl -fsSL https://claude.ai/install.sh | bash`

Then run `claude` once and log in. Full instructions: https://docs.claude.com/en/docs/claude-code/setup

Now follow **either** Path A **or** Path B.

### Path A: GitHub mailbox

**A1. Install the GitHub CLI** (both developers).
- Windows: `winget install --id GitHub.cli`
- macOS: `brew install gh`
- Linux: see https://github.com/cli/cli#installation

Open a **new** terminal afterwards, so `gh` is on your PATH.

**A2. Log `gh` in** (both developers).
```
gh auth login
```
Choose *GitHub.com*, then *SSH* or *HTTPS* (either works), then *Login with a web browser*, and follow the prompts. Check that it worked:
```
gh auth status
```
It should say *Logged in to github.com account <you>*, and the token scopes should include `repo`.

**A3. Create a private mailbox repo** (the owner, once per collaboration). It holds no code.
```
gh repo create <owner>/feature-x-sync --private --description "Claude sync mailbox for feature X"
```
(Or use the website: *New repository → Private*.)

**A4. Invite your colleague** (the owner).
```
gh api -X PUT repos/<owner>/feature-x-sync/collaborators/<their-github-username> -f permission=push
```
(Or on the website: *Settings → Collaborators → Add people*.)

**A5. Accept the invitation** (the colleague), either from the email GitHub sends or at `https://github.com/<owner>/feature-x-sync/invitations`. Until they accept, they can't see the repo.

**A6. Agree on the details:** the mailbox name (`<owner>/feature-x-sync`) and who takes which role, normally `impl` for the implementation side and `spec` for the spec side.

The labels get created during configuration (Part 3), so continue with [Part 3](#part-3-install-the-plugin-and-configure-both-developers).

### Path B: GitLab mailbox

Use this to keep the conversation on your own servers. It works with gitlab.com and with self-hosted GitLab. The examples use `gitlab.yourcompany.com`.

**B1. Install the GitLab CLI, `glab`** (both developers).
- Windows: `winget install --id GLab.GLab`
- macOS: `brew install glab`
- Linux: see https://gitlab.com/gitlab-org/cli#installation

Open a **new** terminal afterwards, so `glab` is on your PATH.

**B2. Create a personal access token** (both developers). In GitLab, go to *your avatar → Preferences → Access tokens → Add new token*, tick the **`api`** scope, set an expiry date, and copy the token.

**B3. Log `glab` in to your server** (both developers).
```
glab auth login --hostname gitlab.yourcompany.com
```
Paste the token when asked. Check that it worked:
```
glab auth status --hostname gitlab.yourcompany.com
```

**B4. Check you can reach the server** (both developers, especially whoever works remotely). If your GitLab is only reachable on the office network or VPN, the remote side needs that connection whenever they use the mailbox. Without it, the session-start notice says *"could not reach GitLab … (offline, VPN, or not logged in?)"*.

**B5. Create a private mailbox project** (the owner, once per collaboration). In GitLab, choose *New project → Create blank project*, set **Visibility: Private**, and leave Issues enabled. For example: `team/sync/feature-x-sync`. It holds no code.

**B6. Add your colleague** (the owner). Go to *Manage → Members → Invite members* and choose the role **Reporter** or higher. Reporter is enough to open issues, comment, and change labels.

**B7. Agree on the details:** the host (`gitlab.yourcompany.com`), the project path (`team/sync/feature-x-sync`), and who takes which role (`impl` / `spec`).

Continue with Part 3.

### Part 3. Install the plugin and configure (both developers)

**3.1 Install the plugin.** In Claude Code (any folder):
```
/plugin marketplace add DylanTre/claude-to-claude-communication
/plugin install sync-mailbox@claude-sync
```
Then exit and restart Claude Code. The plugin is installed for your user, but it does nothing in a project until step 3.2. It comes from the public GitHub repo for both paths.

> To try out a local copy instead, use `/plugin marketplace add <path to a clone of this repo>`.

**3.2 Configure each project.** Run `/sync-setup` and answer the questions. See [Configure each project](#configure-each-project) for details.

| Question | Path A: GitHub | Path B: GitLab |
|---|---|---|
| Where is the mailbox? | GitHub | GitLab |
| Host | — | `gitlab.yourcompany.com` |
| Mailbox repo | `<owner>/feature-x-sync` | `team/sync/feature-x-sync` |
| Your role / the other role | `impl` / `spec` (or the reverse) | same |

**3.3 Turn on notifications.** See [Turn on notifications](#turn-on-notifications).

**3.4 Smoke test,** about 2 minutes:
1. Implementation side: `/sync-ask this is a setup test, invent a trivial question`, approve it, and note the issue number.
2. Spec side: restart Claude Code. The session-start notice should mention the issue. Then run `/sync-reply <n>` and approve.
3. Implementation side: restart. The notice should say *1 answers to review*. Then run `/sync-close <n>`.

If all three work, you're done.

---

## One-time setup: details

### Configure each project

Open Claude Code in the project where you work on the feature (the implementation side in the code repo; the spec side wherever the spec lives) and run:

```
/sync-setup
```

It will:

1. ask where the mailbox lives (GitHub or GitLab, plus the host for GitLab), the mailbox repo (`acme/feature-x-sync` or `team/sync/feature-x-sync`), your role (`impl` or `spec`), and the other side's role,
2. check that `gh` or `glab` is installed and logged in (for GitLab, to that host),
3. write `.claude/sync-mailbox.env` in the project,
4. add that file to `.git/info/exclude` so it is never committed (your `.gitignore` is not touched),
5. check that the mailbox is reachable,
6. create the mailbox labels, after asking you (only needed once per mailbox, safe to repeat).

Repeat this in every project where you want the mailbox active. Projects without the config are completely unaffected.

### Turn on notifications

So you hear about new messages even when Claude Code is closed:

- **GitHub:** on the mailbox repo, choose *Watch → All activity*.
- **GitLab:** on the mailbox project, click the bell icon and choose *Watch*.

---

## Daily usage

### When you have a question for the other side

1. Work normally. When Claude finds something the spec doesn't cover, or covers wrongly, investigate it with Claude until you agree on the root cause.
2. Run `/sync-ask` (or just say *"ask the spec side about this"*).
3. Review the draft Claude shows you. Edit anything, then approve.
4. Claude posts it and gives you the issue link. Carry on with other work.

### When something is waiting for you

- At **session start** Claude tells you, for example: *"Sync mailbox: 2 to answer [#12, #14], 1 answers to review [#9]."*
- Run `/sync-inbox` for a summary of each item, with draft answers.
- Answer with `/sync-reply <n>`, or apply a received answer and close it with `/sync-close <n>`.

### Cheat sheet

| I want to… | Command | Plain-language alternative |
|---|---|---|
| set up a project | `/sync-setup` | "set up the sync mailbox here" |
| ask the other side | `/sync-ask [topic]` | "ask the spec side about the retry limit" |
| see what's waiting | `/sync-inbox` | "check the sync inbox" |
| answer or ask back | `/sync-reply <n>` | "answer mailbox question 12" |
| close an applied answer | `/sync-close <n>` | "close mailbox question 12, it's applied" |
| check automatically | `/loop 30m /sync-inbox` | — |

> If a command name clashes with another plugin, use the full name, for example `/sync-mailbox:sync-inbox`.

---

## Commands in detail

### `/sync-setup`

One-time setup per project; see [Configure each project](#configure-each-project). Run it again whenever you want to check the setup, change the mailbox repo, or change your role. If a config already exists it shows it and asks before changing anything.

### `/sync-ask [topic]`

Drafts a question for the other side and posts it after your approval.

- **`topic`** is optional. Without it, Claude uses whatever you were just discussing.
- Claude fills the [question template](#what-a-good-question-looks-like) from the session and the code: the observation, the root cause, links to the code at the current commit, the exact spec passage, the options, and its recommendation.
- If something essential is missing, for example the root cause isn't settled yet, Claude asks you instead of guessing.
- It asks whether the question is **blocking** your work, and if so adds the `blocking` label so it goes to the top of the other side's inbox.
- It shows you the full title, body, labels, and the exact `gh`/`glab` command, and waits. Nothing is posted until you say yes.

### `/sync-inbox`

Shows what's waiting for you. **It never posts anything.**

Items are sorted with blocking ones first, in three kinds:

| Kind | Meaning | What Claude does |
|---|---|---|
| **answer** | a question addressed to you | summarizes it, reads the spec and code it references, and offers a draft answer, plus a spec change if one is needed |
| **review** | your question was answered | summarizes the decision and proposes how to apply it to your current work |
| **followup** | the other side asked you something back | explains what they need |

### `/sync-reply <n>`

Drafts and posts a reply on issue `n`. Claude works out what kind of reply is needed from the labels:

| Situation | Reply | Status after |
|---|---|---|
| a question for you | an answer (decision, rationale, spec change, follow-ups) | `status:answered` |
| a question for you that you can't answer yet | a follow-up question | `status:needs-info` |
| the other side asked you back (`needs-info`) | your clarification | `status:awaiting-answer` |

You see the exact comment and label change before anything is posted. If the answer needs a spec change on your side, Claude offers to make it afterwards as a separate step in your normal workflow.

### `/sync-close <n>`

Closes a question once its answer has been applied.

- Only the person who **asked** closes it.
- Claude asks you to confirm the answer was applied, then shows a one-line closing comment ("Applied in …") for your approval.

---

## Checking the inbox periodically

There are three layers, from least to most effort:

| When | How | Setup |
|---|---|---|
| Claude Code is closed | GitHub or GitLab notifications | GitHub: *Watch → All activity*; GitLab: bell icon → *Watch* |
| A session starts | automatic notice | none, it's built in |
| During a long session | `/loop` | type it once per session |

### Using `/loop`

```
/loop 30m /sync-inbox
```

- Claude runs `/sync-inbox` every 30 minutes for as long as that session is open. Use any interval, such as `15m`, `1h`, or `2h`; every 30 to 60 minutes is usually enough.
- It **only lasts for the session.** It stops when you exit, and you start it again next time. That's intentional: it runs only while someone is there to approve replies.
- It **never posts**. It only reads and drafts.
- To stop it early, ask Claude to stop the loop, or press Esc while it runs.

**Quieter variant.** `/sync-inbox` reports even when the inbox is empty. To hear only when something has arrived:

```
/loop 30m check the sync mailbox with the inbox script; if it's empty, say nothing
```

---

## What a good question looks like

The point of the mailbox is that the other Claude can act **without the two of you having to talk**. Every question follows this template:

```markdown
**Question:** May an upload be retried indefinitely, or is there a limit?

**What we observed:** A failing upload is retried forever; the client never surfaces an error.

**Root cause:** Spec §4.2 says "failed uploads are retried" with no limit or backoff.

**Code evidence:**
- https://github.com/acme/app/blob/3f2c1a9/src/upload/retry.ts#L40-L52: the retry loop
  ```ts
  while (!ok) { ok = await tryUpload(file); }
  ```

**Spec reference:** acme/spec/upload.md@8d1e0b2#retries
> Failed uploads are retried.

**Options:**
1. Fixed limit (e.g. 5) then error: simple; user sees failures quickly.
2. Exponential backoff up to 1 h: resilient; failures surface late.

**Recommendation:** Option 1 with a limit of 5; it matches the error UX already in §6.

**Blocking?** Yes, the upload error screen depends on it.
```

Answers follow a short template:

```markdown
**Decision:** Option 1, limit 5, with 2 s / 4 s / 8 s / 16 s backoff.
**Rationale:** …
**Spec change:** §4.2 now reads "…" (spec repo, commit 91ab3c0)
**Follow-ups:** Show the error screen from §6 after the 5th failure.
```

Rules Claude follows when writing questions:

- **Code evidence is a link to a fixed commit**, plus a short preview of at most about 15 lines. Never whole files. Both sides can open the code repo, so the link is what counts.
- **Never** secrets, tokens, credentials, personal data, or `.env` contents.
- No shorthand only one side understands, and no "as discussed".

---

## Labels and the life of a question

| Label | Meaning |
|---|---|
| `for:impl` / `for:spec` | who must answer |
| `from:impl` / `from:spec` | who asked |
| `status:awaiting-answer` | waiting on whoever must answer |
| `status:needs-info` | the answerer asked a follow-up; waiting on the asker |
| `status:answered` | answer posted; the asker should review and apply it |
| `blocking` | the asker is blocked until this is answered |
| *(issue closed)* | resolved |

```
            /sync-ask                   /sync-reply (answer)                 /sync-close
  (new) ──────────────▶ awaiting-answer ─────────────────────▶ answered ─────────────▶ closed
                          │      ▲
     /sync-reply          │      │  /sync-reply
     (follow-up question) ▼      │  (asker clarifies)
                         needs-info
```

**Your inbox** is every open issue where:
- it's `for:<you>` and `status:awaiting-answer` → you need to answer; or
- it's `from:<you>` and `status:answered` → you need to review and apply; or
- it's `from:<you>` and `status:needs-info` → you need to clarify.

You can also read and browse everything on GitHub or GitLab as normal.

---

## Safety: approvals and permissions

**Rule:** Claude never posts, comments, changes labels, or closes anything in the mailbox without your explicit approval of that exact text and action.

It's enforced in two independent ways:

1. **In conversation:** the plugin's instructions require Claude to show you the exact text and command and wait for a yes, and to show it again after any edit.
2. **In Claude Code itself:** a `PreToolUse` hook catches any `gh` or `glab` write aimed at the mailbox (`issue create/comment/note/edit/update/close/…`, label changes, `api`, repo admin) and forces a permission prompt, even if your settings would normally allow the command. Commands against other repos are not affected.

Recommended settings:

- It's fine to allow reads: `Bash(gh issue list:*)`, `Bash(gh issue view:*)`, `Bash(glab issue list:*)`, `Bash(glab issue view:*)`.
- **Don't** add `gh` or `glab` writes to your allow-list.

Whether the forced prompt appears in each permission mode:

| Mode | Prompt appears? |
|---|---|
| default | yes (verified end to end) |
| auto | not verified |
| bypass permissions | not verified: Claude Code may skip all prompts in this mode, so rely on the in-conversation approval |

---

## Configuration reference

Per project, in `.claude/sync-mailbox.env` (written by `/sync-setup`, never committed):

```
SYNC_MAILBOX_REPO=acme/feature-x-sync
SYNC_MAILBOX_ROLE=impl
```

GitLab example:

```
SYNC_MAILBOX_PROVIDER=gitlab
SYNC_MAILBOX_HOST=gitlab.yourcompany.com
SYNC_MAILBOX_REPO=team/sync/feature-x-sync
SYNC_MAILBOX_ROLE=impl
```

| Key | Meaning |
|---|---|
| `SYNC_MAILBOX_REPO` | the mailbox repo: `owner/name` on GitHub, `group/subgroup/project` on GitLab |
| `SYNC_MAILBOX_ROLE` | your role; letters, digits, `-` and `_` only. Usually `impl` or `spec` |
| `SYNC_MAILBOX_PROVIDER` | `github` (default) or `gitlab` |
| `SYNC_MAILBOX_HOST` | GitLab only: your server, for example `gitlab.yourcompany.com` (default `gitlab.com`) |

- `#` comment lines and blank lines are allowed. Windows line endings are fine.
- No file means the plugin is inactive in that project: no notice, no guard, no network calls.
- A project points to exactly one mailbox. If you work on several features in different projects, configure each one.
- Roles other than `impl` and `spec` work too. Use the same two roles on both sides, and pass both to `/sync-setup` so the matching labels exist.

---

## Updating the plugin

Maintainer:
1. Bump `version` in `plugins/sync-mailbox/.claude-plugin/plugin.json`.
2. Commit and push to the plugin repo (`DylanTre/claude-to-claude-communication`).

Both developers:
```
/plugin marketplace update claude-sync
/plugin update sync-mailbox@claude-sync
```
Then restart Claude Code.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| *"Sync mailbox: could not reach GitHub via gh…"* at session start | offline, `gh` not installed, or not logged in | `gh auth status`; `gh auth login`; then `/sync-setup` to check |
| No notice at session start, but you expect items | no config in this project, or the labels are wrong on the issue | check `.claude/sync-mailbox.env`; on GitHub/GitLab, make sure the issue has `for:<you>` plus a status label |
| *"Sync mailbox: could not reach GitLab (host) via glab…"* at session start | off the company network/VPN, `glab` not installed, or not logged in to that host | connect to the network; `glab auth status --hostname <host>`; `glab auth login --hostname <host>` |
| `/sync-setup` says the mailbox isn't reachable | typo, or you're not a collaborator / project member | GitHub: `gh repo view owner/name`; GitLab: open `https://<host>/<group>/<project>` in a browser; ask the owner to add you |
| GitLab token stopped working | the personal access token expired | create a new token with the `api` scope and run `glab auth login --hostname <host>` again |
| `/sync-inbox` not found | name clash with another plugin, or the plugin isn't installed | use `/sync-mailbox:sync-inbox`; check `/plugin` |
| Label errors when posting | labels never created in this mailbox | run `/sync-setup` and approve the label step |
| Scripts fail with `$'\r': command not found` | the plugin files got Windows line endings | re-clone; the repo's `.gitattributes` forces LF on scripts |
| An item stays in your inbox after you answered | the status label wasn't switched | on GitHub/GitLab, replace `status:awaiting-answer` with `status:answered` |

---

## FAQ

**Can the two Claudes talk to each other on their own?**
No, by design. Every outgoing message is approved by its human. The mailbox removes the relaying between people, not their oversight.

**Does the spec have to be in the same repo as the code?**
No. Questions reference the spec by location, whether that's a path at a commit in any repo or a document URL plus section. The spec side runs `/sync-setup` wherever they work on the spec.

**What if the spec change is big?**
The mailbox carries the *decision*. The spec side makes the actual edit in their normal workflow and links it in the answer's "Spec change" field.

**Can we use GitLab instead?**
Yes, including a self-hosted GitLab, so conversations stay on your servers. See [Path B: GitLab mailbox](#path-b-gitlab-mailbox). The choice is made per project, so you can mix GitHub and GitLab mailboxes.

**Is our code sent anywhere new?**
Only the short previews and links you approve in each question, posted to your own private repo.

---

## Development

```
.claude-plugin/marketplace.json        marketplace "claude-sync"
plugins/sync-mailbox/
  .claude-plugin/plugin.json           plugin manifest (version lives here)
  hooks/hooks.json                     SessionStart notice + PreToolUse write guard
  scripts/lib.sh                       config loader
  scripts/inbox.sh                     inbox query (one gh call)
  scripts/session-start.sh             session-start notice
  scripts/guard-writes.sh              forces a prompt on mailbox writes
  scripts/setup-labels.sh              creates/updates labels
  skills/sync-mailbox/SKILL.md         rules and templates Claude follows
  commands/*.md                        the five slash commands
tests/                                 bash tests with a fake gh
docs/                                  design spec and implementation plan
```

- Run the tests: `bash tests/run.sh`. They need bash and the standalone `jq`, which the fake `gh` uses (the fake `glab` needs nothing extra).
- Validate the plugin: `claude plugin validate .`
