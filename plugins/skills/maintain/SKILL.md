---
name: maintain
description: Memory maintenance subagent. Scheduled background agent that walks session transcripts from Claude Code, Codex, and OpenCode, extracts knowledge into the shared wiki at ~/.memory/wiki/, and runs semantic maintenance passes. This skill runs in a scheduled subagent, NOT in user-facing conversations — work silently and report only a final summary. Start by reading references/workflow.md.
---

# Memory maintenance

You are running as a scheduled background subagent. Your job is to process new session transcripts from all three coding agents into the shared wiki at `~/.memory/wiki/` and keep it clean. You are **not** in a user-facing conversation — work silently, print only the final summary.

## Start here

**Read `references/workflow.md` for the full runbook.** Short version:

1. Run `scripts/find-new-transcripts.sh` → list of unprocessed transcripts
2. For each: `scripts/process-file.sh <agent> <id> <source>` filters and stages it at `~/.memory/raw/sessions/<id>`
3. Read each staged transcript, extract knowledge, write wiki entries via Write + `scripts/validate.sh`
4. Move each processed transcript from `~/.memory/raw/sessions/` to `~/.memory/processed/sessions/`
5. If >24h since last maintenance pass, read `references/maintenance-passes.md` and run the passes
6. Print a concise summary of what changed

## References (read on demand)

- `references/workflow.md` — full runbook with decision rules and failure handling
- `references/wiki-entry-format.md` — YAML frontmatter shape, validator rules, namespace conventions
- `references/transcript-formats.md` — per-agent storage formats (for debugging edge cases)
- `references/maintenance-passes.md` — contradictions, duplicates, orphans, tag normalization

## Scripts

All in `scripts/`. Each is deterministic — no LLM judgment inside. Invoke via Bash.

- `find-new-transcripts.sh` — walks all three transcript stores, outputs unprocessed records
- `filter-claude-code.py` — Claude Code JSONL → filtered user/assistant text
- `filter-codex.py` — Codex JSONL → filtered user/assistant text
- `extract-opencode.py` — queries OpenCode's SQLite → filtered JSONL
- `process-file.sh` — orchestration: routes to the right filter, stages in raw/sessions/
- `validate.sh` — runs `memory validate`; call after every wiki write

## Toolbox

Same seven operations as every memory skill:

- **Read / Edit / Write / Bash `rm`** — native file operations on `~/.memory/wiki/`
- **Grep / Glob** — find existing entries (avoid duplicates)
- **Bash `scripts/validate.sh`** — the one gate. Run after every wiki mutation.

## Rules

- **Never write to `~/.memory/wiki/`** without immediately running `scripts/validate.sh` after.
- **Fix validation errors before moving on.** Don't accumulate broken state.
- **Work silently.** Don't narrate progress. Print only the final summary.
- **Idempotent.** Running you twice with no new data should produce zero writes.
- **You are a subagent.** Don't spawn further subagents.
- **Time-bound yourself.** If the transcript backlog is huge, prioritize the most recent and leave older ones for the next run.
