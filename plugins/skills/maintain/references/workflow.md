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

### Step 3b: Decide what to extract

Read the transcript and decide what (if anything) is worth turning into wiki entries. This is your judgment call — the skill does not prescribe what counts as knowledge worth keeping. The corpus is self-describing: if you need context for what the wiki currently covers, glob and read.

### Step 3c: For each knowledge item, find or create a wiki entry

1. **Search `~/.memory/wiki/`** with grep for related topics — avoid duplicates
2. **If an existing entry covers the topic:**
   - Read it
   - Edit to merge the new information
   - Update `meta.updated` to the current ISO timestamp
   - Append the transcript id to `meta.sources`
3. **If no existing entry fits:**
   - Compose a new entry in markdown (see `references/wiki-entry-format.md` for the required structure)
   - Choose an id and namespace — existing namespaces are listed in the entry format reference, but you can create new ones if nothing fits
   - Write to `~/.memory/wiki/<id>.md`
4. **Run `scripts/validate.sh`** — fix any errors reported and re-validate until clean

**Validation failures are your signal.** Common causes:
- Missing `[[ref]]` in body matching a frontmatter link (or vice versa)
- Broken link target (the entry you referenced doesn't exist — create it or remove the link)
- Tags in flow style `[a, b]` instead of block style
- ID doesn't match filename

### Step 3d: Always mark the transcript as done

**Always move the file out of `raw/sessions/`, regardless of whether you extracted anything.** The presence of a file in `processed/sessions/` is what marks the transcript as "seen" — not "had content worth saving." If you leave a staged transcript in `raw/sessions/` because "nothing to extract," the next run will re-filter and re-read it forever.

Two cases:

**Case A — you extracted knowledge and wrote/updated entries:**

```bash
mv ~/.memory/raw/sessions/<id> ~/.memory/processed/sessions/<id>
```

**Case B — you read the transcript and decided nothing was worth extracting:**

Same move. The file's content doesn't matter after this point — only its presence in `processed/sessions/` does. Move it anyway:

```bash
mv ~/.memory/raw/sessions/<id> ~/.memory/processed/sessions/<id>
```

**Case C — the filter in Phase 2 produced an empty file and `process-file.sh` deleted it:**

There's no file in `raw/sessions/` to move. Create a zero-byte marker directly:

```bash
touch ~/.memory/processed/sessions/<id>
```

In all three cases, after this step, `find-new-transcripts.sh` will skip this transcript on future runs.

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
