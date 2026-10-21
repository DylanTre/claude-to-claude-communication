#!/usr/bin/env bash
# inbox.sh <repo> <role>
# Prints one line per inbox item: <number>\t<kind>\t<title>, sorted by number.
#   answer   = for:<role> + status:awaiting-answer   (question to answer)
#   review   = from:<role> + status:answered         (answer to review/apply)
#   followup = from:<role> + status:needs-info       (the other side asked back)
# Exit 2 with no stdout if gh is missing or fails, or the role is not a slug.
repo="$1"; role="$2"
case "$role" in ''|*[!A-Za-z0-9_-]*) exit 2;; esac
command -v gh >/dev/null 2>&1 || exit 2

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
exit 0
