# Wiki entry format

Every wiki entry is markdown with YAML frontmatter, stored at `~/.memory/wiki/<id>.md`.

## Full example

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
    - <session-id-1>
    - <session-id-2>
---

# Section heading

Body text with [[other.entry.id]] inline references that must match
every frontmatter link target.

# Another section

More body content. Additional [[other.entry.id]] references can appear
anywhere in the body — they just need to be matched by the frontmatter
links list.
```

## Frontmatter fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | Dot-notation, lowercase, must match `<id>.md` filename |
| `title` | string | yes | Quoted if it contains special YAML chars |
| `kind` | string | yes | Free-form (you pick): `design-decision`, `technical`, `insight`, `concept`, `personal`, `setup`, `strategy`, etc. |
| `tags` | list | yes | Block-style YAML list, lowercase slugs, no spaces, no flow-style |
| `links` | list | yes | Each entry has `target` and `label` |
| `meta.created` | ISO 8601 | yes | Quoted timestamp. **Preserve on update.** |
| `meta.updated` | ISO 8601 | yes | Quoted timestamp. **Update on every modification.** |
| `meta.sources` | list | yes | Provenance trail. **Append on update, never replace.** |

## Validator rules

The `memory validate` CLI will reject entries that violate any of these:

1. **ID format** — dot-notation (at least one dot), lowercase, segments are hyphenated slugs
2. **ID matches filename** — `cognitive.intp.profile` must be in `cognitive.intp.profile.md`
3. **Tags are block-style YAML** — one per line, indented with `- `. **NOT** flow-style `[a, b, c]` — the parser rejects flow-style and returns a parse error
4. **Tags are lowercase slugs** — no spaces, no uppercase
5. **Link integrity — bidirectional** — every `[[ref]]` in the body must have a matching entry in the frontmatter `links` list, AND every `links[].target` must have a matching `[[ref]]` somewhere in the body
6. **Link targets resolve** — every `links[].target` must be the `id` of an existing entry in the wiki
7. **Labels required** — every link must have a non-empty `label`
8. **Meta fields required** — `created`, `updated`, `sources` (list)
9. **Timestamps quoted** — ISO 8601 strings wrapped in quotes

## Updating an existing entry

When you update an entry:

- **Keep the original `meta.created`** — it marks when the knowledge was first captured
- **Set `meta.updated`** to the current ISO timestamp
- **Append the current transcript/session id to `meta.sources`** — don't replace, accumulate provenance
- **Preserve links you don't need to change** — editing should be additive when possible
- **When adding a new `[[ref]]` to the body, add the matching `links` entry in the frontmatter**, and vice versa — the validator enforces both directions

## Namespace conventions

Common namespaces currently in the wiki:

- `cognitive.*` — user's cognitive profile, MBTI, preferences
- `lang.<language>.*` — language-specific knowledge (e.g. `lang.gleam.actors`)
- `tools.*` — tooling decisions and patterns
- `arch.*` — architecture decisions
- `strategy.*` — strategic thinking
- `concepts.*` — general concepts
- `beam.*` — BEAM/Erlang ecosystem
- `infra.*` — deployment and infrastructure

**Use an existing namespace when possible.** Create a new one only when nothing fits. Run `ls ~/.memory/wiki/` (or grep on frontmatter `id:` fields) before introducing a new namespace to see what exists.

## What NOT to include as entries

- Ephemeral task state ("I'm debugging X right now")
- Information derivable from code or git history
- Back-and-forth clarifications that don't reach a decision
- Information already captured in an existing entry — **update the existing one instead**
- Tool call details, transcripts, process notes
- Anything that would be uninteresting or stale a month from now

## The "kind" field is free-form

`kind` is entirely up to the entry's creator. The validator doesn't enforce any particular set of values — it just requires the field to exist and be a non-empty string. Pick whatever word best describes what the entry *is*.

Values you'll see in the current wiki (as a rough guide, not a closed set): `design-decision`, `technical`, `insight`, `concept`, `personal`, `setup`, `strategy`, `infrastructure`, `research`, `decision`. Use them when they fit. Invent new ones when they don't. There's no authority to appeal to — the creator decides.

The convention is lowercase, hyphen-separated, single line. Beyond that, it's your call.
