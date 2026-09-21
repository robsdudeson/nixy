---
title: "docs: Wire pi coding agent to the local llama-server (streaming)"
type: docs
status: active
date: 2026-09-21
---

# docs: Wire pi coding agent to the local llama-server (streaming)

## Overview

Document how to point the imperatively-installed `pi` coding agent at the
repo's local `llama-server` (from `modules/home/llama-server.nix`) using an
OpenAI-compatible provider entry in `~/.config/pi/agent/models.json`. Explain
that streaming is pi's default transport for `api: "openai-completions"` and
clarify which `compat` knobs matter only when llama.cpp rejects a streaming
field. No Nix code changes — `models.json` is deliberately not Nix-managed
(pi mutates its config directory), so this is a documented first-run step.

## Problem Frame

A host can already run `llama-server` (declarative module + manual launchd
lifecycle) and install `pi` (imperative, per `docs/pi.md`), but nothing ties
the two together. A user who wants pi to drive their local model has no
documented path for the `models.json` provider entry, no statement that
streaming works out of the box, and no guidance on the llama.cpp-specific
`compat` fields (`maxTokensField`, `supportsUsageInStreaming`,
`supportsFinishReason`). This plan closes that documentation gap.

## Requirements Trace

- R1. Document a working `models.json` provider entry pointing pi at the local
  llama-server's OpenAI-compatible endpoint (`http://127.0.0.1:8080/v1`).
- R2. State clearly that streaming is the default for `api: "openai-completions"`
  and explain the streaming-related `compat` knobs as failure-mode overrides,
  not an enable switch.
- R3. Make the `id`/`alias` correspondence between `models.json` and the
  `services.llama-server` module explicit.
- R4. Frame the whole thing as a manual/first-run step, consistent with
  `docs/pi.md`'s existing "not Nix-managed" stance for the pi config directory.
- R5. Cross-link the two docs so a reader on either side can find the wiring.

## Scope Boundaries

- No changes to `modules/home/llama-server.nix` or its options/flags.
- No new `llama-server` flags (`--parallel`, `--cont-batching`, etc.).
- No checked-in `models.json` example file — guidance lives inline in docs.
- No Nix management of `models.json` or any pi config file.
- No provider-key/secret handling changes (already covered in `docs/pi.md`).

---

## Context & Research

### Relevant Code and Patterns

- `modules/home/llama-server.nix` — `services.llama-server` options; `alias`
  becomes `--alias` and is the model name pi must reference. Default bind is
  `127.0.0.1:8080`.
- `docs/llama-server.md` — existing "Enable a server" + launchctl lifecycle
  doc; the new cross-link and a short "Using with pi" pointer land here.
- `docs/pi.md` — existing structure (What's declarative vs. manual, First-run
  checklist, Provider API keys, Environment variables, settings.json). The new
  "Using pi with the local llama-server" section mirrors this voice and its
  "manual, not Nix-managed" framing.

### External References

- pi `docs/models.md` (OpenAI Compatibility section) — `compat` fields:
  `supportsUsageInStreaming` (default true), `supportsFinishReason` (default
  true), `maxTokensField` (`max_tokens` vs `max_completion_tokens`).
- pi `docs/custom-provider.md` / `docs/providers.md` — provider shape with
  `baseUrl`, `api: "openai-completions"`, `apiKey`, `models[]`.

---

## Key Technical Decisions

- **Documented manual step, not Nix:** `models.json` is mutated by pi and lives
  beside `settings.json`/`trust.json`; `docs/pi.md` already forbids symlinking
  it from the store. The wiring is therefore prose + example, not a module.
  (see origin: `docs/pi.md` settings.json section)
- **Streaming framed as default, not a toggle:** pi always streams for
  `openai-completions`; the doc presents `compat` fields as "add only if the
  server rejects a field," to prevent readers cargo-culting `false` values.
- **Start minimal, add compat on failure:** recommend `maxTokensField:
  "max_tokens"` up front (llama.cpp convention) but leave
  `supportsUsageInStreaming`/`supportsFinishReason` at defaults unless the user
  observes errors — recent llama.cpp builds support both.
