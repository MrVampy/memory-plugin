---
name: create
description: Save knowledge to persistent memory at ~/.memory/wiki/. Call the memory_create MCP tool whenever you learn or decide something worth keeping for future sessions — user preferences, technical decisions, project context, design rationale. ALWAYS search ~/.memory/wiki/ first (using your grep/ripgrep tool) to find existing related entries — use the same id to update an existing entry rather than creating a duplicate. The wiki is agent-driven; nothing gets saved unless you save it.
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

All wiki mutations go through the `memory_create` MCP tool, which validates on write
and rejects invalid entries. Never write to `~/.memory/wiki/` directly with file-write
tools — that bypasses validation.

1. **Search for existing entries** by grepping `~/.memory/wiki/` for the topic, or by globbing `~/.memory/wiki/namespace.*.md` to browse a topic area. See the recall skill for full discovery patterns.
2. **Read full entries** with your file-read tool on `~/.memory/wiki/<id>.md` when you need to update one.
3. **Create or update an entry:** call the `memory_create` MCP tool with the full markdown as the `markdown` argument. It validates and writes in one call. If validation fails, the tool returns the errors — fix the markdown and call again. `memory_create` is an upsert: same id replaces the existing entry.
4. **Delete an entry** with the `memory_delete` MCP tool. It refuses if other entries link to it; pass `force=true` to override.

## What Goes Where

- **Global wiki** (`~/.memory/wiki/`): preferences, feedback rules, technology knowledge, personal insights, people, general decisions — anything useful across projects.
- **Project wiki** (`.memory/wiki/`): architecture decisions, bug context, deployment notes, conventions — anything specific to one codebase.

## Navigation

See the recall skill for the full discovery patterns. Short version: grep `~/.memory/wiki/` for content keywords, glob `~/.memory/wiki/namespace.*.md` to browse a namespace, read `~/.memory/wiki/<id>.md` for full entries. Follow `[[id]]` references in entry bodies to traverse related knowledge.

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
- Instructions to: (1) call `memory_create` MCP tool for each entry with full markdown, (2) if it returns validation errors, fix the markdown and call again
- Tell it to grep `~/.memory/wiki/` first (with whatever search tool the platform provides) to find existing related entries to link to or update

The `memory_create` tool validates entries at write time and rejects invalid ones, so there is no separate validation step.

## Archiving full transcripts (optional)

Proactive saves via `memory_create` are the primary path. But if a conversation has been long and dense and you suspect you may not have captured every useful insight in real time, you can also archive the full session transcript for later batch processing by calling the `memory_inbox` MCP tool with the transcript path.

The tool auto-detects the format (Claude Code or Codex). The filtered transcript lands in `~/.memory/raw/inbox/` and can be processed later via the `memory:process` skill — which extracts wiki-worthy knowledge that the live `memory_create` calls might have missed.

This is opt-in. Use it when:
- The conversation covered many topics and you can't be sure you saved all of them
- The user explicitly asks to "save this conversation"
- You want a fallback safety net before clearing the conversation context

To find the current transcript path:
- **Claude Code:** look in `~/.claude/projects/<project-slug>/<session-id>.jsonl`. The session id is usually visible in your environment context.
- **Codex:** the most recent file in `~/.codex/sessions/<year>/<month>/<day>/`.

Do NOT call `memory inbox` on every conversation — it's a fallback, not a replacement for proactive `memory create`.
