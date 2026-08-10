---
name: create
description: Create, update, or delete persistent Memory entries only when the user explicitly asks to remember, save, update, forget, or delete something. Search and read through the local `memory` 9P projection, then submit one head-bound typed mutation to Memory. Never write a host-local wiki or save proactively.
---

# Apply an explicit Memory mutation

Use this skill only for a direct user request to change persistent memory.
Automatic transcript maintenance belongs to the Memory service and is not a
reason to invoke this skill.

Use the private `memory` service projected into `$NAMESPACE`. Do not edit
`~/.memory`, invoke Git, run the validator directly, or discover service
endpoints and credentials. Memory owns validation, atomic application, Git
history, and publication.

## Prepare the mutation

1. Read `memory/status` and retain its exact `repository_head`.
1. Search `memory/wiki/search` and read related entries before creating a new
   ID. Prefer updating the existing entry that owns the subject.
1. For an update, preserve `meta.created`, update `meta.updated`, and append the
   current session identifier to `meta.sources` when one is available.
1. Before deleting an entry, search for the literal `[[ENTRY_ID]]`. Update or
   remove inbound links in the same atomic mutation, or ask the user when the
   intended repair is ambiguous.
1. Compose complete replacement contents for every upsert. Entry filenames and
   frontmatter IDs use the same dot-notation ID.

## Submit one atomic request

Write one valid JSON document to a private temporary file:

```json
{
  "schema_id": "memory-entry-mutation-request.v1",
  "expected_head": "EXACT_HEAD_FROM_STATUS",
  "upserts": [
    {
      "id": "namespace.entry-id",
      "content": "complete markdown entry"
    }
  ],
  "deletions": [
    {
      "id": "namespace.retired-entry"
    }
  ]
}
```

Omit neither array; use an empty array for the unused operation kind. Submit it
with `r9p rpc memory/ctl/entries < REQUEST_FILE`, then remove the temporary
file.

A successful `memory-entry-mutation-result.v1` reports `applied` or
`no_change`, the resulting head, and publication state. Report the affected
entry IDs to the user. If publication failed after a local commit, say so
without pretending the mutation was rejected.

## Resolve ambiguity safely

- On a stale-head rejection, read status and all affected entries again,
  deliberately rebase the intended semantic change, and submit a newly bound
  request.
- If delivery is unknown, do not replay blindly. Read status and the affected
  entries first to determine whether the mutation committed.
- If Memory rejects validation, fix the complete proposed entries and submit a
  new request. Never bypass the service gate.

Do not save facts merely because they appear useful. Explicit user intent is
required.
