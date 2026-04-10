---
name: recall
description: Search persistent memory for relevant prior knowledge. Call this at the start of any non-trivial task to surface what you already know about the topic. Use whenever the user asks about something that might have been discussed or decided before.
argument-hint: "[search terms]"
---

# Memory Recall

You have a persistent typed wiki at `~/.memory/wiki/` containing knowledge from previous sessions — user preferences, technical decisions, project context, design rationale, personal facts about the user. Recall is **agent-driven**: nothing surfaces automatically. You must call recall when you need context.

## When to call recall (DO THIS PROACTIVELY)

**At the start of any non-trivial task**, before doing other work:
- The user asks about a topic, project, or decision → recall it first
- The user mentions a name, technology, or concept → check if there's prior context
- You're about to make a recommendation → check if a related decision already exists
- You're starting work in an unfamiliar area → look for namespace coverage

**The cost of an unnecessary recall is small. The cost of a missed recall is acting on incomplete context.** When in doubt, call it.

## How to call

The fastest path is the CLI:

```bash
memory recall "your search terms here"
```

This returns the top 5 matching entry summaries (id, title, kind, tags, links). It uses keyword matching, not embeddings — so use distinctive terms from the topic, not generic words like "thing" or "system".

## How to dig deeper

After `memory recall` surfaces candidate entries:

1. **Read the full entry** with the Read tool: `Read ~/.memory/wiki/<id>.md`
2. **Follow links** in the body (`[[other.id]]`) or frontmatter (`links:`) — related entries are usually as relevant as the matched one
3. **Browse a namespace** when you want everything in a topic area: `memory list <namespace>` (e.g. `memory list lang.gleam`)
4. **Search by tag or content** with grep when keyword recall misses: `grep -rl "tag-name" ~/.memory/wiki/`

## What to do with what you find

- Cite the entry id when referencing recalled knowledge so the user knows its source
- If a recalled entry seems wrong or outdated, *update it* via `memory create` (the create skill explains how) — don't just work around it
- If two entries cover the same topic with conflicting info, surface the conflict to the user

## What NOT to do

- Don't skip recall because the question seems simple. Simple questions often have prior context you don't have in your weights.
- Don't only rely on recall hits — also use Read/Glob to explore the wiki when the search misses
- Don't pretend you "remember" something — recall it explicitly so the user can verify the source
