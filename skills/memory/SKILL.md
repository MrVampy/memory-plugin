---
name: memory
description: Read, write, and navigate the typed wiki memory system. Use when you need to store knowledge for future sessions or recall previously stored knowledge.
argument-hint: "[compile] [what to remember]"
---

# Memory Wiki

You have access to a persistent, typed wiki for storing and retrieving knowledge across sessions.

## Commands

- **`/memory <what to remember>`** — Save something specific to the wiki right now. Read the index, create or update the appropriate entry.
- **`/memory compile`** — Process uncompiled raw material from `~/.claude/.memory/raw/`. Read each file, extract knowledge worth keeping, write wiki entries, then move the source to `~/.claude/.memory/processed/`.

Arguments: $ARGUMENTS

## Wiki Location

- **Global wiki:** `~/.claude/.memory/wiki/` — knowledge that spans all projects
- **Project wiki:** `.memory/wiki/` in the current repo — project-specific knowledge (future)

## Entry Format

Every wiki entry is a markdown file with YAML frontmatter:

```markdown
---
id: entry-id-slug
title: Human readable title
kind: whatever-you-decide
links:
  - target: other-entry-id
    label: why this entry relates to that one
meta:
  created: "2026-04-09T03:00:00"
  updated: "2026-04-09T03:00:00"
  sources:
    - session-id
---

# Section Heading

Body text with [[other-entry-id]] inline references where the
relationship naturally occurs in context.
```

## Rules

1. **Frontmatter is typed and validated.** Every entry must have: `id`, `title`, `kind`, `links` (list), `meta.created`, `meta.updated`, `meta.sources` (list).
2. **Links must appear in both places.** Every `[[ref]]` in the body must have a corresponding entry in `links`, and vice versa. Every link must have a non-empty `label`.
3. **Link targets must resolve.** Every `links[].target` must be the `id` of an existing entry.
4. **You decide the content.** The `kind`, section headings, body content, and link labels are yours to determine. The structure is enforced; the content is free.
5. **Timestamps are ISO 8601 strings.** Always quote them in YAML.
6. **Sources track provenance.** Add the current session ID to `meta.sources` when creating or updating an entry.

## Workflow

1. **Read the index** at `~/.claude/.memory/wiki/INDEX.md` to see what exists.
2. **Follow links** by reading entries referenced in the index or in other entries.
3. **Create entries** using the Write tool — write the full markdown file to `~/.claude/.memory/wiki/<id>.md`.
4. **Update entries** using the Edit tool — modify frontmatter or body as needed. Update `meta.updated` and add the session to `meta.sources`.
5. **After any wiki write/edit**, the Stop hook validates and regenerates the index automatically.

## What Goes Where

- **Global wiki** (`~/.claude/.memory/wiki/`): preferences, feedback rules, technology knowledge, personal insights, people, general decisions — anything useful across projects.
- **Project wiki** (`.memory/wiki/`): architecture decisions, bug context, deployment notes, conventions — anything specific to one codebase.

## Navigation

The index shows every entry with its id, title, kind, and link labels. Use this to decide what to read. Follow `[[links]]` to traverse related knowledge. The labels tell you whether a link is worth following without opening the target.

## Automatic Memory (IMPORTANT)

You MUST proactively save knowledge to the wiki during conversations. Do not wait to be asked. After completing a task or discussion, assess whether anything worth remembering emerged:

- **Insights or decisions** — anything the user or you concluded that would be useful in future sessions
- **Technical knowledge** — research findings, how things work, architecture understanding
- **User preferences and feedback** — how the user wants to work, corrections they gave, approaches they confirmed
- **Project context** — decisions made, why something was done a certain way, what was tried and rejected

**When NOT to save:**
- Ephemeral task details (specific file edits, debugging steps)
- Things already in the wiki (check the index first)
- Information derivable from code or git history

**How:** Always use a **background Sonnet subagent** for memory writes. Spawn it with the Agent tool:

```
Agent({
  description: "Save wiki memory",
  model: "sonnet",
  run_in_background: true,
  prompt: "You are the memory writer for a typed wiki system. <include full context of what to save, the current INDEX.md content, and the entry format rules from this skill>. Write the wiki entry/entries to ~/.claude/.memory/wiki/<id>.md using the Write tool. Follow all rules: frontmatter with id/title/kind/links/meta, [[refs]] in body matching frontmatter links, ISO 8601 timestamps. Check the index for existing related entries and link to them."
})
```

The subagent runs on Sonnet in the background — the main conversation continues uninterrupted. The Stop hook validates and regenerates the index when the subagent finishes.

**Important:** Include the current wiki index content in the subagent prompt so it knows what exists and can link to relevant entries.

## Compile Mode (`/memory compile`)

When invoked with `compile`, spawn a **Sonnet subagent** (foreground, since the user explicitly asked for compilation):

The subagent should:

1. List all files in `~/.claude/.memory/raw/` recursively (sessions/, inbox/, etc.)
2. For each unprocessed file:
   a. Read it. Determine the format (JSONL session transcript, markdown notes, etc.)
   b. Extract knowledge worth keeping — insights, decisions, technical findings, user preferences
   c. Check the wiki index for existing related entries — update them or create new ones
   d. Write wiki entries with proper links to existing entries
   e. Move the source file to `~/.claude/.memory/processed/` (preserving subdirectory structure)
3. Report what was processed and what entries were created/updated.

**Important:** Session transcripts can be large. Focus on extracting the *conclusions* — what was decided, learned, or discovered. Skip the back-and-forth debugging, tool call details, and ephemeral task steps.