- **Placeholder apiKey:** the OpenAI transport requires `apiKey`; llama-server
  ignores it, so a non-secret placeholder (`sk-noop`) is documented — never a
  real key, consistent with the Provider API keys section.

## Open Questions

### Resolved During Planning

- Docs-only vs. module change: user chose docs-only.
- Where the wiring section lives: primary content in `docs/pi.md`; a short
  pointer + cross-link in `docs/llama-server.md`.

### Deferred to Implementation

- Exact heading placement within `docs/pi.md` (before or after "Extensions and
  skills") — decide while editing for best reading flow.
- Whether to add a one-row troubleshooting entry for streaming/`max_tokens`
  errors — add if it reads naturally alongside the existing table.

---

## Implementation Units

- [ ] U1. **Add "Using pi with the local llama-server" section to `docs/pi.md`**

**Goal:** Give a reader a copy-adaptable `models.json` provider entry and a
clear streaming explanation, framed as a first-run step.

**Requirements:** R1, R2, R3, R4

**Dependencies:** None

**Files:**
- Modify: `docs/pi.md`

**Approach:**
- New H2 section covering: (1) llama-server exposes an OpenAI-compatible API at
  `http://127.0.0.1:8080/v1`; (2) minimal `models.json` provider block with
  `baseUrl`, `api: "openai-completions"`, placeholder `apiKey`, and a
  `models[]` entry whose `id` equals the module's `alias`; (3) streaming is the
  default — no switch to flip; (4) `compat` table subset
  (`maxTokensField`, `supportsUsageInStreaming`, `supportsFinishReason`) with
  guidance to add only on observed failures; (5) note that `models.json` sits
  beside `settings.json` and is not Nix-managed.
- Reuse the existing doc's tone and the config path
  `~/.config/pi/agent/models.json`.
- Optionally add one troubleshooting-table row for streaming/`max_tokens`
  rejection (deferred decision).

**Patterns to follow:**
- Section structure, code-fence style, and "manual vs. declarative" framing
  already in `docs/pi.md` (settings.json and Environment variables sections).

**Test scenarios:**
- Test expectation: none — documentation only, no behavioral code change.
- Manual verification captured in U1 Verification below.

**Verification:**
- The documented `models.json`, with `id` set to a real `alias`, lets `pi`
  list and select the local model against a running llama-server, and a prompt
  streams tokens — confirmed by hand on a host that has both running.
- `id`/`alias` correspondence and the `127.0.0.1:8080/v1` endpoint match
  `modules/home/llama-server.nix` defaults.

- [ ] U2. **Cross-link `docs/llama-server.md` to the pi wiring section**

**Goal:** A reader configuring the server can discover how to point pi at it.

**Requirements:** R5

**Dependencies:** U1 (the target section must exist to link to)

**Files:**
- Modify: `docs/llama-server.md`

**Approach:**
- Add a short "Using with pi" pointer (1–3 sentences) linking to the new
  `docs/pi.md` section, placed near "Lifecycle and state" where the running
  endpoint is established.
- Keep it a pointer, not a duplicate of the `models.json` content.

**Patterns to follow:**
- Existing relative-link style within the repo docs.

**Test scenarios:**
- Test expectation: none — documentation only.

**Verification:**
- The relative link resolves to the new section heading in `docs/pi.md`.

---

## Documentation / Operational Notes

- Per repo convention (`AGENTS.md`), run the `plain-english` skill over both
  edited docs before finalizing.
- No rollout, migration, or monitoring impact — documentation only.

---

## Sources & References

- Related code: `modules/home/llama-server.nix` (`services.llama-server`,
  `alias`, default `127.0.0.1:8080`)
- Related docs: `docs/pi.md`, `docs/llama-server.md`
- External: pi `docs/models.md` (OpenAI Compatibility), `docs/providers.md`,
  `docs/custom-provider.md`
