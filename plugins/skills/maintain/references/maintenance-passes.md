# Semantic maintenance passes

These are the established longer-cycle semantic passes. The validator enforces
entry structure; these passes exercise corpus-level judgment. Run the passes in
the order below. Run as many as context permits, and prefer one or two complete
namespaces over a shallow whole-wiki pass.

## Pass 1: Contradiction detection

Group entries by namespace, read related entries, and look for opposing claims
about the same topic.

- If the difference is an unambiguous timeline, represent what superseded what
  or merge the history into the current entry.
- If both claims are true in different contexts, distinguish those contexts
  explicitly and link the entries.
- If one appears wrong but the corpus does not prove which, make no destructive
  change. Never silently pick a winner.

## Pass 2: Duplicate merging

Compare IDs, titles, tags, bodies, sources, and inbound links for entries that
cover the same idea.

- Choose the canonical ID using age, completeness, and inbound links.
- Merge sections without duplicating facts.
- Preserve and union every `meta.sources` value and relevant relationship.
- Update every inbound linker before deleting the duplicate.
- Delete only after reading both entries and all inbound linkers in full.

## Pass 3: Orphan detection

Find entries with no inbound `[[id]]` reference. Do not automatically delete an
orphan merely because it is unlinked. It may be a root concept, a recent entry,
or deliberately standalone. Delete only when the entry itself and the corpus
make its disposable status unambiguous.

## Pass 4: Tag normalization

Build a corpus-wide tag frequency map and look conservatively for spelling,
hyphen/underscore, singular/plural, or case variants that mean the same thing.
Choose the established common form. Do not merge distinct concepts just because
their names are similar.

## Pass 5: Stale review

Re-read old entries about fast-moving tooling, architecture, and technical
decisions. Personal facts, concepts, and historical decisions age differently.

- If the corpus proves an entry is still accurate, its review timestamp may be
  refreshed.
- If the corpus proves it is superseded, update it with the current status or a
  clear history.
- If correctness requires outside knowledge or user judgment, leave the claim
  unchanged.

## Pass 6: Link health

Check that references are useful as well as structurally valid. Remove stale or
weightless links from both body and frontmatter, or correct them when the corpus
proves the intended target. Memory's validator performs the final mechanical
integrity check.

## Pass 7: Holistic re-read and clean

Read the complete selected corpus before proposing any edit. Then clean it as
one body of knowledge:

- Keep one idea per entry and one entry per idea.
- Organize by theme, not by the chronology of sessions or meetings.
- Treat very thin stubs and bloated multi-topic entries as signals to merge,
  split, or enrich when the corpus supports it.
- Use flat, factual, encyclopedic prose. Remove peacock words, editorial voice,
  progressive narrative, stale framing, empty sections, and AI hedges.
- Preserve direct quotes exactly and normally keep no more than two per entry.
- Keep only links that materially help a reader.
- Promote recurring patterns, tensions, and philosophies into first-class
  concept entries when the corpus supports the synthesis.
- Restructure diary-shaped entries, split real subtopics, merge genuine stubs,
  add missing useful links, remove vestigial scaffolding, and enrich anemic
  entries from facts already elsewhere in the wiki.
- Update `meta.updated` for every touched entry.

Do the work when it is supported; do not merely produce a flag list. Leave an
already coherent entry alone. The goal is a cleaner wiki, not a different one.

## Guardrails for every pass

- Never invent a fact.
- Never alter a direct quote.
- Never remove a provenance source.
- Never silently resolve a contradiction by picking a winner.
- Never delete without reading the entry and its inbound links in full.
- Keep each semantic commit coherent and bounded enough for Memory to validate
  and publish atomically.
- If a structural change cannot be made safely, prefer no mutation to damage.
