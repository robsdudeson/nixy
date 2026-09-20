#!/usr/bin/env bash
# bootstrap.sh — guided nixy setup: validate repos, discover hosts, build, switch.
#
# Usage:
#   ./scripts/bootstrap.sh [options]
#
# Options:
#   --repo <path>          Public nixy checkout path (default: ~/code/nixy; env: NIXY_REPO)
#   --private-repo <path>  Private nixy-priv path (default: sibling of public repo; env: NIXY_PRIV_REPO)
#   --host <name>          Private Darwin host to build/apply (skips interactive prompt)
#   --build-only           Build the selected host but do not offer a switch
#   --dry-run              Same as --build-only
#   --help                 Show this help text
#
# Environment variables:
#   NIXY_REPO              Override the public repo path (same as --repo)
#   NIXY_PRIV_REPO         Override the private repo path (same as --private-repo)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

err() { echo "error: $*" >&2; }
info() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

usage() {
	cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
  --repo <path>          Public nixy checkout (default: ~/code/nixy; env: NIXY_REPO)
  --private-repo <path>  Private nixy-priv path (default: sibling of public repo; env: NIXY_PRIV_REPO)
  --host <name>          Darwin host to build/apply (skips interactive prompt)
  --build-only           Build only; do not offer darwin-rebuild switch
  --dry-run              Same as --build-only
  --help                 Show this help

Environment variables:
  NIXY_REPO       Override the public repo path
  NIXY_PRIV_REPO  Override the private repo path
EOF
}

# Resolve ~ in paths without relying on eval
expand_home() {
	local p=$1
	if [[ "$p" == "~"* ]]; then
		printf '%s%s' "$HOME" "${p:1}"
	else
		printf '%s' "$p"
	fi
}

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

build_only=0
chosen_host=''

# Apply environment variable defaults before parsing flags so flags win.
repo_path="${NIXY_REPO:-~/code/nixy}"
private_repo_path="${NIXY_PRIV_REPO:-}" # resolved later relative to repo if empty

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
	case $1 in
	--repo)
		[[ $# -ge 2 ]] || {
			err "--repo requires a path argument"
			exit 1
		}
		repo_path=$2
		shift 2
		;;
	--private-repo)
		[[ $# -ge 2 ]] || {
			err "--private-repo requires a path argument"
			exit 1
		}
		private_repo_path=$2
		shift 2
		;;
	--host)
		[[ $# -ge 2 ]] || {
			err "--host requires a name argument"
			exit 1
		}
		chosen_host=$2
		shift 2
		;;
	--build-only | --dry-run)
		build_only=1
		shift
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		err "unknown option: $1"
		usage >&2
		exit 1
		;;
	esac
done

# ---------------------------------------------------------------------------
# U1: Validate public repo
# ---------------------------------------------------------------------------

info "Locating public nixy checkout..."

# Resolve to a canonical real path (handles /var -> /private/var on macOS).
repo_path=$(expand_home "$repo_path")
if [[ -d "$repo_path" ]]; then
	repo_path=$(cd "$repo_path" && pwd -P)
fi

# Marker files that must exist in a real nixy checkout.
marker_files=(
	flake.nix
	docs/private-overlay.md
	scripts/check-public-safety.sh
)

if [[ ! -d "$repo_path" ]]; then
	err "Public repo not found at '$repo_path'."
	echo ""
	echo "  Fix: clone the public nixy repo to ~/code/nixy, or pass --repo <path>."
	echo "  You can also set NIXY_REPO=<path> to change the default permanently."
	exit 1
fi

for marker in "${marker_files[@]}"; do
	if [[ ! -f "$repo_path/$marker" ]]; then
		err "'$repo_path' is missing expected file '$marker'."
		echo ""
		echo "  This looks like a partial checkout or a copy of the script."
		echo "  Ensure you have the full nixy repo at this path,"
		echo "  or use --repo <path> / NIXY_REPO=<path> to point at the correct location."
		exit 1
	fi
done

