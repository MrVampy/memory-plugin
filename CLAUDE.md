# Memory — Typed Wiki for Claude Code

A Gleam-based memory system for Claude Code sessions, built on the Karpathy wiki pattern:
LLM incrementally builds and maintains a persistent wiki rather than re-deriving knowledge via RAG.

## Architecture

- **Raw layer**: Session JSONL transcripts (already captured by Claude Code)
- **Wiki layer**: Structured markdown entries with typed frontmatter, validated by Gleam tools
- **Index**: Auto-generated directory of all entries for context injection at session start
- **MCP server**: Gleam → JS, exposes wiki read/search/write to Claude Code

## Design Principles

- **Type the structure, not the content**: Gleam enforces entry shape (id, title, kind, links, meta). The LLM decides what kind an entry is, what sections it has, and how to describe relationships.
- **Validate on write, not after**: The Gleam write tool rejects invalid entries. No linter needed — invalid state never hits disk.
- **Links are inline**: `[[entry-id]]` appears in prose where the relationship naturally occurs. Frontmatter links list is the authoritative index with labels for traversal.
- **Frontmatter/body link consistency**: Every `[[ref]]` in body must appear in frontmatter links, and vice versa.

## Tech Stack

- **Gleam → JS**: MCP server, hooks, validation tools
- **Gleam → Erlang**: Future BEAM deployment on Nucbox
- **Format**: Markdown with YAML frontmatter, validated by Gleam types

## Entry Format

```markdown
---
id: entry-id
title: Human readable title
kind: whatever-the-llm-decides
links:
  - target: other-entry-id
    label: why this entry relates to that one
meta:
  created: 2026-04-09T02:30:00
  updated: 2026-04-09T02:30:00
  sources:
    - session-id
---

# Section Heading

Body text with [[other-entry-id]] inline references...
```
