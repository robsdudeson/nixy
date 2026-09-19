#!/usr/bin/env bash
set -euo pipefail

allowed_private_repo='nixy-priv'

mapfile -t files < <(
  {
    git ls-files
    git ls-files --others --exclude-standard
  } | sort -u | grep -vE '^(\.git/|result($|-))'
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files to scan."
  exit 0
fi

status=0

declare -a checks=(
  'private flake URL::(git\+ssh://|git\+https://|ssh://).*(private|priv|work|corp|company)'
  'local user path::/Users/(rd|robby|robsdudeson)(/|$)'
  'token assignment::(token|password|passwd|secret|api[_-]?key|private[_-]?key)\s*[:=]'
  'private key block::-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'real email::[A-Za-z0-9._%+-]+@(gmail\.com|corp|company|work)'
)

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue

  # The plan and docs intentionally name the private overlay repo. That name is
  # safe by itself; private URLs, lock entries, paths, and secrets are not.
  sanitized=$(mktemp)
  sed "s/${allowed_private_repo}/ALLOWED_PRIVATE_REPO/g" "$file" > "$sanitized"

  for check in "${checks[@]}"; do
    label=${check%%::*}
    pattern=${check#*::}
    if grep -EIn "$pattern" "$sanitized" >/tmp/nixy-public-safety-match; then
      echo "Public-safety risk: $label in $file"
      cat /tmp/nixy-public-safety-match
      status=1
    fi
  done

  rm -f "$sanitized"
done

if [[ $status -eq 0 ]]; then
  echo "Public-safety check passed."
else
  echo "Public-safety check failed. Review findings before committing or pushing."
fi

exit "$status"
