# Semantic maintenance passes

These passes run on longer cycles (once per ~6 hours, tracked by `~/.memory/.maintenance-state/last-maintenance-pass`). They look for inconsistencies the per-entry validator can't catch because they require comparing multiple entries against each other.

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

## Pass 7: Holistic re-read and clean

**Goal:** read the wiki end-to-end as one body of knowledge and *make it cleaner*. This pass is where the wiki goes from a sediment of moments to something that reads coherently. You are not flagging — you are doing the work.

### What "clean" means

A clean wiki reads as one coherent body of knowledge, written by one mind, even though it grew incrementally. Concretely:

- **One idea per entry, one entry per idea.** No entry trying to be two things; no idea smeared across three entries. Atomicity test: if you can't remove anything without breaking the idea, and nothing's missing, it's atomic.
- **Theme-driven, not chronology-driven.** Sections are organized by what they mean, not when they happened. The Steve Jobs Wikipedia test: "Early life / Career / NeXT" — not "The March meeting / The April pivot." Diary-shaped entries are the most common rot.
- **Right-sized.** Stubs under ~15 lines and bloat over ~120 lines are both smells in the same namespace.
- **Encyclopedic tone.** Flat, factual, neutral. No peacock words ("legendary," "deeply," "truly"), no editorial voice ("interestingly," "it should be noted"), no progressive narrative ("would go on to"). Facts imply significance.
- **Quote discipline.** Where direct quotes appear, they carry the emotional weight and the prose stays neutral. Cap at ~2 per entry.
- **Links carry weight.** Every `[[ref]]` is there because following it actually helps a reader, not because the words happened to match.
- **No vestigial scaffolding.** Headings, framings, or hedges that made sense when written but no longer fit how the wiki has grown.
- **Concept entries are first-class.** Patterns, themes, tensions, philosophies — synthesis entries that connect across many sources. These are where the wiki becomes a map of a mind.

### How to run the pass

1. **Glob all entries** in `~/.memory/wiki/`. Group by namespace, then sort by id, so related entries land near each other in your context.

2. **Read the entire wiki in that order.** Hold the whole picture in mind as you go. Don't edit during the read — editing mid-read fragments your attention and biases the rest of the read. You're forming a map first.

3. **After the full read, work through the entries again and clean.** For each entry, ask the audit questions:
   - Does it tell a coherent point, or is it a chronological dump?
   - Are sections organized by theme, not date?
   - Is it the right size for its namespace, or does it need splitting / merging / enriching?
   - Does the tone match the rest of the wiki, or is it drifting (peacock words, editorial voice, AI hedges)?
   - Does it connect to related entries that exist? Are there `[[refs]]` it should have but doesn't? Refs it has but shouldn't?
   - Would a reader learn something non-obvious, or is it a stub pretending to be an entry?

4. **Act on what you find. Don't flag, don't surface, don't ask.** Within the guardrails below, fix it:
   - **Restructure diary-shaped entries** into theme-driven ones. Rewrite section headings, regroup paragraphs, integrate so the entry reads as a whole.
   - **Normalize tone.** Strip peacock words, editorial voice, progressive-narrative phrasing. Tighten to flat encyclopedic prose. Preserve direct quotes — they're the one place voice belongs.
   - **Split bloated entries.** If a sub-topic has accumulated three or more paragraphs inside another entry, lift it into its own entry with its own id, link from the original, validate.
   - **Merge thin stubs into the canonical entry** when they cover the same ground (this overlaps with Pass 2 — fine, do it here too if you spot it).
   - **Add missing links** where an entry mentions a topic that has its own entry but doesn't `[[link]]` to it. Update the frontmatter `links` block to match.
   - **Remove vestigial scaffolding** — empty sections, stale "Status as of <date>" notes that have been superseded, framing paragraphs that no longer fit.
   - **Enrich anemic entries** when the rest of the wiki contains material that should be in them. Pull the connections in, integrate, don't just append.
   - **Update `meta.updated`** on every entry you touch.
   - **Validate after every entry** with `scripts/validate.sh`. If validation fails, fix and re-validate before moving on.

### Guardrails — what NOT to do

These exist so the pass doesn't quietly damage the wiki:

- **Never delete an entry without reading it in full first**, including checking inbound links. If deletion would break links, update the linkers first.
- **Never invent facts.** When restructuring or rewriting, every claim in the new version must trace back to something already in the wiki. You are reorganizing existing knowledge, not generating new knowledge.
- **Never overwrite the user's voice in direct quotes.** Quotes are sacred — copy them verbatim into the restructured entry.
- **Never silently resolve a contradiction by picking a winner.** That's Pass 1's job, and Pass 1's rule is to report, not pick. If you spot a contradiction during the holistic read, leave it for Pass 1 / the report.
- **Never delete `meta.sources` entries.** When merging, append the absorbed entry's sources to the survivor's; don't drop them.
- **Don't restructure for restructuring's sake.** If an entry already reads coherently, leave it alone. The goal is making the wiki cleaner, not different.
- **Don't fight with validation.** If the same edit fails validation three times, revert that entry to its pre-edit state and move on. Better to skip one entry than corrupt it.

### Reporting

After the pass, include in the final summary: how many entries were read, how many were edited, how many were split or merged, how many were left untouched. No flag list — the actions are the report.

### Cost note

This pass reads the entire wiki, so it's the most context-expensive one. If the wiki has grown large and context is tight on a given run, it's fine to do a partial pass — pick one or two namespaces, clean those thoroughly, and let the next maintenance cycle pick up the rest. A partial-but-thorough pass beats a complete-but-shallow one.

## Rules for all passes

- **Don't batch-delete.** Deletions accumulate errors — do them one at a time with validation between.
- **Always run `scripts/validate.sh` after any wiki mutation.**
- **Report what you did.** Each pass should state: "Found N candidates, fixed M, flagged K for review."
- **Stop on error loops.** If the same edit fails three times, skip it and move on.
- **Track progress.** Long-running passes should pause periodically and check that you're making forward progress.
