# OpenCode adapter

A TypeScript plugin that wires the `memory` CLI into OpenCode's hook
surface. Unlike Claude Code (JSON hook config) and Codex (also JSON
hook config), OpenCode plugins are TS modules with callback-based hooks.

## What works on OpenCode

- **Recall** via `experimental.chat.system.transform` — the most recent
  user prompt is captured from `chat.message`, then injected as a system
  prompt fragment on the next LLM call. The recall content is plain text
  (the OpenCode branch in `memory hook recall` skips JSON envelope wrapping).
- **Permission auto-allow** via `permission.ask` — wiki writes and
  raw→processed file moves get auto-allowed without prompting the user.
- **Skills** — install the `memory:create`, `memory:process`, and
  `memory:recall` SKILL.md files into OpenCode's skills directory the same
  way as for Claude Code and Codex.
- **`memory create` / `delete` / `list` / `inbox`** — the CLI works
  identically; the agent calls it via OpenCode's bash/shell tool.

## What doesn't work on OpenCode

- **No Stop hook** — but we don't need one. Validation happens at
  write time inside `memory create`, so there's nothing for a stop hook
  to do.
- **No SessionEnd hook** — capture is agent-driven via `memory inbox`
  on all agents, so no per-agent hook is needed.

## Caveats

- The recall context is appended to the system prompt for *every* LLM
  call in the session, not just the first turn after the user message.
  This is because `system.transform` runs per turn and we don't have a
  way to know if it's the same turn we already injected for. Net effect:
  the model sees recall context redundantly across multi-turn tasks
  within a single session. Acceptable but not ideal.

- The OpenCode `Permission` type doesn't match Claude Code's
  `{tool_name, tool_input}` shape exactly. The plugin does a best-effort
  mapping based on `permission.type` and `permission.metadata`. If you
  see wiki writes prompting where they shouldn't, the mapping needs
  adjustment for your OpenCode version.

## Install

The repo's `install.sh` detects `~/.config/opencode/` and copies this
plugin into place. The plugin needs `@opencode-ai/plugin` available to
the OpenCode runtime — that comes with OpenCode itself, no extra install.
