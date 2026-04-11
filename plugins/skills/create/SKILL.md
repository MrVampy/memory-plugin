---
name: create
description: Explicit memory writes — call ONLY when the user directly asks you to remember, update, or delete something in persistent memory. Examples of triggers - "remember that I prefer X", "save this decision", "stop remembering Y", "update the entry about Z". You do NOT save proactively — a scheduled maintenance subagent processes session transcripts into the wiki on its own cycle. Use native Read/Edit/Write/Bash-rm on ~/.memory/wiki/ and always run `memory validate` after any change.
argument-hint: "[what to remember/update/delete]"
---

# Explicit memory writes

This skill is for **explicit user-requested** memory operations only. If the user says *"remember that X"*, *"save this"*, *"update the entry about Y"*, *"delete the memory about Z"* — that's this skill.

**Do NOT use this skill to proactively save things.** Proactive capture of conversation content is handled by a scheduled maintenance subagent that runs on its own cycle. Your job here is only to respond to explicit user requests for memory writes.

## Toolbox

The memory system has exactly one custom tool: **`memory validate`**, a Bash CLI that validates the wiki at `~/.memory/wiki/`. Everything else uses your native tools:

- **Read** — inspect an existing entry before updating
- **Edit** — modify an existing entry in place
- **Write** — create a new entry or overwrite an existing one
- **Grep / Glob** — find related entries before writing (avoid duplicates)
- **Bash `rm`** — delete an entry
- **Bash `memory validate`** — the gate. Run after every mutation.

Never skip the validate step. If validation fails, fix the entry and re-validate until clean.

## Workflow by operation

### Create a new entry

1. **Search first:** grep `~/.memory/wiki/` for related topics — an existing entry you should update instead of duplicating.
2. **Compose the markdown** in memory. See `## Entry format` below for the shape.
3. **Write** the file to `~/.memory/wiki/<id>.md` using the Write tool.
4. **Validate:** run `memory validate` via Bash.
5. **If errors:** read the errors, Edit the file to fix them, validate again. Repeat until clean.

### Update an existing entry

1. **Read** the existing entry at `~/.memory/wiki/<id>.md`.
2. **Edit** in place with the Edit tool, or Write the full replacement.
3. **Update `meta.updated`** to the current ISO timestamp.
4. **Add the current session id** to `meta.sources` (append, don't replace).
5. **Validate:** `memory validate`. Fix errors if any.

### Delete an entry

1. **Check for inbound links** before deleting: grep `~/.memory/wiki/` for `[[<id>]]` references. Any hits mean another entry will be broken by the delete.
2. **If links exist:** either fix the linking entries first (remove the references) or confirm with the user that they want the links broken.
3. **Delete:** `rm ~/.memory/wiki/<id>.md` via Bash.
4. **Validate:** `memory validate`. If errors (you missed an inbound link), either restore the entry from memory (you should have Read it first) or clean up the newly-broken linkers.

The "always grep for inbound links before deleting" step is your safety net — the validator only catches the problem *after* the fact, and by then the file is gone.

## Entry format

Every wiki entry is markdown with YAML frontmatter:

```markdown
---
id: namespace.entry-name
title: "Human readable title"
kind: design-decision
tags:
  - tag1
  - tag2
  - tag3
links:
  - target: other.entry.id
    label: why this links to that
meta:
  created: "2026-04-09T10:00:00"
  updated: "2026-04-11T12:00:00"
  sources:
    - <previous-sources>
    - <current-session-id>
---

# Section heading

Body text with [[other.entry.id]] inline references that must match the
frontmatter `links` entries.
```

### Validator rules (the validator will reject violations)

1. **IDs use dot-notation.** e.g. `lang.gleam.actors`, `cognitive.intp.profile`. Filename must match `<id>.md`.
2. **Tags are block-style YAML.** One per line, indented with `- `. NOT flow-style `[a, b]` — the parser rejects flow-style.
3. **Tags are lowercase slugs.** No spaces.
4. **Every `[[ref]]` in the body has a matching entry in `links`.** And vice versa. The validator checks both directions.
5. **Every `links[].target` resolves to an existing entry.** (Exception: removing a target is valid as long as nothing references it.)
6. **Every link has a non-empty `label`.**
7. **All meta fields required:** `created`, `updated`, `sources` (list).
8. **Timestamps are quoted ISO 8601 strings.**

When updating an existing entry, **keep the original `created` timestamp** and only update `meta.updated`.

## Namespace conventions

Before creating a new id, browse the existing namespaces with glob to pick a consistent one. Common namespaces you'll see:

- `cognitive.*` — user's cognitive profile, MBTI, preferences
- `lang.<language>.*` — language-specific knowledge
- `tools.*` — tooling decisions
- `arch.*` — architecture decisions
- `strategy.*` — strategic thinking
- `concepts.*` — general concepts

Pick an existing namespace when possible. Create a new one only when nothing fits.

## What NOT to do

- **Don't proactively save things** that "seem interesting" during a conversation. The scheduled maintenance subagent does that based on transcripts. Only save what the user explicitly asks you to save.
- **Don't skip the grep-for-existing step.** Duplicate entries under different ids are the worst kind of mess to clean up.
- **Don't delete without checking inbound links first.** The validator catches it post-hoc, but by then you've already broken things.
- **Don't write anything to `~/.memory/wiki/` without validating immediately after.**
- **Don't spawn a subagent for this.** Explicit user-requested writes are fast (one or two entries), you can do them in the main thread. The scheduled maintenance flow uses subagents because it processes many entries in batch.

## A typical interaction

User: *"Remember that I prefer Gleam over Rust for new projects."*

Agent:

1. Grep `~/.memory/wiki/` for "Gleam" and "Rust" — find candidates like `lang.gleam.full-stack-decision.md`.
2. Read the most relevant candidate. If it already captures this preference, update it. If not, create a new entry under `user.preferences.language` or similar.
3. Write the entry via Write tool.
4. Run `memory validate` via Bash.
5. If clean, report: *"Saved as `user.preferences.language`."*
6. If errors, fix and retry.

One turn, a handful of tool calls, the user's knowledge is now durable.
