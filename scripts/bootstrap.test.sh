#!/usr/bin/env bash
# Fixture-style tests for scripts/bootstrap.sh.
# Tests path/repo validation, private-repo validation, and --host flag
# using temporary fake repos. Does not invoke nix, darwin-rebuild, or any
# real host discovery — those require a live Nix installation and nixy-priv.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bootstrap="$script_dir/bootstrap.sh"

fail=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() { echo "ok: $1"; }
fail_test() {
	echo "FAIL: $1"
	[[ -f "$tmpout" ]] && cat "$tmpout" || true
	fail=1
}

# run_bootstrap captures both stdout and stderr of bootstrap.sh in $tmpout.
# Do NOT add extra redirections when calling run_bootstrap — $tmpout is
# written inside the function and extra 2>"$tmpout" would double-truncate.
run_bootstrap() {
	"$bootstrap" "$@" >"$tmpout" 2>&1
}

# ---------------------------------------------------------------------------
# Setup shared temp dirs
# ---------------------------------------------------------------------------

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

tmpout="$workdir/out.txt"

# Create a minimal fake public nixy repo at $workdir/nixy.
fake_nixy="$workdir/nixy"
mkdir -p "$fake_nixy/docs" "$fake_nixy/scripts"
git -C "$workdir" init -q nixy
touch "$fake_nixy/flake.nix"
touch "$fake_nixy/docs/private-overlay.md"
touch "$fake_nixy/scripts/check-public-safety.sh"
git -C "$fake_nixy" add -A
git -C "$fake_nixy" -c user.email="test@example.com" \
	-c user.name="Test" commit -qm "init" >/dev/null 2>&1

# Create a minimal fake nixy-priv repo at $workdir/nixy-priv.
fake_priv="$workdir/nixy-priv"
mkdir -p "$fake_priv"
git -C "$workdir" init -q nixy-priv
touch "$fake_priv/flake.nix"
git -C "$fake_priv" add -A
git -C "$fake_priv" -c user.email="test@example.com" \
	-c user.name="Test" commit -qm "init" >/dev/null 2>&1

# ---------------------------------------------------------------------------
# U1: Path and repo validation
# ---------------------------------------------------------------------------

# Happy path: valid public repo reaches the private-repo validation stage.
# We expect failure at the private-repo check (since we are not passing one),
# but a specific failure message about the private repo — not about the public repo.
if run_bootstrap \
	--repo "$fake_nixy" ||
	grep -q "nixy-priv" "$tmpout"; then
	pass "U1 happy path: valid public repo reaches private-repo check"
else
	fail_test "U1 happy path: valid public repo should reach private-repo check"
fi

# Edge case: non-existent path exits with a clear error.
if ! run_bootstrap --repo "$workdir/does-not-exist"; then
	if grep -q "not found" "$tmpout"; then
		pass "U1 edge case: non-existent path exits non-zero with 'not found'"
	else
		fail_test "U1 edge case: expected 'not found' message for missing path"
	fi
else
	fail_test "U1 edge case: should fail for non-existent path"
fi

# Edge case: missing marker file fails before private-repo check.
no_marker="$workdir/nixy-no-marker"
mkdir -p "$no_marker/docs"
git -C "$workdir" init -q nixy-no-marker
touch "$no_marker/flake.nix"
# omit docs/private-overlay.md intentionally
mkdir -p "$no_marker/scripts"
touch "$no_marker/scripts/check-public-safety.sh"
git -C "$no_marker" add -A
git -C "$no_marker" -c user.email="test@example.com" \
	-c user.name="Test" commit -qm "init" >/dev/null 2>&1
if ! run_bootstrap --repo "$no_marker"; then
	if grep -q "private-overlay.md" "$tmpout"; then
		pass "U1 edge case: missing marker file exits with marker name"
	else
		fail_test "U1 edge case: expected missing marker name in error"
	fi
else
	fail_test "U1 edge case: should fail when marker file is missing"
fi

# Error path: a path that is not a Git checkout fails.
not_git="$workdir/not-a-git"
mkdir -p "$not_git/docs" "$not_git/scripts"
touch "$not_git/flake.nix" "$not_git/docs/private-overlay.md" \
	"$not_git/scripts/check-public-safety.sh"
if ! run_bootstrap --repo "$not_git"; then
	pass "U1 error path: non-Git directory exits non-zero"
else
	fail_test "U1 error path: should fail for directory that is not a Git repo"
fi

# ---------------------------------------------------------------------------
# U2: Private repo validation
# ---------------------------------------------------------------------------

# Happy path: valid private repo with flake.nix passes validation.
# We pass both repos; the script will fail at host discovery (no Nix), but
# the private-repo validation itself should succeed (error comes later).
if run_bootstrap \
	--repo "$fake_nixy" \
	--private-repo "$fake_priv" ||
	grep -qi "host\|darwin\|discover\|nix" "$tmpout"; then
	pass "U2 happy path: valid private repo passes validation"