# Verify it is actually a Git checkout rooted at repo_path.
if ! git -C "$repo_path" rev-parse --show-toplevel >/dev/null 2>&1; then
	err "'$repo_path' exists but is not a Git repository."
	exit 1
fi

git_root=$(git -C "$repo_path" rev-parse --show-toplevel)
if [[ "$git_root" != "$repo_path" ]]; then
	err "Git repository root ($git_root) does not match the expected path ($repo_path)."
	echo ""
	echo "  The script may be running inside a subdirectory. Use --repo to point at the repo root."
	exit 1
fi

echo "  Public repo: $repo_path"

# ---------------------------------------------------------------------------
# U2: Validate sibling private repo
# ---------------------------------------------------------------------------

info "Locating private nixy-priv checkout..."

if [[ -z "$private_repo_path" ]]; then
	# Default: sibling directory named nixy-priv next to the public repo.
	# repo_path is already canonical (pwd -P), so dirname is safe.
	private_repo_path="$(dirname "$repo_path")/nixy-priv"
fi

private_repo_path=$(expand_home "$private_repo_path")
if [[ -d "$private_repo_path" ]]; then
	private_repo_path=$(cd "$private_repo_path" && pwd -P)
fi

if [[ ! -d "$private_repo_path" ]]; then
	err "Private repo not found at '$private_repo_path'."
	echo ""
	echo "  The bootstrap script requires a sibling nixy-priv checkout to proceed."
	echo "  See docs/private-overlay.md for the expected layout."
	echo ""
	echo "  Fix: clone nixy-priv as a sibling of this repo, or use:"
	echo "    --private-repo <path>   or   NIXY_PRIV_REPO=<path>"
	exit 1
fi

if ! git -C "$private_repo_path" rev-parse --show-toplevel >/dev/null 2>&1; then
	err "'$private_repo_path' exists but is not a Git repository."
	echo ""
	echo "  Ensure nixy-priv is properly cloned. See docs/private-overlay.md."
	exit 1
fi

if [[ ! -f "$private_repo_path/flake.nix" ]]; then
	err "'$private_repo_path' does not contain a flake.nix — this does not look like a valid nixy-priv repo."
	echo ""
	echo "  See docs/private-overlay.md for the expected private repo structure."
	exit 1
fi

echo "  Private repo: $private_repo_path"

# ---------------------------------------------------------------------------
# U3: Discover and prompt for private host
# ---------------------------------------------------------------------------

info "Discovering Darwin hosts in nixy-priv..."

