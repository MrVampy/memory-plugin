---
name: recall
description: Consult the user's host-native Memory wiki for prior decisions, preferences, project history, and personal context. Always use this before acting on a topic that may have prior context. Use native grep, glob, and file reads against the local ~/.memory/wiki checkout, follow wiki links when relevant, and cite entry IDs in the response.
---

# Recall persistent context

Use the host-local read-only checkout at `${HOME}/.memory/wiki`. Memory keeps
that ordinary Git repository converged to the authoritative remote head. Do
not use a namespace projection, search another host, fetch or pull the
repository, or mutate the checkout.

## Discover relevant entries

1. Set the wiki root to `${HOME}/.memory/wiki` and require that it is a
   readable directory containing Markdown entries.
1. Search contents with `rg`, using bounded, distinctive literal or regular
   expression queries and `--glob '*.md'` as appropriate.
1. Browse IDs with ordinary shell globs or `rg --files "${HOME}/.memory/wiki"`
   when a filename prefix or namespace is more useful than content search.
1. Read matching `.md` files with ordinary file tools.
1. Follow relevant `[[linked.entry.id]]` references by reading
   `${HOME}/.memory/wiki/linked.entry.id.md`.

The local checkout is the current host's native Memory replica. Treat it as
read-only even when Unix permissions allow writes. Memory alone owns
replication and service-directed mutation.

## Use recalled knowledge

- Cite each relied-on entry ID so the user can identify the source.
- Surface conflicting entries instead of silently choosing one.
- If an entry appears stale, explain the discrepancy. Use the `create` skill
  only when the user explicitly asks for a persistent correction.
- If search produces no useful result, proceed honestly without claiming to
  remember the topic.

Never mutate Memory during recall.
