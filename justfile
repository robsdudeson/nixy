set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

host := "example-aarch64-darwin"

bootstrap *ARGS:
    ./scripts/bootstrap.sh {{ARGS}}

show:
    nix flake show

fmt:
    nix fmt

build-example:
    nix build .#darwinConfigurations.{{host}}.system --dry-run

bootstrap-test:
    ./scripts/bootstrap.test.sh

check:
    nix flake show --all-systems >/dev/null
    nix build .#darwinConfigurations.{{host}}.system --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-onepassword --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-pi --dry-run
    ./scripts/bootstrap.test.sh
    ./scripts/check-public-safety.sh

check-public-safety:
    ./scripts/check-public-safety.sh