# Use nix eval to extract darwinConfigurations output names.
# Falls back to nix flake show --json if eval is unavailable.
discover_hosts() {
	local priv=$1
	local hosts=()
	local raw

	# Try nix eval first (cheaper: no build, just attr evaluation).
	if raw=$(nix eval --json "$priv#darwinConfigurations" --apply 'builtins.attrNames' 2>/dev/null); then
		# Parse the JSON array with basic shell processing.
		# Strip [ " ] chars and split on commas/spaces.
		raw="${raw//[\"[\\]]/}"
		raw="${raw//,/ }"
		for h in $raw; do
			[[ -n "$h" ]] && hosts+=("$h")
		done
	elif raw=$(nix flake show --json "$priv" 2>/dev/null); then
		# Fall back to flake show JSON: extract darwinConfigurations keys.
		# Portable extraction without jq.
		while IFS= read -r line; do
			if [[ "$line" =~ \"([^\"]+)\":[[:space:]]*\{ ]]; then
				hosts+=("${BASH_REMATCH[1]}")
			fi
		done < <(echo "$raw" | python3 -c "
import sys, json
data = json.load(sys.stdin)
dc = data.get('darwinConfigurations', {})
for k in dc:
    print(k)
" 2>/dev/null || true)
	fi

	printf '%s\n' "${hosts[@]+"${hosts[@]}"}"
}

PUBLIC_EXAMPLE_HOST="example-aarch64-darwin"

all_hosts=()
while IFS= read -r h; do
	[[ -n "$h" ]] && all_hosts+=("$h")
done < <(discover_hosts "$private_repo_path")

# Filter out the public example host if it somehow appears (dev override).
real_hosts=()
for h in "${all_hosts[@]+"${all_hosts[@]}"}"; do
	if [[ "$h" != "$PUBLIC_EXAMPLE_HOST" ]]; then
		real_hosts+=("$h")
	fi
done

if [[ ${#real_hosts[@]} -eq 0 ]]; then
	err "No private Darwin hosts found in nixy-priv."
	echo ""
	echo "  Add a darwinConfigurations.<host> output to your nixy-priv flake."
	echo "  See docs/private-overlay.md and docs/operations.md#adding-a-host."
	exit 1
fi

if [[ -n "$chosen_host" ]]; then
	# Validate the explicitly supplied host exists.
	found=0
	for h in "${real_hosts[@]}"; do
		if [[ "$h" == "$chosen_host" ]]; then
			found=1
			break
		fi
	done
	if [[ $found -eq 0 ]]; then
		err "Host '$chosen_host' not found in nixy-priv darwinConfigurations."
		echo ""
		echo "  Available hosts:"
		for h in "${real_hosts[@]}"; do
			echo "    $h"
		done
		exit 1
	fi
	echo "  Using host: $chosen_host"
elif [[ ${#real_hosts[@]} -eq 1 ]]; then
	chosen_host="${real_hosts[0]}"
	echo "  One private host found. Using: $chosen_host"
else
	echo ""
	echo "  Available private hosts:"
	for i in "${!real_hosts[@]}"; do
		printf '    %d) %s\n' "$((i + 1))" "${real_hosts[$i]}"
	done
	echo ""
	read -r -p "  Select host number: " selection
	if ! [[ "$selection" =~ ^[0-9]+$ ]] ||
		[[ "$selection" -lt 1 ]] ||
		[[ "$selection" -gt ${#real_hosts[@]} ]]; then
		err "Invalid selection: $selection"
		exit 1
	fi
	chosen_host="${real_hosts[$((selection - 1))]}"
	echo "  Selected: $chosen_host"
fi

# ---------------------------------------------------------------------------
# U4: Build before optional switch
# ---------------------------------------------------------------------------

info "Building $chosen_host (dry-run)..."

flake_ref="$private_repo_path#darwinConfigurations.$chosen_host.system"

nix build "$flake_ref" --dry-run

echo "  Build check passed."

if [[ $build_only -eq 1 ]]; then
	echo ""
	echo "  --build-only: skipping switch."
	echo ""
	echo "  To apply this host, run:"
	if command -v darwin-rebuild >/dev/null 2>&1; then
		echo "    sudo darwin-rebuild switch --flake $private_repo_path#$chosen_host"
	else
		echo "    sudo nix run nix-darwin#darwin-rebuild -- switch --flake $private_repo_path#$chosen_host"
	fi
	exit 0
fi

echo ""
if command -v darwin-rebuild >/dev/null 2>&1; then
	switch_cmd="sudo darwin-rebuild switch --flake $private_repo_path#$chosen_host"
else
	switch_cmd="sudo nix run nix-darwin#darwin-rebuild -- switch --flake $private_repo_path#$chosen_host"
fi

echo "  About to run:"
echo "    $switch_cmd"
echo ""
read -r -p "  Apply this host? [y/N] " confirm
case "${confirm,,}" in
y | yes) ;;
*)
	echo ""
	echo "  Switch cancelled. To apply later, run:"
	echo "    $switch_cmd"
	exit 0
	;;
esac

info "Switching to $chosen_host..."
eval "$switch_cmd"

echo ""
echo "  Switch complete."

# Detect whether the switched host imports the 1Password profile so we can
# surface the post-switch checklist. We check for the presence of the
# profiles/onepassword.nix import in the private repo without printing
# private file contents.
if grep -qr "onepassword" "$private_repo_path/flake.nix" 2>/dev/null ||
	grep -rl "onepassword" "$private_repo_path" --include="*.nix" >/dev/null 2>&1; then
	echo ""
	echo "  This host appears to use the 1Password profile."
	echo "  Complete the manual first-run steps documented at:"
	echo "    $repo_path/docs/onepassword.md#first-run-checklist"
fi