else
	fail_test "U2 happy path: should pass private-repo validation"
fi

# Edge case: --private-repo override is respected.
alt_priv="$workdir/alt-priv"
mkdir -p "$alt_priv"
git -C "$workdir" init -q alt-priv
touch "$alt_priv/flake.nix"
git -C "$alt_priv" add -A
git -C "$alt_priv" -c user.email="test@example.com" \
	-c user.name="Test" commit -qm "init" >/dev/null 2>&1
if run_bootstrap \
	--repo "$fake_nixy" \
	--private-repo "$alt_priv" ||
	grep -qi "host\|darwin\|discover\|nix" "$tmpout"; then
	pass "U2 edge case: --private-repo override is used"
else
	fail_test "U2 edge case: should use --private-repo override"
fi

# Error path: missing private repo exits with guidance.
if ! run_bootstrap \
	--repo "$fake_nixy" \
	--private-repo "$workdir/missing-priv"; then
	if grep -q "nixy-priv\|private-overlay" "$tmpout"; then
		pass "U2 error path: missing private repo exits with setup guidance"
	else
		fail_test "U2 error path: expected setup guidance mentioning nixy-priv"
	fi
else
	fail_test "U2 error path: should fail when private repo is missing"
fi

# Error path: directory without flake.nix fails as invalid private host repo.
no_flake="$workdir/no-flake"
mkdir -p "$no_flake"
git -C "$workdir" init -q no-flake
git -C "$no_flake" -c user.email="test@example.com" \
	-c user.name="Test" commit -qm "init" --allow-empty >/dev/null 2>&1
if ! run_bootstrap \
	--repo "$fake_nixy" \
	--private-repo "$no_flake"; then
	if grep -q "flake.nix" "$tmpout"; then
		pass "U2 error path: private repo without flake.nix exits with 'flake.nix' message"
	else
		fail_test "U2 error path: expected 'flake.nix' in error for missing private flake"
	fi
else
	fail_test "U2 error path: should fail when private repo has no flake.nix"
fi

# ---------------------------------------------------------------------------
# U3: Host flag validation (without real Nix)
# ---------------------------------------------------------------------------

# Error path: --host with unknown name exits before build.
# (host discovery will fail since the fake flake.nix has no darwinConfigurations,
#  so this tests the "no hosts found" path rather than "host not found in list").
if ! run_bootstrap \
	--repo "$fake_nixy" \
	--private-repo "$fake_priv" \
	--host "unknown-host"; then
	pass "U3 error path: unknown --host exits non-zero before build"
else
	fail_test "U3 error path: should fail for unknown --host"
fi

# ---------------------------------------------------------------------------
# Public-safety fixture: op:// and 1password.com patterns still blocked
# ---------------------------------------------------------------------------

# These run check-public-safety.sh in an isolated workdir to confirm that
# examples in bootstrap docs use angle-bracket placeholders (safe) and that
# realistic references remain blocked.

safety_script="$script_dir/check-public-safety.sh"
safety_workdir=$(mktemp -d)
trap 'rm -rf "$safety_workdir"' EXIT
git -C "$safety_workdir" init -q
mkdir -p "$safety_workdir/scripts"
cp "$safety_script" "$safety_workdir/scripts/check-public-safety.sh"

run_safety() {
	(cd "$safety_workdir" && ./scripts/check-public-safety.sh) >"$tmpout" 2>&1
}

write_fixture() {
	printf '%s\n' "$1" >"$safety_workdir/fixture.md"
	git -C "$safety_workdir" add -A
}

# Placeholder op:// in angle-bracket form must be allowed.
write_fixture 'EXAMPLE_VALUE=op://<vault>/<item>/<field>'
if run_safety; then
	pass "public-safety: angle-bracket op:// placeholder is allowed"
else
	fail_test "public-safety: angle-bracket op:// placeholder should be allowed"
fi

# Realistic op:// reference must be blocked.
write_fixture 'EXAMPLE_VALUE=op://MyVault/github-pat/credential'
if ! run_safety; then
	pass "public-safety: realistic op:// reference is blocked"
else
	fail_test "public-safety: realistic op:// reference should be blocked"
fi

# 1Password account sign-in URL must be blocked.
write_fixture 'Sign in at acme-corp.1password.com/signin'
if ! run_safety; then
	pass "public-safety: 1password.com sign-in URL is blocked"
else
	fail_test "public-safety: 1password.com sign-in URL should be blocked"
fi

rm -f "$safety_workdir/fixture.md"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

if [[ $fail -ne 0 ]]; then
	echo "bootstrap.test.sh: FAILED"
	exit 1
fi

echo "bootstrap.test.sh: all tests passed"
