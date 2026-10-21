#!/usr/bin/env bash
# setup-labels.sh <repo> <role_a> <role_b>
# Creates (or updates, via --force) every label the mailbox uses. Idempotent.
repo="$1"; a="$2"; b="$3"
if [ -z "$repo" ] || [ -z "$a" ] || [ -z "$b" ]; then
  echo "usage: setup-labels.sh <repo> <role_a> <role_b>" >&2; exit 64
fi

labels=(
  "for:$a|1d76db|Question for the $a side to answer"
  "for:$b|1d76db|Question for the $b side to answer"
  "from:$a|c5def5|Asked by the $a side"
  "from:$b|c5def5|Asked by the $b side"
  "status:awaiting-answer|fbca04|Waiting on the addressee"
  "status:needs-info|d93f0b|Addressee asked a follow-up; waiting on the asker"
  "status:answered|0e8a16|Answer posted; asker should review and apply"
  "blocking|b60205|Asker is blocked until this is answered"
)
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  if ! gh label create "$name" --repo "$repo" --color "$color" --description "$desc" --force >/dev/null; then
    echo "setup-labels: failed to create label '$name' in $repo" >&2; exit 1
  fi
  echo "label ok: $name"
done
