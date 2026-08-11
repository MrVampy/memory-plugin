# Wiki entry format

Every wiki entry is one flat `<id>.md` file with YAML frontmatter followed by
Markdown. The design principle is "type the structure, free the content".

## Complete shape

```markdown
---
id: namespace.entry-name
title: "Human readable title"
kind: design-decision
tags:
  - tag1
  - tag2
links:
  - target: other.entry.id
    label: why this relationship matters
meta:
  created: "2026-04-09T10:00:00Z"
  updated: "2026-04-11T12:00:00Z"
  sources:
    - source-session-key
---

# Section heading

Body text with an [[other.entry.id]] reference matching the frontmatter link.
```

## Validator-enforced structure

1. Required top-level fields are `id`, `title`, `kind`, `tags`, `links`, and
   `meta`.
2. The ID is 3-240 characters, starts with a lowercase ASCII letter, contains
   at least one dot, has no empty segment, and otherwise uses only lowercase
   ASCII letters, digits, dots, hyphens, and underscores.
3. The ID exactly matches the filename without `.md`.
4. Tags are a block-style YAML list of non-empty strings without spaces.
5. Every body `[[reference]]` has one matching frontmatter link target, and
   every frontmatter link target appears in the body.
6. Every link target exists and every label is non-empty.
7. `meta.created`, `meta.updated`, and the `meta.sources` list are present.
8. Timestamps are quoted ISO 8601 strings.

Everything else is free. The validator does not prescribe topics, namespaces,
kinds, titles, tag meanings, section layout, or what deserves to be remembered.
Read the corpus when consistency matters.

## Updating an existing entry

These provenance rules preserve the established workflow:

- Keep the original `meta.created` value.
- Set `meta.updated` to the current ISO timestamp.
- Append the current source key to `meta.sources` without removing or
  duplicating earlier values.
- Keep body references and frontmatter links bidirectionally synchronized.
