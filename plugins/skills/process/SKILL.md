---
name: process
description: Process raw session transcripts and inbox notes into typed wiki entries. Processes ~/.memory/raw/ and moves completed files to ~/.memory/processed/.
argument-hint: ""
---

# Compile Raw Material into Wiki

Process uncompiled raw material from `~/.memory/raw/` into typed wiki entries.

Spawn a **background Sonnet subagent** (`model: "sonnet"`, `run_in_background: true`) with the instructions below.

The subagent should:

1. List all files in `~/.memory/raw/` recursively (sessions/, inbox/, etc.)
2. For each file:
   a. Read it. Determine the format (JSONL session transcript, markdown notes, etc.)
   b. Extract knowledge worth keeping — insights, decisions, technical findings, user preferences
   c. Use `memory list` and Grep on `~/.memory/wiki/` to find existing related entries to update or link to
   d. Write each new or updated entry to a temp file (e.g. `/tmp/mem-<id>.md`) with the Write tool
   e. Run `memory create --file /tmp/mem-<id>.md` for each entry. If validation fails, fix the temp file and re-run.
   f. Delete temp files when done
   g. Move the source file to `~/.memory/processed/` (preserving subdirectory structure)
3. Report what was processed and what entries were created/updated.

**Important:** Session transcripts can be large. Focus on extracting the *conclusions* — what was decided, learned, or discovered. Skip the back-and-forth debugging, tool call details, and ephemeral task steps.

## Wiki Location

- **Global wiki:** `~/.memory/wiki/`

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
9. **`memory create` validates on write.** It will reject invalid entries with a list of errors. Fix the temp file and re-run. Never bypass it by writing directly to `~/.memory/wiki/`.
