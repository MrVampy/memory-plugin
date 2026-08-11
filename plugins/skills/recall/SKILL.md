---
name: recall
description: Consult the user's namespace-native Memory service for prior decisions, preferences, project history, and personal context. Always use this before acting on a topic that may have prior context. Use native grep, glob, and file reads through the admitted read-only Memory filesystem, follow wiki links when relevant, and cite entry IDs in the response.
---

# Recall persistent context

Use the private `memory` service and read-only filesystem projected into
`$NAMESPACE`. Do not read a host-local `~/.memory` directory and do not look
for service endpoints, certificates, or host addresses.

## Discover relevant entries

1. Read `memory/status` with r9p and confirm that the service is ready.
1. Set the wiki root to `$NAMESPACE/fs/memory` and require that it is a
   readable directory.
1. Search contents with `rg`, using bounded, distinctive literal or regular
   expression queries and `--glob '*.md'` as appropriate.
1. Browse IDs with ordinary shell globs or `rg --files "$NAMESPACE/fs/memory"`
   when a filename prefix or namespace is more useful than content search.
1. Read matching `.md` files with ordinary file tools.
1. Follow relevant `[[linked.entry.id]]` references by reading
   `$NAMESPACE/fs/memory/linked.entry.id.md`.

The mounted tree is an admitted, coherent, read-only projection of the Memory
service. It is not a copied wiki and must never be mutated directly.

## Use recalled knowledge

- Cite each relied-on entry ID so the user can identify the source.
- Surface conflicting entries instead of silently choosing one.
- If an entry appears stale, explain the discrepancy. Use the `create` skill
  only when the user explicitly asks for a persistent correction.
- If search produces no useful result, proceed honestly without claiming to
  remember the topic.

Never mutate Memory during recall.
