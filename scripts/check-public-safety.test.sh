#!/usr/bin/env bash
set -euo pipefail

# Fixture-style expectations for scripts/check-public-safety.sh. Run before
# changing any pattern in that script to confirm allowed placeholder
# examples still pass and known-risky examples still block.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
real_script="$script_dir/check-public-safety.sh"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

git -C "$workdir" init -q
mkdir -p "$workdir/scripts"
cp "$real_script" "$workdir/scripts/check-public-safety.sh"
chmod +x "$workdir/scripts/check-public-safety.sh"

fail=0

run_check() {
	(cd "$workdir" && ./scripts/check-public-safety.sh) >/tmp/nixy-cps-test-out 2>&1
}

assert_pass() {
	local name=$1 content=$2
	printf '%s\n' "$content" >"$workdir/fixture.md"
	git -C "$workdir" add -A
	if run_check; then
		echo "ok (allowed): $name"
	else
		echo "FAIL (expected allowed, was blocked): $name"
		cat /tmp/nixy-cps-test-out
		fail=1
	fi
}

assert_fail() {
	local name=$1 content=$2
	printf '%s\n' "$content" >"$workdir/fixture.md"
	git -C "$workdir" add -A
	if run_check; then
		echo "FAIL (expected blocked, was allowed): $name"
		cat /tmp/nixy-cps-test-out
		fail=1
	else
		echo "ok (blocked): $name"
	fi
}

assert_pass "placeholder op:// reference" \
	'EXAMPLE_VALUE=op://<vault>/<item>/<field>'

assert_pass "prose mentioning op:// without a real reference" \
	'Never resolve op:// references during Nix evaluation.'

assert_pass "nixy-priv repo name alone" \
	'See the nixy-priv repository for real hosts.'

assert_pass "generic 1Password docs URL" \
	'See https://developer.1password.com/docs/cli/get-started/'

assert_fail "realistic op:// reference" \
	'EXAMPLE_VALUE=op://Engineering/github-pat/credential'

assert_fail "1Password account sign-in URL" \
	'Sign in at acme-corp.1password.com/signin'

assert_fail "real email" \
	'Contact robby@gmail.com for access.'

assert_fail "private key block" \
	'-----BEGIN OPENSSH PRIVATE KEY-----'

assert_fail "token assignment" \
	'API_TOKEN=abc123'

assert_fail "uppercase env-var-style secret assignment" \
	'MY_SECRET=abc123'

rm -f "$workdir/fixture.md"
git -C "$workdir" add -A

if [[ $fail -ne 0 ]]; then
	echo "check-public-safety.test.sh: FAILED"
	exit 1
fi

echo "check-public-safety.test.sh: all fixtures passed"
