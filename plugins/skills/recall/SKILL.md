---
name: recall
description: Consult the user's namespace-native Memory service for prior decisions, preferences, project history, and personal context. Always use this before acting on a topic that may have prior context. Search and read through the local `memory` 9P projection with r9p, follow wiki links when relevant, and cite entry IDs in the response.
---

# Recall persistent context

Use the private `memory` service projected into `$NAMESPACE`. Do not read a
host-local `~/.memory` directory and do not look for service endpoints,
certificates, or host addresses.

## Discover relevant entries

1. Read `memory/status` and confirm that the service is ready.
1. Search with a bounded same-fid RPC to `memory/wiki/search`:

   ```json
   {
     "schema_id": "memory-wiki-search-request.v1",
     "query": "distinctive literal text",
     "limit": 20
   }
   ```

   Write valid JSON to a private temporary file, run
   `r9p rpc memory/wiki/search < REQUEST_FILE`, and remove the temporary file.
   Use several distinctive queries when one term is ambiguous.
1. Browse `r9p read memory/wiki/index` when an ID prefix or namespace is more
   useful than content search.
1. Read a match with `r9p read memory/wiki/entries/ENTRY_ID`.
1. Follow relevant `[[linked.entry.id]]` references by reading those entry IDs.

Search results contain global namespace paths for discovery. Inside the private
projection, address entries with the stable local form
`memory/wiki/entries/ENTRY_ID`.

## Use recalled knowledge

- Cite each relied-on entry ID so the user can identify the source.
- Surface conflicting entries instead of silently choosing one.
- If an entry appears stale, explain the discrepancy. Use the `create` skill
  only when the user explicitly asks for a persistent correction.
- If search produces no useful result, proceed honestly without claiming to
  remember the topic.

Never mutate Memory during recall.
