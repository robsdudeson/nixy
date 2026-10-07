set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

host := "example-aarch64-darwin"
nixos_host := "example-x86_64-linux"

bootstrap *ARGS:
    ./scripts/bootstrap.sh {{ARGS}}

show:
    nix flake show

fmt:
    nix fmt

build-example:
    nix build .#darwinConfigurations.{{host}}.system --dry-run

build-example-nixos:
    nix build .#nixosConfigurations.{{nixos_host}}.config.system.build.toplevel --dry-run

bootstrap-test:
    ./scripts/bootstrap.test.sh

check:
    nix flake show --all-systems >/dev/null
    nix build .#darwinConfigurations.{{host}}.system --dry-run
    nix build .#nixosConfigurations.{{nixos_host}}.config.system.build.toplevel --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-onepassword --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-pi --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-llama-server --dry-run
    nix build .#checks.aarch64-darwin.example-aarch64-darwin-llama-server-enabled --dry-run
    nix build .#checks.x86_64-linux.fish-test
    nix build .#checks.x86_64-linux.gh-test
    nix build .#checks.x86_64-linux.git-test
    nix build .#checks.x86_64-linux.pi-declarative-test
    nix build .#checks.x86_64-linux.vscode-test
    nix build .#checks.x86_64-linux.common-test
    nix build .#checks.x86_64-linux.wsl-test
    ./scripts/bootstrap.test.sh
    ./scripts/check-public-safety.sh

check-public-safety:
    ./scripts/check-public-safety.sh
