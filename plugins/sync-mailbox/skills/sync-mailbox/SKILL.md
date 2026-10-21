---
name: sync-mailbox
description: Exchange human-approved questions and answers with the other side of a feature (spec author or implementer) through the shared GitHub or GitLab Issues mailbox. Use when the user says "ask the spec side", "ask the impl side", "post this to the mailbox", "check the sync inbox", "answer the question from the other side", when a session-start note says the sync mailbox has items, or when you find a spec gap the other side must decide.
---

# Sync mailbox

Two developers, each with their own Claude Code, share a private GitHub repo whose Issues are a mailbox. One issue = one question thread. You draft; your human approves; only then do you post.

## Config

Read `.claude/sync-mailbox.env` in the project root:

```
SYNC_MAILBOX_REPO=<owner/name, or group/subgroup/project on GitLab>
SYNC_MAILBOX_ROLE=<my role slug, e.g. impl or spec>
SYNC_MAILBOX_PROVIDER=<github (default) or gitlab>
SYNC_MAILBOX_HOST=<GitLab host, e.g. gitlab.example.com; default gitlab.com; unused for github>
```

If it is missing, stop and point the user to `/sync-setup`. The other side's role is the other slug used on the repo's `for:` labels (normally `impl` and `spec`).

Scripts live in the plugin's `scripts/` directory, two levels above this skill's base directory:
- `inbox.sh <repo> <role> <provider> <host>` prints lines `<number>\t<kind>\t<title>`, kind = `answer` | `review` | `followup`; exit 2 means the CLI is unavailable or the mailbox unreachable.
- `setup-labels.sh <repo> <role_a> <role_b> <provider> <host>`

## Provider commands

GitHub uses `gh`; GitLab uses `glab`. On GitLab, `<R>` is `https://<SYNC_MAILBOX_HOST>/<SYNC_MAILBOX_REPO>` (a full URL, so the right server is used); issue numbers are the project-level `#iid`.

| Action | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| view with comments | `gh issue view <n> --repo <repo> --comments` | `glab issue view <n> -R <R> --comments` |
| create | `gh issue create --repo <repo> --title <t> --body-file <f> --label a --label b` | `glab issue create -R <R> --title <t> --description-file <f> --label a,b --yes` |
| comment | `gh issue comment <n> --repo <repo> --body-file <f>` | `glab issue note <n> -R <R> --message "$(cat <f>)"` |
| change labels | `gh issue edit <n> --repo <repo> --remove-label a --add-label b` | `glab issue update <n> -R <R> --unlabel a --label b` |
| close with comment | `gh issue close <n> --repo <repo> --comment <c>` | `glab issue note <n> -R <R> --message <c>` then `glab issue close <n> -R <R>` |
| auth check | `gh auth status` | `glab auth status --hostname <host>` |

Every row with a write is subject to the approval rule below.

## The approval rule (never break it)

Before ANY `gh`/`glab` write (issue create, comment/note, edit/update including label changes, close, `api` writes), show the user the exact text and the exact command, and wait for an explicit yes for that action. If they edit, show the result again and wait again. Approval covers only what you showed. A plugin hook also makes Claude Code prompt for these commands; that prompt does not replace asking in conversation.

Reads (`issue list`, `issue view`) need no approval.

## How to post

- Use the [provider commands](#provider-commands) for `SYNC_MAILBOX_PROVIDER`.
- Always pass the repo explicitly (`--repo <repo>` on GitHub, `-R https://<host>/<repo>` on GitLab); never rely on the current directory.
- Write bodies to a temp file and pass it as in the table (`--body-file`, `--description-file`, or `--message "$(cat <file>)"`); this avoids quoting and line-ending problems. Delete the temp file afterwards.
- Issue title: `[<area>] <one-line question>`.
- New question labels: `for:<other>`, `from:<me>`, `status:awaiting-answer`, plus `blocking` if the user says so.

## Labels and the inbox

| Label | Meaning |
|---|---|
| `for:<role>` | who must answer |
| `from:<role>` | who asked |
| `status:awaiting-answer` | waiting on the addressee |
| `status:needs-info` | addressee asked a follow-up; waiting on the asker |
| `status:answered` | answer posted; asker should review and apply |
| `blocking` | asker is blocked until answered |
| closed issue | resolved; the asker closes it after applying the answer |

My inbox = open issues with (`for:<me>` AND `status:awaiting-answer`) OR (`from:<me>` AND (`status:answered` OR `status:needs-info`)). Keep exactly one `status:` label: when changing status, remove the old one in the same label-change command.

## Question template (issue body)

````markdown
**Question:** <the exact decision needed, phrased so it can be answered directly>

**What we observed:** <the concrete behavior or scenario the spec allows>

**Root cause:** <why the spec permits it: the human-validated analysis>

**Code evidence:**
- <permalink pinned to a commit SHA>: <what it shows>
  ```<lang>
  <short preview, at most ~15 lines>
  ```

**Spec reference:** <repo/path@sha#section, or doc URL + section name>
> <quoted passage>

**Options:**
1. <option>: <consequences>
2. <option>: <consequences>

**Recommendation:** <what we suggest, and why>

**Blocking?** <yes/no, and what is blocked>
````

## Answer template (comment)

```markdown
**Decision:** <...>

**Rationale:** <...>

**Spec change:** <new or changed text, and where it lives / will live, or "none">

**Follow-ups:** <anything the asker must do or watch for, or "none">
```

Follow-up questions in either direction are plain comments ending with one clear question.

## Evidence and confidentiality

- The other side can open the code repo, so permalinks are the primary evidence. Build them from `git rev-parse HEAD` and the code host's URL format (GitHub: `https://github.com/<owner>/<repo>/blob/<sha>/<path>#L<a>-L<b>`; GitLab: `https://<host>/<group>/<project>/-/blob/<sha>/<path>#L<a>-<b>`). The code host can differ from the mailbox host. Check the commit is pushed (`git branch -r --contains <sha>`); if not, say the links will work once it is pushed.
- Excerpts are short previews, never whole files.
- Never include secrets, tokens, credentials, personal data or `.env` contents. If the evidence involves them, describe instead of quoting.
- Write so the other Claude can act without the humans talking: no undefined shorthand, no "as discussed".

## Applying answers

When an answer arrives, summarise it for your user, propose how to apply it to the current work, and apply it only after they agree. Spec edits on the answering side happen in that side's normal workflow with its human's approval: the mailbox carries the decision, not the edit.
