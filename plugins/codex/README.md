# Codex adapter

Wires the `memory` CLI into Codex's hook system. Codex's hook protocol is
deliberately Claude Code-compatible, so this plugin is just a single
`hooks.json` file that calls `memory hook recall --agent codex` on every
user message.

## What works on Codex

- **Recall** (`UserPromptSubmit` hook) — injects matching wiki entries as
  `additionalContext` before the model sees the prompt. Same envelope as
  Claude Code.
- **`memory create` / `memory delete` / `memory list` / `memory recall`** —
  the CLI works identically; agents call it via Codex's bash tool.

## What doesn't work on Codex

Codex has no `SessionEnd` or `PermissionRequest` hook. That means:

- **No automatic session capture.** Conversations aren't auto-archived to
  `~/.memory/raw/sessions/`. You can still drop manual notes into
  `~/.memory/raw/inbox/` and run `/memory:process` later.
- **No auto-allow for wiki writes.** Background subagents that touch
  `~/.memory/wiki/` will trigger Codex's normal permission prompts.
  Adjust Codex's `permission_mode` if you want unattended operation.

## Install

`install.sh` at the repo root detects `~/.codex/` and installs this
plugin. If `~/.codex/hooks.json` already exists, the installer prints a
warning and asks you to merge manually rather than clobbering it.
