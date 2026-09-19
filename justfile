set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

host := "example-aarch64-darwin"

show:
    nix flake show

fmt:
    nix fmt

build-example:
    nix build .#darwinConfigurations.{{host}}.system --dry-run

check:
    nix flake show --all-systems >/dev/null
    nix build .#darwinConfigurations.{{host}}.system --dry-run
    ./scripts/check-public-safety.sh

check-public-safety:
    ./scripts/check-public-safety.sh
