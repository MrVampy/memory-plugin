---
name: memory
description: Read, write, and navigate the typed wiki memory system. Use when you need to store knowledge for future sessions or recall previously stored knowledge.
---

# Memory Wiki

You have access to a persistent, typed wiki for storing and retrieving knowledge across sessions.

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
5. **After any wiki write/edit**, the validator runs automatically and will report errors. Fix any errors it finds.
6. **Regenerate the index** after changes: `memory index ~/.claude/.memory/wiki`

## What Goes Where

- **Global wiki** (`~/.claude/.memory/wiki/`): preferences, feedback rules, technology knowledge, personal insights, people, general decisions — anything useful across projects.
- **Project wiki** (`.memory/wiki/`): architecture decisions, bug context, deployment notes, conventions — anything specific to one codebase.

## Navigation

The index shows every entry with its id, title, kind, and link labels. Use this to decide what to read. Follow `[[links]]` to traverse related knowledge. The labels tell you whether a link is worth following without opening the target.
