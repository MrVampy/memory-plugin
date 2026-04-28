## Persistent memory wiki

The user has a typed wiki at `~/.memory/wiki/` containing prior decisions, preferences, user profile, and project context — things NOT in your weights. Before responding to any task that could touch these topics (user identity, preferences, prior decisions, project history, technical context), use your native filesystem tools to consult it:

- **Grep** `~/.memory/wiki/` for keywords from the current task
- **Glob** `~/.memory/wiki/<prefix>.*.md` to browse a namespace
- **Read** a specific entry at `~/.memory/wiki/<id>.md`

Entries are markdown with YAML frontmatter. Links between entries use `[[other.entry.id]]` and the frontmatter `links` array — follow them when relevant.

For explicit memory writes (user says *"remember that X"*, *"save this"*, *"update the entry about Y"*), see the `memory-create` skill. Reads are free — the cost of skipping is acting on incomplete context.
