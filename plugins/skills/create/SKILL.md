---
name: create
description: Create, update, or delete persistent Memory entries only when the user explicitly asks to remember, save, update, forget, or delete something. Search and read the host-native ~/.memory/wiki checkout, bind the request to its exact Git head, then submit one typed mutation to the current host's admitted Memory control namespace. Never edit the checkout directly or save proactively.
---

# Apply an explicit Memory mutation

Use this skill only for a direct user request to change persistent memory.
Automatic transcript maintenance belongs to the Memory service and is not a
reason to invoke this skill.

Use `${HOME}/.memory/wiki` as the read-only discovery surface. Do not use a
namespace projection, edit the checkout, fetch or pull, run the validator
directly, or discover service endpoints and credentials.
Memory owns validation, atomic application, Git history, and publication.

## Prepare the mutation

1. Require `${HOME}/.memory/wiki` to be a readable Git checkout. Read its exact
   head with `git -C "${HOME}/.memory/wiki" rev-parse HEAD` and retain that
   value as `expected_head`. This head read is the only admitted Git operation;
   repeat it only when resolving a stale or delivery-unknown result.
1. Search `${HOME}/.memory/wiki` with native `rg` and read related `.md` files
   before creating a new ID. Prefer updating the existing entry that owns the
   subject.
1. For an update, preserve `meta.created`, update `meta.updated`, and append the
   current session identifier to `meta.sources` when one is available.
1. Before deleting an entry, use `rg --fixed-strings '[[ENTRY_ID]]'
   "${HOME}/.memory/wiki"`. Update or remove inbound links in the same atomic
   mutation, or ask the user when the intended repair is ambiguous.
1. Compose complete replacement contents for every upsert. Entry filenames and
   frontmatter IDs use the same dot-notation ID.

## Submit one atomic request

Write one valid JSON document to a private temporary file:

```json
{
  "schema_id": "memory-entry-mutation-request",
  "expected_head": "EXACT_HEAD_FROM_CHECKOUT",
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
as one same-fid RPC to `/memory/<host>/ctl/entries` through the current
agent's already admitted Coordinator namespace session, then remove the
temporary file. The surrounding host profile or Agent request must supply the
exact current-host Memory root and namespace session. Never guess a host ID,
endpoint, principal, auth domain, or credential path. If that admitted control
binding is absent, report that mutation control is unavailable and do not edit
the checkout.

A successful `memory-entry-mutation-result` reports `applied` or
`no_change`, the mutation digest, and the resulting head. Report the affected
entry IDs to the user. If the RPC fails after an ambiguous delivery, reconcile
the checkout before describing the mutation as rejected.

## Resolve ambiguity safely

- On a stale-head rejection, read the checkout head and all affected entries
  again, deliberately rebase the intended semantic change, and submit a newly
  bound request.
- If delivery is unknown, do not replay blindly. Read the checkout head and
  affected entries first to determine whether the mutation committed.
- If Memory rejects validation, fix the complete proposed entries and submit a
  new request. Never bypass the service gate.

Do not save facts merely because they appear useful. Explicit user intent is
required.
