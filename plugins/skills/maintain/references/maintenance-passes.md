# Semantic maintenance passes

These passes run on longer cycles (once per ~24 hours, tracked by `~/.memory/.maintenance-state/last-maintenance-pass`). They look for inconsistencies the per-entry validator can't catch because they require comparing multiple entries against each other.

Each pass is independent. Run as many as time permits; skip ones that don't apply.

**What the validator enforces vs. what these passes handle**

The validator enforces the per-entry structure — frontmatter shape, link bidirectionality within a single entry, required fields. These passes handle *semantic* issues across the corpus — contradictions, duplicates, stale info, tag variants. The validator has no opinion on any of this; these passes are judgment calls about knowledge quality.

When you run these passes, you are acting on your own judgment, not applying validator-style rules. When you're unsure, report and let the user decide.

## Pass 1: Contradiction detection

**Goal:** find pairs of entries that make opposing claims about the same topic.

**How:**

1. Glob entries by namespace (`~/.memory/wiki/<ns>.*.md`). Contradictions usually live within a namespace.
2. For each namespace, read all entries.
3. Look for patterns:
   - Two entries asserting different values for the same fact ("X uses Y" vs "X uses Z")
   - Two entries recommending opposing approaches without context distinguishing them
   - A decision entry that contradicts a concept it links to

**What to do:**

- **If the contradiction is a timeline** (one decision superseded the other): update the newer entry to note what it supersedes, or merge them with a "History" section in the newer one
- **If both are true in different contexts**: split into two entries with distinct ids, each naming the context it applies to, link them with clear labels
- **If one is simply wrong**: surface the conflict in the report with both entry ids and let the user decide

**Don't silently pick a winner.** If you can't unambiguously resolve, report and move on.

## Pass 2: Duplicate merging

**Goal:** find entries that cover the same ground under different ids.

**How:**

1. Glob all entries, collect `{id, title, tags}` for each
2. Look for:
   - Title similarity (e.g. "Gleam actor model" vs "Actors in Gleam")
   - Tag overlap + body overlap (both entries mention the same facts)
   - One entry that exists only to link to another (stub entries)

**What to do:**

- Pick the canonical id (usually the older one or the one with more inbound links)
- Read both entries carefully
- Merge content into the canonical entry:
  - Combine sections
  - Deduplicate facts
  - Preserve all links from both
  - Append the other entry's `meta.sources` to the survivor's
- Set `meta.updated` to now on the survivor
- Validate: `scripts/validate.sh`
- Delete the duplicate: `rm ~/.memory/wiki/<duplicate-id>.md`
- Validate again: `scripts/validate.sh`
- **If validation fails on delete** (broken inbound links from third entries), update the third entries to point at the canonical id instead, validate, retry delete

## Pass 3: Orphan detection

**Goal:** find entries with no inbound links (possibly dead knowledge).

**How:**

1. Glob all entries
2. For each entry, grep the wiki for `[[<id>]]` — inbound link count
3. Entries with zero inbound links are candidates

**What to do:**

- **Don't automatically delete orphans.** Being unlinked doesn't imply being useless — an entry might be a root-level concept, a recently created entry that hasn't been linked yet, or deliberately standalone.
- **Surface them in the report** for user review.
- If the entry's own frontmatter signals that it's throwaway (e.g. a `kind` value the creator used to mark scratch content), deleting is fine — but read the entry before deciding, don't pattern-match on a fixed list of kind values.

## Pass 4: Tag normalization

**Goal:** merge tag variants that mean the same thing.

**How:**

1. Glob all entries, extract tag lists, build frequency counts
2. Look for variant spellings:
   - Underscore vs hyphen (`memory-system` vs `memory_system`)
   - Singular vs plural (`decision` vs `decisions`)
   - Case variants (shouldn't exist since validator rejects non-lowercase)
   - Typos (`memroy` vs `memory`)

**What to do:**

- Pick the most common form as canonical (or the form that matches the wiki's existing conventions)
- For each entry using a variant:
  - Read the entry
  - Edit the tag
  - Validate
- **Be conservative.** `typescript` and `javascript` are different tags, not variants.

## Pass 5: Stale entry review

**Goal:** find entries that may no longer be accurate.

**How:**

- Heuristic: entries with `meta.updated` older than ~6 months where the topic is fast-moving
  - Fast-moving topics: tooling, architecture, technology decisions
  - Slow-moving topics: personal facts, general concepts, historical decisions
- Re-read the flagged entries

**What to do:**

- **If still accurate:** update `meta.updated` to mark you re-verified (no content change needed)
- **If outdated:** add a note section (`## Status as of <date>`) describing what's changed, or update the content
- **Be conservative about automated rewrites.** Marking as reviewed is fine. Substantive rewrites should be surfaced in the report for user review.

## Pass 6: Link health audit

**Goal:** find broken links that slipped through (shouldn't happen if validator is doing its job, but check anyway).

**How:**

1. `scripts/validate.sh` — the validator already catches broken links
2. If it reports errors, fix them:
   - Remove the stale `[[ref]]` from the body AND the matching `links` entry
   - Or update the target to the correct id
3. Re-validate until clean

This pass is usually a no-op (the validator runs after every write in Phase 3). Include it anyway as a safety check.

## Rules for all passes

- **Don't batch-delete.** Deletions accumulate errors — do them one at a time with validation between.
- **Always run `scripts/validate.sh` after any wiki mutation.**
- **Report what you did.** Each pass should state: "Found N candidates, fixed M, flagged K for review."
- **Stop on error loops.** If the same edit fails three times, skip it and move on.
- **Track progress.** Long-running passes should pause periodically and check that you're making forward progress.
