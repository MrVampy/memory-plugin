# Maintenance runbook

This is the full runbook for the scheduled maintenance subagent. Follow the phases in order.

## Phase 1: Discover new transcripts

```bash
scripts/find-new-transcripts.sh
```

Outputs one tab-separated record per line:

```
<agent>\t<id>\t<source>\t<cursor>
```

- `agent` — one of `claude-code`, `codex`, `opencode`
- `id` — filename-safe identifier ending in `.jsonl` (e.g. `claude-code-abc123.jsonl`)
- `source` — source file path (claude-code/codex) or session_id (opencode)
- `cursor` — how much of this session has already been consumed
  - `claude-code` / `codex`: line count of the source already processed
  - `opencode`: unix-ms `time_created` of the last message already processed
  - `0` for sessions that have never been seen before

The marker file at `~/.memory/processed/sessions/<id>` holds a single integer — the cursor — on its first line. The script emits a record only when there is genuinely new content past the cursor: for file-based agents, when the source's current line count exceeds the stored cursor; for opencode, always (the extractor filters by `--since` at query time).

This means **in-progress sessions get re-picked-up on every tick** as long as they keep growing. Each tick processes only the diff since the last cursor, not the whole transcript.

If the output is empty, **skip to Phase 4** (maintenance passes) — there's nothing new to process.

## Phase 2: Stage each transcript

For each record from Phase 1, pass the cursor as the 4th argument:

```bash
scripts/process-file.sh <agent> <id> <source> <cursor>
```

This:
1. Routes to the right filter (`filter-claude-code.py`, `filter-codex.py`, `extract-opencode.py`), telling it to skip everything up to the cursor
2. Writes filtered JSONL of the **diff only** to `~/.memory/raw/sessions/<id>` — only if the diff contained user/assistant text
3. Writes the NEW cursor value (post-diff) to `~/.memory/raw/sessions/<id>.cursor` — **always**, even when the content diff was empty
4. Prints the staged content-file path on stdout (empty if no content to stage)

**Two possible outcomes:**

- **Content diff non-empty** — proceed to Phase 3 to extract knowledge, then commit the cursor sidecar.
- **Content diff empty** (filter consumed lines past the previous cursor but none of them were user/assistant text) — no Phase 3 extraction needed, but you still MUST commit the cursor sidecar. If you don't, those same lines get read again on the next tick. See Phase 3 Step 3d Case C.

**Do not touch `~/.memory/processed/sessions/<id>` yourself in this phase.** The commit happens in Phase 3d after extraction, or directly in Phase 3d Case C for empty-diff sessions. This keeps the advance atomic with extraction and preserves crash-safety: if extraction fails, the cursor doesn't advance, and the diff is re-read next tick.

## Phase 2b: Discover inbox notes (alternate intake)

In addition to session transcripts, the wiki accepts hand-dropped markdown
notes placed in `~/.memory/raw/inbox/`. These are already user-authored
markdown — no filter or staging step is needed. List them:

```bash
ls ~/.memory/raw/inbox/ 2>/dev/null
```

Each file in that directory is treated just like a staged transcript in
Phase 3 below: read it, extract what's worth keeping into wiki entries,
then move the file to `~/.memory/processed/inbox/<same-filename>` when
done. The `processed/inbox/` directory marks a note as "seen" — the same
contract as `processed/sessions/`.

If the directory is empty or missing, skip this phase.

## Phase 3: Extract knowledge from staged transcripts and inbox notes

For each file in `~/.memory/raw/sessions/` **and** `~/.memory/raw/inbox/`:

### Step 3a: Read the transcript

```
Read(~/.memory/raw/sessions/<id>)
```

Each line is JSON: `{"role": "user"|"assistant", "content": [text, ...]}`. The transcript is a cleaned conversation — no tool calls, no system reminders, just human/assistant text.

### Step 3b: Decide what to extract

Read the transcript and decide what (if anything) is worth turning into wiki entries. This is your judgment call — the skill does not prescribe what counts as knowledge worth keeping. The corpus is self-describing: if you need context for what the wiki currently covers, glob and read.

### Step 3c: For each knowledge item, find or create a wiki entry

1. **Search `~/.memory/wiki/`** with grep for related topics — avoid duplicates
2. **Before creating anything new, check whether this transcript id already appears in any `meta.sources`.** If it does, this session has been partially processed before and you're now seeing a diff — treat the new content as an **extension** of existing entries. Update those entries in place; do not create parallel duplicates just because the source looks new.
3. **If an existing entry covers the topic:**
   - Read it
   - Edit to merge the new information
   - Update `meta.updated` to the current ISO timestamp
   - Append the transcript id to `meta.sources` (skip if already present)
