# Maintenance runbook

This is the full runbook for the scheduled maintenance subagent. Follow the phases in order.

## Phase 1: Discover new transcripts

```bash
scripts/find-new-transcripts.sh
```

Outputs one tab-separated record per line:

```
<agent>\t<id>\t<source>
```

- `agent` — one of `claude-code`, `codex`, `opencode`
- `id` — filename-safe identifier ending in `.jsonl` (e.g. `claude-code-abc123.jsonl`)
- `source` — source file path (claude-code/codex) or session_id (opencode)

"Already processed" is determined by the presence of a file with the matching `id` in `~/.memory/processed/sessions/`. The script is idempotent — running it twice with no new transcripts produces zero output.

If the output is empty, **skip to Phase 4** (maintenance passes) — there's nothing new to process.

## Phase 2: Stage each transcript

For each record from Phase 1:

```bash
scripts/process-file.sh <agent> <id> <source>
```

This:
1. Routes to the right filter (`filter-claude-code.py`, `filter-codex.py`, `extract-opencode.py`)
2. Writes filtered JSONL to `~/.memory/raw/sessions/<id>`
3. Prints the staged file path on stdout

If the filter produces no user/assistant content (the script exits 0 with no output), **still create a zero-byte marker** in `~/.memory/processed/sessions/<id>` so the transcript is treated as "done" on the next run:

```bash
touch ~/.memory/processed/sessions/<id>
```

Otherwise it will show up as "new" forever.

## Phase 3: Extract knowledge from staged transcripts

For each file in `~/.memory/raw/sessions/`:

### Step 3a: Read the transcript

```
Read(~/.memory/raw/sessions/<id>)
```

Each line is JSON: `{"role": "user"|"assistant", "content": [text, ...]}`. The transcript is a cleaned conversation — no tool calls, no system reminders, just human/assistant text.

### Step 3b: Scan for knowledge worth extracting

Look for:

- **Insights or decisions** the user reached or approved ("we decided to use X")
- **Technical findings** that would be useful in future sessions (how things work, architecture understanding)
- **User preferences and feedback** (corrections, approvals, stated preferences)
- **Project context** — *why* something was done a certain way, what was tried and rejected
- **Personal facts** the user shared about themselves (profile, preferences, situation)

Skip:

- Back-and-forth debugging details (process, not knowledge)
- Ephemeral task progress ("I'm now running X, Y, Z")
- Redundant information already captured in an existing wiki entry
- Short exchanges with no substantive content
- Questions the user answered but didn't decide anything durable about

### Step 3c: For each knowledge item, find or create a wiki entry

1. **Search `~/.memory/wiki/`** with grep for related topics — avoid duplicates
2. **If an existing entry covers the topic:**
   - Read it
   - Edit to merge the new information (add a new section, update existing text, or append to an existing section)
   - Update `meta.updated` to the current ISO timestamp
   - Append the transcript id to `meta.sources`
3. **If no existing entry fits:**
   - Compose a new entry in markdown
   - Pick a namespace from existing conventions (see `references/wiki-entry-format.md`)
   - Write to `~/.memory/wiki/<id>.md`
4. **Run `scripts/validate.sh`** — fix any errors reported and re-validate until clean

**Validation failures are your signal.** Common causes:
- Missing `[[ref]]` in body matching a frontmatter link (or vice versa)
- Broken link target (the entry you referenced doesn't exist — create it or remove the link)
- Tags in flow style `[a, b]` instead of block style
- ID doesn't match filename

### Step 3d: Move the processed transcript

After all knowledge is extracted and validated:

```bash
mv ~/.memory/raw/sessions/<id> ~/.memory/processed/sessions/<id>
```

The presence of the file in `processed/` is what tells the next run "this is done."

## Phase 4: Maintenance passes (on longer cycles)

Check the marker at `~/.memory/.maintenance-state/last-maintenance-pass`. If missing or older than ~24 hours, run the passes documented in `references/maintenance-passes.md`.

After running the passes, update the marker:

```bash
mkdir -p ~/.memory/.maintenance-state
date -u +%Y-%m-%dT%H:%M:%SZ > ~/.memory/.maintenance-state/last-maintenance-pass
```

Not every invocation of the maintain skill needs to run maintenance passes — only when the marker says they're due.

## Phase 5: Report

Print a concise final summary:

```
Memory maintenance complete.
- Transcripts processed: N
- Entries created: N
- Entries updated: N
- Entries deleted: N (only during maintenance passes)
- Maintenance passes run: [names or "none"]
- Wiki state: X entries, Y errors
```

If any step failed irrecoverably, include it with context.

## Failure handling

- **Validator errors you can't fix** after 3 attempts: skip the entry, move to the next, report in the summary
- **Transcript file corrupt or format unrecognized:** skip, still move to processed/ so you don't retry forever
- **Cross-transcript conflicts** that need user judgment: flag in report, let the next maintenance pass resolve or surface to user
- **Out of context (huge backlog):** prioritize most recent transcripts, leave older ones for the next run
- **Script invocation failed:** check `references/transcript-formats.md` — the filter may need updating for an edge case in the agent's format

## Rules

- **Never write to `~/.memory/wiki/`** without immediately running `scripts/validate.sh` after.
- **One entry at a time through validation.** Don't batch many writes and validate once at the end — fix errors as they appear.
- **Idempotent.** If there's nothing to do, do nothing and exit cleanly.
- **Work silently.** Only the final summary should be printed.
- **No subagents.** You are the subagent; don't spawn further ones.
