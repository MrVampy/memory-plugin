---
name: recall
description: THIS IS YOUR PERSISTENT MEMORY. You have no long-term memory across sessions — anything the user has told you, decided with you, or asked you to remember lives at ~/.memory/wiki/ as markdown files with YAML frontmatter. ALWAYS search this directory at the start of any task touching a topic the user might have prior context on (facts about themselves, technical decisions, project history, preferences). Use your content-search tool (grep / ripgrep) against ~/.memory/wiki/, your filename-pattern tool (glob) for namespace browsing like ~/.memory/wiki/namespace.*.md, and your file-read tool for full entries. The cost of checking unnecessarily is small; the cost of acting on incomplete context is large.
argument-hint: "[search terms]"
---

# Recall is agent-driven via your native tools

There are no MCP tools or hooks for recall. You use your existing native filesystem
tools — whatever your platform calls them — directly against `~/.memory/wiki/`.
You decide when to query based on the task. Reads are unrestricted by design.

The exact tool names vary by platform. Most coding agents have something equivalent
to:

- A **content-search tool** (grep / ripgrep) — searches file contents by regex,
  optionally scoped to a directory
- A **filename-pattern tool** (glob) — lists files matching a pattern like `*.md`
- A **file-read tool** — reads a file's contents by path

Use whichever ones your platform exposes. If unsure of the exact names, list your
available tools and look for ones with these capabilities.

# How to find entries

Pick the right operation for the question:

**By keyword in content** (the most common case):

Search the wiki directory with your grep/ripgrep tool, e.g. searching for the
keyword `MBTI` in `~/.memory/wiki/`. Returns matching file paths. Use distinctive
terms — searching for `MBTI` is better than searching for `type`. Add follow-up
searches for refinement.

**By tag**:

Tags live in the YAML frontmatter as block-style list items (`- tagname` lines).
Search for `- tagname` in `~/.memory/wiki/` to find entries by tag.

**By namespace** (browse a topic area):

The wiki uses dot-notation ids, so namespace prefixes work like directories.
Use your glob tool with patterns like:

- `~/.memory/wiki/lang.gleam.*.md`
- `~/.memory/wiki/cognitive.*.md`
- `~/.memory/wiki/tools.memory-*.md`

**By id** (when you already know it from a search hit or a link):

Read the file directly at `~/.memory/wiki/<id>.md` — for example
`~/.memory/wiki/cognitive.intp.profile.md`.

**Listing everything**:

Glob `~/.memory/wiki/*.md`.

# How to follow links

Wiki entries reference each other with `[[other.entry.id]]` in the body and as
`{target, label}` pairs in the frontmatter `links` list. After reading one entry,
read the entries linked from it. The frontmatter `links` array shows you why each
link exists (the `label` field) so you can decide whether to follow without
opening the target.

# Discovery workflow at the start of a task

1. **Search by keyword** — grep/ripgrep `~/.memory/wiki/` for the primary topic word
2. **If hits look promising** — read the most relevant entries in full
3. **Follow links** — read entries linked from the matches
4. **If no hits** — try a different keyword, or glob a likely namespace prefix
5. **If still nothing** — it's safe to proceed without prior context, but you tried

# What to do with what you find

- **Cite the entry id** when referencing recalled knowledge so the user knows the source
- **If a recalled entry seems wrong or outdated**, update it via `memory_create` (the
  create skill explains the format) — don't just work around stale information
- **If two entries cover the same topic with conflicting info**, surface the conflict
  to the user

# What NOT to do

- **Don't skip the check because the question seems simple.** Simple questions often
  have prior context you don't have in your weights ("what's my MBTI" is a one-word
  answer that lives in `cognitive.intp.profile`).
- **Don't pretend you "remember" something** — recall it explicitly so the user can
  verify the source.
- **Don't write to the wiki via Write/Edit** — that bypasses validation. Use
  `memory_create` (the MCP tool) for any wiki writes.
