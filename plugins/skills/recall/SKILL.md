---
name: recall
description: Search the wiki for specific knowledge. Use when recalled memory summaries are insufficient, when you need deeper context, or when you want to search for a specific topic.
argument-hint: "[search terms]"
---

# Memory Recall

Search the persistent wiki at `~/.memory/wiki/` for knowledge stored in previous sessions.

## Context

A recall hook automatically surfaces wiki entry summaries matching the user's message. These appear as `UserPromptSubmit hook additional context` at the start of each turn. This skill is for when those summaries are insufficient and you need more.

## When to Use

- The automatic recall surfaced relevant entries but the summaries lack the detail you need
- You want to search for a topic not covered by the automatic recall
- You need to follow links between entries to build a fuller picture

## How to Search

1. **By tag:** `grep -rl "tags:" ~/.memory/wiki/ | xargs grep -l "keyword"`
2. **By content:** `grep -rl "keyword" ~/.memory/wiki/`
3. **By namespace:** `ls ~/.memory/wiki/namespace.*.md`
4. **By ID:** Read `~/.memory/wiki/<id>.md` directly if you know the entry ID from a recalled summary

## How to Navigate

- **Read full entries** — summaries from the recall hook show id, title, tags, and links. Read the full `.md` file for complete content.
- **Follow links** — entries reference each other via `[[id]]` notation and `links:` in frontmatter. If one entry is relevant, its linked entries likely are too.
- **Chain searches** — find an entry by keyword, read it, then follow its links to related entries.

## Arguments

`$ARGUMENTS` — search terms to grep across wiki entries. If empty, list all available entries with `ls ~/.memory/wiki/*.md`.
