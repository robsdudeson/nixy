# pi coding agent

This repo installs the Bun JavaScript runtime declaratively and sets pi's
non-secret environment through Home Manager. The `pi` binary itself is
installed imperatively — it is not in nixpkgs and fully declarative packaging
was deferred. See [First-run checklist](#first-run-checklist).

## What's declarative vs. manual

Declarative (this repo, once a host opts in via `profiles/pi.nix`):

- Installing the Bun runtime (`pkgs.bun`).
- Installing Node.js 22 (`pkgs.nodejs_22`) so `npx` can run LazyPi.
- Setting `BUN_INSTALL` to `~/.bun` so `bun install -g` lands in a
  predictable, user-writable location.
- Adding `~/.bun/bin` to `PATH` so the installed `pi` binary resolves in
  every login shell.
- Setting `PI_CODING_AGENT_DIR` to `~/.config/pi/agent` so pi and LazyPi use
  the same writable config tree.
- Setting `PI_PACKAGE_DIR` to `~/.local/share/pi/packages` for stable,
  store-path-safe extension storage.
- Setting `PI_TELEMETRY=0` to opt out of install/update telemetry.
- Seeding a minimal `~/.config/pi/agent/settings.json` only if one does not
  already exist (idempotent; never overwrites an existing file).

Manual (you, once per machine, after a switch):

- Installing `pi` with `bun install -g @earendil-works/pi-coding-agent`.
- Optionally running LazyPi to install community Pi packages.
- Configuring a provider API key (see [Provider API keys](#provider-api-keys)).
- Any personal settings (theme, editor, model) in `settings.json`.

Nix does not own the `pi` binary, extensions, skills, session history, or
provider authentication. Treat those as first-run steps, not build output.

## Enabling this on a host

Public `nixy` does not enable pi on the public example host by default. A
real host opts in from `nixy-priv` (or a local ignored override) by importing
`profiles/pi.nix`:

```nix
imports = [
  # ... other nixy modules/profiles
  inputs.nixy + "/profiles/pi.nix"
];
```

## First-run checklist

After a successful `darwin-rebuild switch` on a host with this profile enabled:

1. Install pi:

   ```sh
   bun install -g @earendil-works/pi-coding-agent
   ```

2. Verify pi and the LazyPi runtime tools are on `PATH`:

   ```sh
   which -a pi
   pi --version
   bun --version
   node --version
   npm --version
   npx --version
   echo "$PI_CODING_AGENT_DIR"
   echo "$PI_PACKAGE_DIR"
   ```

   Node must be `22.19` or newer for LazyPi.

3. Optional: install community Pi packages with LazyPi — see
   [LazyPi package bootstrap](#lazypi-package-bootstrap).

4. Configure a provider API key — see [Provider API keys](#provider-api-keys).

5. Start pi:

   ```sh
   pi
   ```

## LazyPi package bootstrap

[LazyPi](https://lazypi.org/) is an optional package bootstrapper for Pi. It
installs a curated set of community packages such as subagents, MCP support,
web access, memory, plan mode, interactive shell, Compound Engineering, usage
tracking, and themes.

Run LazyPi only after a rebuild and after `pi` is already installed with Bun.
Do not run it from Home Manager or nix-darwin activation: it is interactive,
networked, and mutates Pi's writable package/config state.

Recommended install flow:

```sh
which -a pi
pi --version
echo "$PI_CODING_AGENT_DIR"
echo "$PI_PACKAGE_DIR"
npx @robzolkos/lazypi@<reviewed-version>
npx @robzolkos/lazypi@<reviewed-version> status
npx @robzolkos/lazypi@<reviewed-version> doctor
which -a pi
pi --version
```

Use a reviewed LazyPi version when you want repeatable setup. Running
`npx @robzolkos/lazypi` without a version fetches the latest package and is
best treated as an intentional one-off update.

Pi packages run with full user permissions. Review the LazyPi catalog before
choosing **Install all**, especially on machines or projects that handle private
work. Keep real package choices and provider-auth details in `nixy-priv` or
local ignored notes, not in public `nixy`.

Useful LazyPi commands:

```sh
npx @robzolkos/lazypi@<reviewed-version> status
npx @robzolkos/lazypi@<reviewed-version> update
npx @robzolkos/lazypi@<reviewed-version> doctor
npx @robzolkos/lazypi@<reviewed-version> remove
```

LazyPi install and update need network access. They are separate from running
pi with `PI_OFFLINE=1`.

## Upgrading

Upgrade pi itself with:

```sh
pi update --self
```

To pin pi to a specific version:

```sh
bun install -g @earendil-works/pi-coding-agent@<version>
```

Check the installed version with `pi --version` or look for
`lastChangelogVersion` in `~/.config/pi/agent/settings.json`.

Update LazyPi-managed packages with the reviewed LazyPi version you want to
trust:

```sh
npx @robzolkos/lazypi@<reviewed-version> update
```

## Provider API keys

Provider keys are secrets. They must not be committed to Nix files, generated
dotfiles, or the Nix store. Supply them at runtime using `op run`:

```sh
op run --env-file .env.op -- pi
```

The env file should contain provider variable names whose values are `op://`
references. Keep real vault, item, and field names in `nixy-priv` or a local
ignored file — never in this repo. See
[`docs/onepassword.md`](onepassword.md#runtime-secrets-op-run) for the full
`op run` pattern and what to avoid.

If you do not use 1Password, set the provider variable manually in your
terminal before starting pi. Never put a resolved key in `.zshrc`, `.zprofile`,
or any committed file.

## Using pi with the local llama-server

`services.llama-server` exposes llama.cpp through an OpenAI-compatible API at
`http://127.0.0.1:8080/v1` by default. Add a provider for that endpoint in
`~/.config/pi/agent/models.json`:

```json
{
  "providers": {
    "local-llm": {
      "baseUrl": "http://127.0.0.1:8080/v1",
      "api": "openai-completions",
      "apiKey": "sk-noop",
      "models": [
        {
          "id": "local-model",
          "input": ["text"],
          "compat": {
            "maxTokensField": "max_tokens"
          }
        }
      ]
    }
  }
}
```

Set `models[].id` to the same value as `services.llama-server.alias`. That
alias becomes llama.cpp's `--alias` value, and pi uses it as the model name.
The OpenAI transport requires `apiKey`, but llama-server ignores it. Use a
non-secret placeholder such as `sk-noop`.

Pi streams responses for `api: "openai-completions"` by default. There is no
streaming switch to turn on. Start with the minimal `compat` block above; add
the other fields only when the local server rejects or omits a streaming field:

| Symptom | `compat` field | When to use it |
|---|---|---|
| llama-server rejects `max_completion_tokens` | `"maxTokensField": "max_tokens"` | Recommended for llama.cpp-compatible servers |
| Streaming fails when pi requests usage data | `"supportsUsageInStreaming": false` | Add only if the server rejects `stream_options.include_usage` |
| Streamed chunks never include a finish reason | `"supportsFinishReason": false` | Add only if pi reports missing `finish_reason` data |

`models.json` sits beside `settings.json`, `trust.json`, sessions, and package
caches. Do not manage it with Nix or replace it with a store symlink; pi can
change files in this directory while it runs.

## Environment variables

| Variable | Set by | Default | Purpose |
|---|---|---|---|
| `BUN_INSTALL` | `modules/home/pi.nix` | `~/.bun` | Bun global-package prefix; `~/.bun/bin` on `PATH` |
| `PI_CODING_AGENT_DIR` | `modules/home/pi.nix` | `~/.config/pi/agent` | Pi config root; keeps pi and LazyPi on the same writable tree |
| `PI_PACKAGE_DIR` | `modules/home/pi.nix` | `~/.local/share/pi/packages` | Extension/plugin install root; avoids Nix-store path issues |
| `PI_TELEMETRY` | `modules/home/pi.nix` | `0` (off) | Install/update telemetry; set `1` in a local shell profile to re-enable |
| `PI_OFFLINE` | unset | — | Set `1` to disable startup network operations (update checks, package updates, telemetry) |

## settings.json

On first switch, the activation script seeds `~/.config/pi/agent/settings.json`
with a minimal baseline:

```json
{
  "enableInstallTelemetry": false
}
```

This file is writable — pi and you can modify it freely. A subsequent
`darwin-rebuild switch` never overwrites it. Edit it directly or through pi's
own settings commands. Do not replace it with a `home.file` symlink; pi
mutates this file and the sibling files in the same directory (`trust.json`,
`ide-selection.json`, sessions/, package caches).

## Extensions and skills

pi extensions and skills are installed imperatively with `pi install` or with
LazyPi:

```sh
pi install npm:<package>
pi install git:github.com/<user>/<repo>
npx @robzolkos/lazypi@<reviewed-version>
```

They land in `PI_PACKAGE_DIR` (default `~/.local/share/pi/packages`) and are
recorded in Pi's writable config tree. Declarative management of specific
extensions is deferred to a future iteration.

## Offline mode

To run pi without any startup network calls (update checks, telemetry):

```sh
PI_OFFLINE=1 pi
```

Or set `PI_OFFLINE=1` in a local, non-committed shell profile.

## Uninstall / escape hatch

To remove LazyPi-installed packages, use LazyPi first:

```sh
npx @robzolkos/lazypi@<reviewed-version> remove
```

To remove pi without touching the rest of the Nix configuration:

```sh
bun remove -g @earendil-works/pi-coding-agent
```

To remove config and sessions:

```sh
rm -rf ~/.config/pi
```

To remove extensions:

```sh
rm -rf "$PI_PACKAGE_DIR"
```

Removing `profiles/pi.nix` from the host import and running
`darwin-rebuild switch` removes Bun and the environment variables. It does
not touch `~/.config/pi` or any installed extensions.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `pi: command not found` after switch | pi not yet installed, or `~/.bun/bin` not on PATH in the current shell | Open a new login shell (PATH is set at session start), then run `bun install -g @earendil-works/pi-coding-agent` |
| `bun: command not found` | Home Manager switch not applied yet, or shell not restarted | Run `darwin-rebuild switch`, then open a new shell |
| `npx @robzolkos/lazypi` fails with a Node version error | Node is missing, too old, or the shell predates the latest switch | Open a fresh shell and check `node --version`; it must be `22.19` or newer |
| LazyPi status does not match Pi's packages | `PI_CODING_AGENT_DIR` or `PI_PACKAGE_DIR` is missing, or multiple `pi` installs exist | Check `echo $PI_CODING_AGENT_DIR`, `echo $PI_PACKAGE_DIR`, and `which -a pi`; resolve duplicates before updating packages |
| pi starts but has no provider | Provider variable not set | Use `op run --env-file .env.op -- pi` or set the provider variable in your shell before starting pi |
| `op run` fails immediately | 1Password locked, item missing, or wrong vault | Unlock/sign in, verify item/vault name, rerun |
| Extensions install to wrong path | `PI_PACKAGE_DIR` not exported in the current shell | Restart the shell or `echo $PI_PACKAGE_DIR` to confirm |
| Settings reset after rebuild | `settings.json` was a Nix-store symlink (read-only) | Delete the symlink, rebuild, and the activation script seeds a writable file |
