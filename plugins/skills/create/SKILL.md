---
name: create
description: Save knowledge to persistent memory. Call this whenever you learn or decide something worth keeping for future sessions — user preferences, technical decisions, project context, design rationale. The wiki is agent-driven; nothing gets saved unless you save it.
argument-hint: "[what to remember]"
---

# Memory Wiki

You have access to a persistent, typed wiki for storing and retrieving knowledge across sessions. The wiki is **agent-driven** — there are no automatic save hooks. Nothing enters memory unless you explicitly write it.

## Two operating principles

**1. Always recall before creating.** Before writing a new entry, run `memory recall "<topic keywords>"` to check if a related entry already exists. If it does, *update that entry* (use the same id — `memory create` upserts) rather than creating a duplicate. Run `memory list <namespace>` to browse a topic area.

**2. Save proactively, not reactively.** Don't wait for the user to say "remember this." After completing any task or significant exchange, ask yourself: *did anything come up that I'd want to know in a future session?* If yes, save it. Specifically:
- Insights or decisions reached
- Technical findings, how things work, architecture understanding
- User preferences, feedback, corrections
- Project context — why something was done a certain way, what was tried and rejected

## Command

Arguments: $ARGUMENTS

**`/memory <what to remember>`** — Save something specific to the wiki right now. Search existing entries first, then create or update the appropriate entry.

## Wiki Location

- **Global wiki:** `~/.memory/wiki/` — knowledge that spans all projects
- **Project wiki:** `.memory/wiki/` in the current repo — project-specific knowledge (future)

## Entry Format

Every wiki entry is a markdown file with YAML frontmatter:

```markdown
---
id: namespace.entry-name
title: Human readable title
kind: whatever-you-decide
tags:
  - tag1
  - tag2
  - tag3
links:
  - target: namespace.other-entry
    label: why this entry relates to that one
meta:
  created: "2026-04-09T03:00:00"
  updated: "2026-04-09T03:00:00"
  sources:
    - session-id
---

# Section Heading

Body text with [[namespace.other-entry]] inline references where the
relationship naturally occurs in context.
```

## Rules

1. **IDs use dot-notation namespaces.** e.g. `lang.gleam.actors`, `cognitive.intp.profile`. Use Grep to search `~/.memory/wiki/` for existing namespaces and use a consistent one, or create a new namespace if nothing fits. The filename must be `<id>.md`.
2. **Tags are lowercase slugs.** Block-style YAML list (one per line, indented with `- `). No spaces in tags. Use 2-5 tags per entry for cross-cutting discovery. Flow-style (`tags: [a, b]`) is NOT supported by the parser.
3. **Frontmatter is typed and validated.** Every entry must have: `id`, `title`, `kind`, `tags` (list), `links` (list), `meta.created`, `meta.updated`, `meta.sources` (list).
4. **Links must appear in both places.** Every `[[ref]]` in the body must have a corresponding entry in `links`, and vice versa. Every link must have a non-empty `label`.
5. **Link targets must resolve.** Every `links[].target` must be the `id` of an existing entry.
6. **You decide the content.** The `kind`, section headings, body content, and link labels are yours to determine. The structure is enforced; the content is free.
7. **Timestamps are ISO 8601 strings.** Always quote them in YAML.
8. **Sources track provenance.** Add the current session ID to `meta.sources` when creating or updating an entry.

## Workflow

All wiki mutations go through the `memory` CLI. The CLI validates on write
and rejects invalid entries — there is no separate validation step. Never
write to `~/.memory/wiki/` directly with the Write or Edit tools.

1. **Search for existing entries** with `memory list <namespace>` or by reading the recall hook context already injected into your prompt.
2. **Read full entries** with the Read tool on `~/.memory/wiki/<id>.md` when you need details beyond the recall summary.
3. **Create or update an entry:**
   a. Use the Write tool to write the full markdown to a temp file (e.g. `/tmp/mem-<id>.md`)
   b. Run `memory create --file /tmp/mem-<id>.md`
   c. If validation fails, fix the temp file and re-run. The CLI prints any errors.
   d. On success, delete the temp file.
   `memory create` is an upsert — it creates new entries and replaces existing ones with the same id.
