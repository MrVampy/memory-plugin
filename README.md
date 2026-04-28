# memory-plugin

A persistent, typed wiki that three coding agents share — **Claude Code**, **Codex**, and **OpenCode**. Your conversations with each agent accumulate into a single markdown knowledge base at `~/.memory/wiki/` that all three can read and write. A scheduled subagent processes session transcripts into structured entries in the background, so the agents remember what you've decided, preferred, or built — without you having to repeat it.

Built on the [Karpathy wiki pattern](https://karpathy.bearblog.dev/self-unsupervised-learning/): an LLM incrementally compiles a persistent knowledge base rather than re-deriving knowledge from raw transcripts every session.

> **Status:** early but used daily. The validator is solid; the maintain skill's heuristics are still maturing. If you try it, expect to tune what your agents save. PRs and issues welcome.

## The shape of it

**One custom tool.** A single CLI called `memory validate` that enforces the wiki's structural consistency. It's the only binary this project ships.

**Three skills.** Installed into each agent's skill directory:

| Skill | When it runs | What it does |
|---|---|---|
| `memory:recall` | Live, when the agent needs prior context | Searches `~/.memory/wiki/` with the agent's native Grep/Glob/Read tools |
| `memory:create` | Live, only when the user explicitly asks to remember, update, or delete | Uses native Write/Edit/rm + validator gate |
| `memory:maintain` | Scheduled (hourly) + on-demand | Spawns a background subagent that walks session transcripts, extracts knowledge, runs maintenance passes |

**Everything else is native.** The agent uses Read, Edit, Write, Bash `rm`, Grep, and Glob directly on the wiki directory. No MCP servers, no custom hooks, no background daemons. The only invariant is: **anything that writes to the wiki runs `memory validate` after.** That's the whole architectural rule.

## Why this shape

- **Type the structure, not the content.** The validator enforces required fields, ID format, tag format, and bidirectional link integrity. What an entry is *about*, what `kind` you call it, what namespace it lives in — all free.
- **Validate on write, not after.** An invalid entry can't stay on disk for long. No post-hoc scan, no Stop-hook lint, no repair tool.
- **Reads open, writes closed.** Native tools read the wiki freely; only writes go through the validator gate. Reads stay fast and flexible; writes stay consistent.
- **Portable across agents.** Same wiki, same validator, same skills across Claude Code, Codex, and OpenCode. Per-agent differences are limited to plugin manifests and install paths.
- **Agent-driven, not host-driven.** No hooks firing prompts into your session unexpectedly. The agent decides when to recall and when to write, from instructions in the skill descriptions. The scheduler is the exception — it fires the maintain skill hourly, and only in a designated project.

## Prerequisites

- `gleam` — 1.x or later
- `node` — 18 or later
- `npm` — for the `yay` YAML library's runtime dep
- `python3` — stdlib only, used by the maintain skill's transcript filters and by `install.sh` for JSON/cron state
- `bash` — for the launcher and install script

Optional but expected:

- At least one of Claude Code, Codex, or OpenCode installed
- If using Codex with `sandbox_mode = "workspace-write"`, `~/.memory` will be added to `writable_roots` by the installer

## Install

```bash
git clone https://github.com/MrVampy/memory-plugin.git
cd memory-plugin
bash install.sh
```

For the scheduled hourly maintenance cron (Claude Code only, per-project):

```bash
bash install.sh --cron-project ~/path/to/project-you-open-regularly
```

The cron registers in that project's `.claude/scheduled_tasks.json` and fires only when Claude Code is running there. If you don't pass `--cron-project`, skills are still installed — you just won't get automatic hourly maintenance until you re-run with the flag. Everything else works without it.

## What the installer does

1. Builds the Gleam validator (`gleam build --target javascript`)
2. Installs `js-yaml` next to the build output (runtime dep of the `yay` YAML library)
3. Symlinks `~/.local/bin/memory` to `bin/memory` in the repo — edits to the repo are live immediately
4. Creates `~/.memory/wiki/` (or `$MEMORY_HOME/wiki/` if set)
5. Detects installed coding agents and installs the three skills into each:
   - **Claude Code:** copies the plugin to `~/.claude/plugins/memory/`
   - **Codex:** copies skills to `~/.codex/skills/memory-{recall,create,maintain}/`, adds `~/.memory` to `[sandbox_workspace_write] writable_roots` in `~/.codex/config.toml`
   - **OpenCode:** writes `~/.config/opencode/opencode.json` with a skills path reference
6. If `--cron-project PATH` is given: registers a durable hourly cron task in `<PATH>/.claude/scheduled_tasks.json`

Re-running `install.sh` is safe — it syncs source edits into each agent's cache without clobbering user state. Existing cron tasks preserve their `createdAt` and `lastFiredAt` across re-runs.

## Using it

After install, open any of the supported coding agents. The skills are now available:

**Manual recall** — just ask the agent about a topic that might have prior context:

> *"What's my preferred language for new projects?"*

The agent's `memory:recall` skill instructs it to grep `~/.memory/wiki/` for relevant entries and cite what it finds.

**Explicit remember** — tell the agent to save something:

> *"Remember that I prefer Gleam over Rust for new projects."*

The `memory:create` skill instructs the agent to find existing related entries first, then either update or create a new one via native Write + the validator.

**Manual maintenance** — kick off a maintenance run on demand:

> *"Run memory maintenance."*

The `memory:maintain` skill's dispatcher spawns a background subagent that processes any new session transcripts into the wiki. You return to whatever you were doing; the subagent reports its summary when done.

**Scheduled maintenance** — if you installed with `--cron-project`, it fires hourly while Claude Code is running in that project. Missed fires (Claude Code was closed at the scheduled time) run once on the next session startup.

## Configuration

| Env var | What it controls | Default |
|---|---|---|
| `MEMORY_HOME` | Root directory for wiki, raw/, processed/ | `~/.memory` |
| `PATH` must include `~/.local/bin` | So agents can find the `memory` CLI | — |

If you want the wiki on a different disk (e.g., a dedicated data partition), set `MEMORY_HOME` in your shell rc:

```bash
export MEMORY_HOME=/mnt/data/memory
```

Then re-run `install.sh`.

## Entry format

A wiki entry is markdown with YAML frontmatter:

```markdown
---
id: namespace.entry-name
title: "Human readable title"
kind: free-form-string
tags:
  - tag1
  - tag2
links:
  - target: other.entry.id
    label: why this entry links to that one
meta:
  created: "2026-04-09T10:00:00"
  updated: "2026-04-11T12:00:00"
  sources:
    - <session-id>
---

# Section heading

Body text with [[other.entry.id]] inline references that must match
every frontmatter link target.
```

The validator enforces: required fields, ID format (dot-notation, matches filename), block-style tags (flow-style rejected), bidirectional link integrity, and that every link target resolves to an existing entry. Everything else is the creator's call — including what `kind` means, what namespaces you use, and what tags represent.

See `plugins/skills/maintain/references/wiki-entry-format.md` for the full specification.

## Design principles in one paragraph

The validator is the only place that enforces rules; everything else is agent behavior described in skill documentation. The skill docs describe **structure** (what the validator requires) and **mechanics** (how to use the scripts and tools) but never **content** (what's worth saving, what kind to use, what namespace to pick — those are the creator's judgment, and the wiki evolves over time, so imposing conventions in docs freezes something that should be fluid). The agent reads the wiki to understand what's there; the docs don't try to describe the wiki's contents.

## Repo layout

```
Memory/
├── bin/memory                      CLI launcher (resolves symlinks)
├── src/
│   ├── memory.gleam                Validator CLI (~75 lines, just dispatch)
│   ├── memory/                     Gleam modules: validate, store, frontmatter, entry, body
│   └── ffi/env.mjs                 Tiny JS FFI for env + process.exit
├── plugins/
│   ├── claude-code/.claude-plugin/ Plugin manifest
│   ├── codex/README.md             Codex notes (no code — consumes shared skills)
│   ├── opencode/README.md          OpenCode notes (no code — consumes shared skills)
│   └── skills/                     Shared across all three agents
│       ├── recall/SKILL.md
│       ├── create/SKILL.md
│       └── maintain/
│           ├── SKILL.md            Dispatcher (main agent runs this)
│           ├── scripts/            Discover / filter / process / validate (bash + python)
│           └── references/         Runbook, entry format, transcript formats, maintenance passes
├── install.sh                      One-command install
├── gleam.toml                      Gleam project
└── test/                           Gleam tests
```

## Limitations and caveats

- **Claude Code is the only agent with a durable cron.** Codex and OpenCode have no equivalent. So scheduled automatic maintenance only runs from Claude Code, even though all three agents contribute transcripts to it.
- **The cron is per-project.** Claude Code reads `scheduled_tasks.json` from the project root with no user-global fallback. You have to pick one "home" project where maintenance lives. The cron fires when Claude Code runs in that project; missed fires run on next session startup.
- **OpenCode's transcript format requires SQLite.** The maintain skill's `extract-opencode.py` script queries OpenCode's `opencode.db` directly. Python's stdlib `sqlite3` module is used — no extra dependency — but the implementation assumes OpenCode's current schema.
- **Keyword-based recall, not embeddings.** The recall skill uses plain grep/glob on markdown. For ~100–1000 entries this is fine; for 10k+ entries or vague semantic queries, vector search would help. Defer until you hit the scale.

## Credits

- **Andrej Karpathy** for the ["LLM-maintained persistent wiki"](https://karpathy.bearblog.dev/self-unsupervised-learning/) idea that inspired this architecture
- **The Dendron note-taking system** for the dot-notation namespace pattern
- **Letta (formerly MemGPT)** and **mem0** for prior art on agent-driven memory systems

## License

MIT. See [LICENSE](./LICENSE).
