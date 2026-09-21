# llama.cpp server

`profiles/llama-server.nix` makes the reusable Home Manager module available to
a host. It does not start a server until the host enables it. Keep real hosts,
model paths, aliases, and hardware settings in `nixy-priv` or a local ignored
override.

## Enable a server

Import the profile from a real host, then configure the module for the host's
Home Manager user:

```nix
imports = [
  "${inputs.nixy}/profiles/llama-server.nix"
];

home-manager.users.${primaryUser}.services.llama-server = {
  enable = true;
  modelPath = "/Users/${primaryUser}/.cache/llama-server/model.gguf";
  alias = "local-model";
  host = "127.0.0.1";
  port = 8080;
  contextSize = 65536;
  flashAttention = "on";
  cacheTypeK = "q8_0";
  cacheTypeV = "q8_0";
  threadsBatch = 12;
};
```

The module installs `pkgs.llama-cpp` and creates a user launchd agent with
tokenized `ProgramArguments`. It passes the configured values to
`llama-server` as `--model`, `--alias`, `--host`, `--port`, `--ctx-size`,
`--flash-attn`, `--cache-type-k`, `--cache-type-v`, and `--threads-batch`.
Set `gpuLayers` only after testing the selected model and hardware.

`modelPath` and `alias` are required when `enable = true`. Use a fixed local
GGUF file and record its checksum outside this public repository. Do not use
the Nix store for models, caches, or logs.

## Lifecycle and state

The agent has `RunAtLoad = false` and `KeepAlive = false`. A rebuild installs
its plist but does not load a model or start a server. Start and stop it with
`launchctl` after validating that its port is free:

```sh
label=org.nix-community.home.llama-server
uid=$(id -u)

lsof -nP -iTCP:8080 -sTCP:LISTEN
launchctl kickstart -k "gui/$uid/$label"
launchctl kill SIGTERM "gui/$uid/$label"
```

By default, stdout and stderr go to
`~/Library/Logs/llama-server/stdout.log` and
`~/Library/Logs/llama-server/stderr.log`. Set `logDirectory` to use another
writable directory. The agent sets `HF_HOME` to `~/.cache/huggingface`, but a
fixed `modelPath` remains the source of truth.

The module binds to `127.0.0.1` by default. Do not expose the server on a
network until you add an authentication and access-control design.

To point pi at this local server, add an OpenAI-compatible provider in
`~/.config/pi/agent/models.json`. See
[the pi docs](pi.md#using-pi-with-the-local-llama-server) for the provider
example, streaming notes, and the `alias`/model-name mapping.

## Validation and rollback

Before switching a real host, dry-build it from its private configuration.
After starting the agent, confirm the local API, model alias, logs, and one
process. Test cold-cache recovery separately; a fixed local model should not
download during startup.

To disable the server, set `enable = false` or remove the profile import, then
rebuild the host. Nix rollback restores the launchd wiring, but does not delete
model files, Hugging Face cache entries, or logs. Remove those paths manually
only when you no longer need them.

## Secrets

Do not put `HF_TOKEN`, API keys, or other resolved secrets in Nix options,
launchd environment variables, or this repository. Supply a secret only at
runtime through a private secret mechanism when a model download needs one.