4. **Delete an entry** with `memory delete <id>`. The CLI refuses if other entries link to it; pass `--force` to override.

## What Goes Where

- **Global wiki** (`~/.memory/wiki/`): preferences, feedback rules, technology knowledge, personal insights, people, general decisions — anything useful across projects.
- **Project wiki** (`.memory/wiki/`): architecture decisions, bug context, deployment notes, conventions — anything specific to one codebase.

## Navigation

Search the wiki using Grep and Glob — the structured frontmatter (tags, IDs, links) is designed for this. Use `grep -rl "tags:.*term"` to find entries by tag, `ls wiki/namespace.*.md` to browse a namespace, or `grep -rl "term"` for full-text search. Follow `[[links]]` to traverse related knowledge.

## Automatic Memory (IMPORTANT)

You MUST proactively save knowledge to the wiki during conversations. Do not wait to be asked. After completing a task or discussion, assess whether anything worth remembering emerged:

- **Insights or decisions** — anything the user or you concluded that would be useful in future sessions
- **Technical knowledge** — research findings, how things work, architecture understanding
- **User preferences and feedback** — how the user wants to work, corrections they gave, approaches they confirmed
- **Project context** — decisions made, why something was done a certain way, what was tried and rejected

**When NOT to save:**
- Ephemeral task details (specific file edits, debugging steps)
- Things already in the wiki (search first)
- Information derivable from code or git history

**How:** Spawn a background subagent for memory writes. The subagent **MUST** run in the background — never block the main conversation on a memory write.

Use the appropriate mechanism for your platform:

**Claude Code:**
```
Agent({
  description: "Save wiki memory",
  model: "sonnet",
  run_in_background: true,
  prompt: "<full briefing — see below>"
})
```
The `run_in_background: true` flag is required. Without it, the main conversation blocks waiting for the wiki write.

**Codex:**
Use the `subagents` mechanism (`/subagents` slash command) and dispatch the task asynchronously. Do not await its completion in the main turn.

**Briefing for the subagent:**
- Full context of what knowledge to save
- The entry format rules from this skill (frontmatter shape, link rules, ID convention)
- Instructions to: (1) write each entry to a temp file with the Write tool, (2) run `memory create --file /tmp/mem-<id>.md` for each, (3) fix and re-run if validation fails, (4) delete temp files when done
- Tell it to use `memory list` and Grep on `~/.memory/wiki/` to find existing related entries to link to

`memory create` validates entries at write time and rejects invalid ones, so there is no separate validation step.

## Archiving full transcripts (optional)

Proactive saves via `memory create` are the primary path. But if a conversation has been long and dense and you suspect you may not have captured every useful insight in real time, you can also archive the full session transcript for later batch processing:

```bash
memory inbox <path-to-current-transcript>
```

The CLI auto-detects the format (Claude Code or Codex). The filtered transcript lands in `~/.memory/raw/inbox/` and can be processed later via the `memory:process` skill — which extracts wiki-worthy knowledge that the live `memory create` calls might have missed.

This is opt-in. Use it when:
- The conversation covered many topics and you can't be sure you saved all of them
- The user explicitly asks to "save this conversation"
- You want a fallback safety net before clearing the conversation context

To find the current transcript path:
- **Claude Code:** look in `~/.claude/projects/<project-slug>/<session-id>.jsonl`. The session id is usually visible in your environment context.
- **Codex:** the most recent file in `~/.codex/sessions/<year>/<month>/<day>/`.

Do NOT call `memory inbox` on every conversation — it's a fallback, not a replacement for proactive `memory create`.
