# Wiki entry format

Every wiki entry is markdown with YAML frontmatter, stored at `~/.memory/wiki/<id>.md`.

The design principle is **type the structure, free the content**: the validator enforces the shape (required fields, link integrity, tag form). Everything *inside* the structure — what to title the entry, what `kind` to call it, which namespace it lives in, what tags mean, what sections the body has — is the creator's call.

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

## Required structure (the validator enforces these)

The `memory validate` CLI rejects entries that violate any of these. They are non-negotiable:

1. **Required top-level fields** — `id`, `title`, `kind`, `tags`, `links`, `meta`
2. **ID must contain at least one dot** — dot-notation is required (e.g. `cognitive.intp.profile`)
3. **ID matches filename** — `cognitive.intp.profile` must live in `cognitive.intp.profile.md`
4. **Tags must parse as a block-style YAML list** — one per line, indented with `- `. Flow-style `[a, b, c]` is rejected by the parser.
5. **Tags must be non-empty strings without spaces** — that's the only content constraint on tags
6. **Link integrity — bidirectional** — every `[[ref]]` in the body must have a matching entry in the frontmatter `links` list, AND every `links[].target` must have a matching `[[ref]]` somewhere in the body
7. **Link targets resolve** — every `links[].target` must be the `id` of an existing entry in the wiki
8. **Labels required** — every link must have a non-empty `label`
9. **Required meta fields** — `meta.created`, `meta.updated`, `meta.sources` (list)
10. **Timestamps quoted** — ISO 8601 strings wrapped in quotes

Everything not in this list is free. The validator does not care about tag case, title wording, kind value, namespace choice, body structure, or any other content.

## Free-form fields (the creator decides)

These fields are required by the structure but what goes *in* them is entirely the creator's choice. There is no closed set, no authority, and no convention the skill imposes:

| Field | Constraint |
|-------|-----------|
| `title` | Any non-empty string. Quote it if it contains YAML special chars. |
| `kind` | Any non-empty string. |
| `tags` | Lowercase slug strings. What each tag *means* is not prescribed. |
| `links[].label` | Any non-empty string. |
| Body | Any markdown. Any sections. Any structure. The validator only looks at `[[ref]]` occurrences. |
| `meta.sources` | Any list of strings. |
| Namespace (the prefix part of the id) | Any dot-prefix. The validator requires at least one dot; it doesn't care what the prefix is or whether it matches anything that already exists. |

If you want to know what other entries look like before composing one, read them. The corpus is self-describing.

## Updating an existing entry

When you update an entry, these three provenance conventions are standard practice (not validator rules):

- **Keep the original `meta.created`** — it marks when the knowledge was first captured
- **Set `meta.updated`** to the current ISO timestamp
- **Append the current source id to `meta.sources`** — don't replace, accumulate provenance

And this is a validator rule:

- **When you add or remove a `[[ref]]` in the body, add or remove the matching `links` entry in the frontmatter** (and vice versa) — the validator enforces both directions.
