#!/usr/bin/env bash
# setup-labels.sh <repo> <role_a> <role_b> [provider] [host]
# Creates (or, on GitHub, updates) every label the mailbox uses. Idempotent:
# on GitLab an already existing label counts as success.
repo="$1"; a="$2"; b="$3"; provider="${4:-github}"; host="${5:-gitlab.com}"
if [ -z "$repo" ] || [ -z "$a" ] || [ -z "$b" ]; then
  echo "usage: setup-labels.sh <repo> <role_a> <role_b> [github|gitlab] [host]" >&2; exit 64
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

# create_label <name> <color> <description>
create_label() {
  local err
  case "$provider" in
    github) gh label create "$1" --repo "$repo" --color "$2" --description "$3" --force >/dev/null;;
    gitlab)
      err="$(glab label create -R "https://$host/$repo" --name "$1" --color "#$2" --description "$3" 2>&1 >/dev/null)" && return 0
      case "$err" in *[Aa]lready*) return 0;; esac
      echo "$err" >&2; return 1;;
    *) echo "setup-labels: unknown provider '$provider'" >&2; return 1;;
  esac
}

for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  if ! create_label "$name" "$color" "$desc"; then
    echo "setup-labels: failed to create label '$name' in $repo" >&2; exit 1
  fi
  echo "label ok: $name"
done
