---
name: maintain
description: Execute one service-submitted bounded Memory maintenance pass inside an exact-head writable wiki checkout. Use for a Memory service turn carrying a memory-maintenance-input envelope. Process every supplied transcript span oldest-first, run requested corpus maintenance, inspect and edit the wiki with native tools, repair validation failures, create one meaningful title-only semantic Git commit, and leave publication to the Memory service. Never schedule work, advance Memory cursors, or spawn another agent.
---

# Memory maintenance executor

Execute the complete maintenance method inside the current working directory.
Memory has already admitted and normalized the source data, assembled the
oldest-first work budget, and bound the run to one wiki head. Agent has been
started in Memory's same-host writable Git checkout at that exact head.

Read [references/workflow.md](references/workflow.md) completely and follow it
exactly. Read these references when the workflow routes you to them:

- [references/wiki-entry-format.md](references/wiki-entry-format.md) for entry
  structure and provenance conventions.
- [references/maintenance-passes.md](references/maintenance-passes.md) when a
  semantic corpus pass is requested.

Use the provider's native Glob, Grep, Read, Edit, and Write tools for wiki
navigation and changes. Use Bash only for bounded foreground Git and `memory
validate`. Do not replace native wiki navigation with shell
pipelines or ad hoc scripts.

Keep every tool and command in the foreground. Stay inside the supplied
checkout. Never mutate Memory state, call Memory mutation RPCs, advance a
cursor, schedule another task, spawn a subagent, acquire a credential, or
push; the Memory service performs the publication.

Do not return until the checkout is structurally valid and cleanly committed,
or until you have deeply considered the complete batch and proven that no wiki
change is warranted. Print only a concise human summary when finished. Memory
derives the result from Git and independently verifies the authoritative remote
head before completing the durable cursor.