4. **If no existing entry fits:**
   - Compose a new entry in markdown (see `references/wiki-entry-format.md` for the required structure)
   - Choose an id and namespace — existing namespaces are listed in the entry format reference, but you can create new ones if nothing fits
   - Write to `~/.memory/wiki/<id>.md`
5. **Run `scripts/validate.sh`** — fix any errors reported and re-validate until clean

**Validation failures are your signal.** Common causes:
- Missing `[[ref]]` in body matching a frontmatter link (or vice versa)
- Broken link target (the entry you referenced doesn't exist — create it or remove the link)
- Tags in flow style `[a, b]` instead of block style
- ID doesn't match filename

### Step 3d: Commit the cursor and clean up

**Always commit the cursor sidecar to `processed/sessions/<id>` and remove the raw files**, regardless of whether you extracted anything. The content of the marker file (an integer — the cursor) is what Phase 1 compares against on the next tick. If you leave a staged file in `raw/sessions/` or skip writing the marker, the next run will either re-read the same lines or never advance.

Three cases for session transcripts:

**Case A — you extracted knowledge and wrote/updated entries:**

```bash
cp ~/.memory/raw/sessions/<id>.cursor ~/.memory/processed/sessions/<id>
rm ~/.memory/raw/sessions/<id>
rm ~/.memory/raw/sessions/<id>.cursor
```

**Case B — you read the diff and decided nothing was worth extracting:**

Same commit. The diff's content doesn't matter after this point — only the advanced cursor does:

```bash
cp ~/.memory/raw/sessions/<id>.cursor ~/.memory/processed/sessions/<id>
rm ~/.memory/raw/sessions/<id>
rm ~/.memory/raw/sessions/<id>.cursor
```

**Case C — the filter in Phase 2 produced an empty diff** (no user/assistant content past the cursor) and there is no `raw/sessions/<id>` file, only the sidecar:

```bash
cp ~/.memory/raw/sessions/<id>.cursor ~/.memory/processed/sessions/<id>
rm ~/.memory/raw/sessions/<id>.cursor
```

Case C still advances the cursor — that's the whole point. Without it, those cursor-advanced-but-content-empty lines would be re-read forever on every tick.

**Inbox notes (from Phase 2b)** use the old mv-based contract because inbox notes are single-shot markdown files, not growing transcripts — there's no cursor to track:

```bash
mkdir -p ~/.memory/processed/inbox
mv ~/.memory/raw/inbox/<filename> ~/.memory/processed/inbox/<filename>
```

In all cases, after this step, the next run will skip already-processed content for this item.

## Phase 4: Maintenance passes (on longer cycles)

Check the marker at `~/.memory/.maintenance-state/last-maintenance-pass`. If missing or older than ~6 hours, run the passes documented in `references/maintenance-passes.md`.

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

## Phase 6: Commit wiki to local git

After the report, commit any wiki changes to the local git repo at `~/.memory/wiki/.git`. This gives you per-maintenance-run history of the wiki and a rollback path if a pass ever makes a bad edit.

```bash
scripts/git-commit.sh "<short summary — typically derived from the Phase 5 report>"
```

The script is self-initializing: the first time it runs, it creates `~/.memory/wiki/.git` and does an initial snapshot commit of the current wiki state. On subsequent runs, it stages all changes and commits only if there's something to commit (no-op safe).

**Commit message convention:**

- Keep the first line under 72 characters
- Lead with the date and what meaningfully changed
- Mention created/updated/deleted counts when non-zero
- Examples:
  - `2026-04-14: +1 created, 2 updated, 0 deleted`
  - `2026-04-14: maintenance passes — resolved 2 orphans, no content changes`
  - `2026-04-14: inbox recovery — 15 sessions rescanned, 3 entries updated`

If nothing changed in the wiki during this run, the script exits cleanly with "no changes to commit" — still call it. It's idempotent and the no-op case is expected on most hourly ticks.

## Phase 7: Push wiki to remote (if configured)

After the local commit, push to the wiki's configured remote. This gives the user off-machine backup and cross-machine sync of their memory.

```bash
scripts/git-push.sh
```

The script is remote-aware: if no `origin` remote is configured, it no-ops silently. If a remote exists but the push fails (network outage, auth expired, non-fast-forward), it logs a warning and exits 0 — the commit stays local and will be picked up on the next successful run. Treat push failures as non-fatal; the local repo is the source of truth.

Call this every run, even when commit said "no changes to commit" — it's idempotent and fast when there's nothing to push.

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
