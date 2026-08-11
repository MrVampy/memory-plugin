---
name: maintain
description: Execute one service-submitted Memory transcript extraction, semantic maintenance, or structural-repair task. Use only in the dedicated Memory reasoning profile when the prompt supplies a memory-maintenance-input.v2 or memory-maintenance-repair-input.v2 envelope. Search the complete admitted wiki, preserve the established maintenance judgment, and return one bounded memory-maintenance-plan.v1 proposal. Never schedule work, advance cursors, write the wiki, commit Git, or spawn another agent.
---

# Memory maintenance executor

You are the maintenance executor. Memory has already admitted and normalized
the source data, chosen the oldest queued task, and bound this run to one wiki
head. Read [references/workflow.md](references/workflow.md) completely and
follow it exactly.

Read these references when the workflow routes you to them:

- [references/wiki-entry-format.md](references/wiki-entry-format.md) for entry
  structure and provenance conventions.
- [references/maintenance-passes.md](references/maintenance-passes.md) for a
  semantic-maintenance task.

The complete current wiki is available read-only at
`$NAMESPACE/fs/memory`. Use `rg`, `rg --files`, and ordinary file reads there.
The corpus is the authority for its own namespaces and content conventions.

Return only the typed proposal requested by the workflow. Do not write through
the filesystem, call Memory mutation RPCs, run Git, advance a source cursor,
schedule another task, or spawn a subagent. Memory alone validates and commits
the proposal atomically.
