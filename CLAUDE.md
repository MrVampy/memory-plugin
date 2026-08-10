# Memory — project guide for coding agents

A persistent, typed wiki shared across Claude Code, Codex, and OpenCode. The user interacts with the wiki via three skills (`recall`, `create`, `maintain`); the project ships one CLI (`memory validate`) that enforces structural consistency.

This file is the project-level context for coding agents working on the repo itself. For the user-facing overview, see [README.md](./README.md).

## Architecture in one sentence

**One tool (validator), three skills (recall/create/maintain), everything else native** — the agent uses Read/Edit/Write/Bash-rm/Grep/Glob directly against `~/.memory/wiki/`, with `memory validate` as the single gate that keeps the wiki structurally consistent.

## What the validator enforces

The Gleam validator (`src/memory/validate.gleam`) rejects entries that violate any of these. Don't weaken these rules casually — they're the only thing keeping the wiki graph coherent:

1. Required top-level fields: `id`, `title`, `kind`, `tags`, `links`, `meta`
2. `id` must contain at least one dot (dot-notation namespace)
3. `id` must match the filename (`<id>.md`)
4. `tags` must parse as a block-style YAML list (flow-style `[a, b]` is rejected)
5. Tags must be non-empty strings without spaces
6. Bidirectional link integrity: every `[[ref]]` in body has a matching `links` entry, and every `links[].target` has a matching `[[ref]]` in body
7. Link targets must resolve to existing entries
8. Every link has a non-empty `label`
9. Required meta fields: `meta.created`, `meta.updated`, `meta.sources` (list)
10. Timestamps are quoted ISO 8601 strings

**Everything else is free.** The validator does not care about title wording, `kind` value (any non-empty string), namespace choice, body structure, or tag meaning. Those are the creator's call. Do not add rules for content; add rules only for structure.

## What each skill is for

- **`plugins/skills/recall/`** — *live, agent-driven discovery.* The agent searches `~/.memory/wiki/` with native Read/Grep/Glob when the current task needs prior context. No hooks, no auto-injection. The skill description (always in the system reminder) is the trigger.

- **`plugins/skills/create/`** — *live, explicit-only writes.* The agent writes to the wiki **only** when the user directly asks ("remember that X", "update the entry about Y", "delete the memory about Z"). Uses native Write/Edit/Bash-rm + `memory validate` as the gate. Does not save proactively — proactive capture is the maintain skill's job.

- **`plugins/skills/maintain/`** — *scheduled, background subagent.* Fires hourly via Claude Code's durable cron. Walks session transcripts from all three agents, extracts knowledge into the wiki, runs maintenance passes. SKILL.md is the dispatcher (run by the main agent to spawn a background subagent); `references/workflow.md` is the runbook (read by the subagent).

## Repo layout

```
Memory/
├── bin/memory                      # CLI launcher (bash, resolves symlinks)
├── src/memory.gleam                # Validator CLI (~75 lines, just dispatch)
├── src/memory/                     # Gleam modules: validate, store, frontmatter, entry, body
├── src/ffi/env.mjs                 # Tiny JS FFI for env + process.exit
├── plugins/
│   ├── claude-code/.claude-plugin/ # Plugin manifest (identity + skills pointer)
│   ├── codex/README.md             # Codex-specific notes (no code)
│   ├── opencode/README.md          # OpenCode-specific notes (no code)
│   └── skills/                     # Shared across all three agents
│       ├── recall/SKILL.md
│       ├── create/SKILL.md
│       └── maintain/
│           ├── SKILL.md            # Dispatcher (main agent runs this)
│           ├── scripts/            # Mechanical work (discover, filter, process)
│           └── references/         # Runbook + entry format + formats + passes
├── install.sh                      # Build + install per detected agent
├── flake.nix                       # Reproducible validator package and checks
├── nix/package.sh                  # Package lifecycle outside the Nix expression
├── gleam.toml                      # Gleam project
└── test/                           # Gleam tests
```

## Working on this repo

**Default to editing skills, not Gleam.** The validator is deliberately small and should stay that way. Most changes — how the wiki gets populated, what counts as a maintenance pass, what the create workflow looks like — are skill-level concerns. Edit SKILL.md files and scripts.

**When touching the validator**, the rule is: add structural rules, never content rules. "Tags must be non-empty" is structural. "Tags must be lowercase" would be content-level and was deliberately not enforced.

**When touching install.sh**, don't add migration code. The installer should be oriented toward fresh installs. If you need to migrate legacy state from a previous version of the plugin, do it in a separate one-shot script, not inside `install.sh`.

**The validator package belongs here.** Consumers use the package exported by this repository's flake. Keep build logic out of consumer repositories and keep imperative package lifecycle work in the shellchecked `nix/package.sh`, not embedded in a Nix expression.

**When touching skill docs**, don't impose content conventions. The docs describe structure (what the validator enforces) and mechanics (how to use the scripts and tools). What the agent saves, what kind it uses, what namespace it picks — those are the agent's call at runtime.

**Install-time substitution.** `plugins/skills/maintain/SKILL.md` contains a `%%SKILL_DIR%%` placeholder in the dispatcher's subagent spawn prompt. `install.sh` runs `sed` on the copied file to replace this with the absolute path of the skill install directory — different for each agent (Claude Code, Codex, OpenCode). If you add more install-time placeholders, use the same `%%NAME%%` convention and add a matching `sed` line in each per-agent install block.

## Running locally

Prerequisites: `gleam`, `node`, `npm`, `python3`, `bash`.

```bash
bash install.sh [--cron-project PATH]
```

The installer builds the Gleam project, symlinks `bin/memory` to `~/.local/bin/memory`, creates `~/.memory/wiki/`, copies skills into each detected agent's skill directory, and (optionally) registers the maintenance cron in the specified project's `.claude/scheduled_tasks.json`.

After install:

```bash
memory validate   # smoke test — should print "✓ N entries, 0 errors"
```

## The wiki is user state

`~/.memory/wiki/` (or `$MEMORY_HOME/wiki/`) contains the user's personal knowledge. It is **not** part of this repo. Don't commit it, don't read it looking for what the code does — read the source. The wiki is per-user, per-machine state that the code produces, like a database file.
