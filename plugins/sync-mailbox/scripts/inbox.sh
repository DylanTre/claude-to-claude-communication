#!/usr/bin/env bash
# inbox.sh <repo> <role> [provider] [host]
# Prints one line per inbox item: <number>\t<kind>\t<title>, sorted by number.
#   answer   = for:<role> + status:awaiting-answer   (question to answer)
#   review   = from:<role> + status:answered         (answer to review/apply)
#   followup = from:<role> + status:needs-info       (the other side asked back)
# provider is github (default, uses gh) or gitlab (uses glab against host).
# Exit 2 with no stdout if the CLI is missing or fails, or the input is unsafe.
repo="$1"; role="$2"; provider="${3:-github}"; host="${4:-gitlab.com}"
case "$role" in ''|*[!A-Za-z0-9_-]*) exit 2;; esac

github_inbox() {
  command -v gh >/dev/null 2>&1 || exit 2
  local filter out
  filter='def has($x): any(.[]; . == $x);
[ .[] | [.labels[].name] as $l
  | (if ($l|has("for:ROLE")) and ($l|has("status:awaiting-answer")) then "answer"
     elif ($l|has("from:ROLE")) and ($l|has("status:answered")) then "review"
     elif ($l|has("from:ROLE")) and ($l|has("status:needs-info")) then "followup"
     else empty end) as $k
  | {n: .number, k: $k, t: (.title | gsub("[\t\r\n]"; " "))} ]
| sort_by(.n) | .[] | "\(.n)\t\(.k)\t\(.t)"'
  filter="${filter//ROLE/$role}"
  out="$(gh issue list --repo "$repo" --state open --limit 200 --json number,title,labels --jq "$filter")" || exit 2
  [ -n "$out" ] && printf '%s\n' "$out"
}

# gitlab_kind <kind> <label> <label>: one GraphQL query for open issues having
# both labels; prints <iid>\t<kind>\t<title> lines. glab has no jq, so the query
# asks only for iid and title, which this parses with sed.
gitlab_kind() {
  local kind="$1" query resp
  query="{ project(fullPath: \"$repo\") { issues(state: opened, labelName: [\"$2\",\"$3\"], first: 100) { nodes { iid title } } } }"
  resp="$(glab api --hostname "$host" graphql -f query="$query")" || return 1
  resp="$(printf '%s' "$resp" | tr -d '\n\r')"
  printf '%s' "$resp" | grep -qE '"errors"[[:space:]]*:|"project"[[:space:]]*:[[:space:]]*null' && return 1
  printf '%s' "$resp" | grep -qE '"project"[[:space:]]*:' || return 1
  printf '%s' "$resp" \
    | grep -oE '"iid"[[:space:]]*:[[:space:]]*"[0-9]+"[[:space:]]*,[[:space:]]*"title"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
    | sed -E "s/^\"iid\"[[:space:]]*:[[:space:]]*\"([0-9]+)\"[[:space:]]*,[[:space:]]*\"title\"[[:space:]]*:[[:space:]]*\"(.*)\"$/\\1	$kind	\\2/" \
    | sed -e 's/\\[ntr]/ /g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
  return 0
}

gitlab_inbox() {
  command -v glab >/dev/null 2>&1 || exit 2
  case "$repo" in ''|*[!A-Za-z0-9_./-]*) exit 2;; esac
  case "$host" in *[!A-Za-z0-9_.:-]*) exit 2;; esac
  local out
  out="$( gitlab_kind answer "for:$role" status:awaiting-answer \
       && gitlab_kind review "from:$role" status:answered \
       && gitlab_kind followup "from:$role" status:needs-info )" || exit 2
  [ -n "$out" ] && printf '%s\n' "$out" | sort -t '	' -k1,1n
}

case "$provider" in
  github) github_inbox;;
  gitlab) gitlab_inbox;;
  *) exit 2;;
esac
exit 0
