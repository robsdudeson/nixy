#!/usr/bin/env bash
set -euo pipefail

allowed_private_repo='nixy-priv'

# Avoid mapfile/readarray: they need bash 4+, but stock macOS ships bash 3.2
# and this script must run before Homebrew (and a newer bash) exist.
files=()
while IFS= read -r file; do
	files+=("$file")
done < <(
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
	'token assignment::(^|[^A-Za-z])(token|password|passwd|secret|api[_-]?key|private[_-]?key)\s*[:=]'
	'private key block::-----BEGIN [A-Z ]*PRIVATE KEY-----'
	'real email::[A-Za-z0-9._%+-]+@(gmail\.com|corp|company|work)'
	'realistic 1Password reference::op://[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+'
	'1Password account sign-in URL::[a-z0-9][a-z0-9-]*\.1password\.com/(signin|vaults|people|activity|item)'
)

for file in "${files[@]}"; do
	[[ -f "$file" ]] || continue
	[[ "$file" == "scripts/check-public-safety.sh" ]] && continue
	[[ "$file" == "scripts/check-public-safety.test.sh" ]] && continue
	# bootstrap.test.sh uses intentional realistic fixtures to verify the check
	# blocks them — same rationale as check-public-safety.test.sh above.
	[[ "$file" == "scripts/bootstrap.test.sh" ]] && continue

	# The plan and docs intentionally name the private overlay repo. That name is
	# safe by itself; private URLs, lock entries, paths, and secrets are not.
	sanitized=$(mktemp)
	sed "s/${allowed_private_repo}/ALLOWED_PRIVATE_REPO/g" "$file" >"$sanitized"

	for check in "${checks[@]}"; do
		label=${check%%::*}
		pattern=${check#*::}
		if grep -EIni -- "$pattern" "$sanitized" >/tmp/nixy-public-safety-match; then
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
