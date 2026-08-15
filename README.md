# memory-plugin

`memory-plugin` owns the structural validator and reusable coding-agent skills
for the namespace-native Memory system.

The live wiki is owned by a configured Memory service instance. Recall and
explicit mutation use its authenticated local `memory` projection. For one
automatic maintenance turn, Memory gives the selected host-native Agent its
exact-head writable Git checkout and a non-secret publication binding. The
Agent obtains one bounded credential through the already admitted local
namespace; no endpoint, certificate, or credential is embedded in a skill.

## Components

- `memory validate` checks the structure and link integrity of a complete wiki
  tree. The Memory service invokes it before committing any mutation.
- `plugins/skills/recall` uses native grep, glob, and file reads through the
  admitted Memory filesystem.
- `plugins/skills/create` submits an explicit, head-bound, atomic mutation when
  the user directly asks to change persistent memory.
- `plugins/skills/maintain` preserves the established transcript-extraction and
  semantic-cleanup method for the host-native Agent application selected by
  Memory. It reads one bounded oldest-first multi-session pass plus any due
  longer-cycle maintenance, searches the complete local wiki, repairs its own
  validation failures, creates one semantic commit, and publishes it with an
  exact head lease.
- `plugins/agents-md-snippet.md` is the small provider-neutral instruction
  block profiles may incorporate.

Automatic transcript ingestion, ordering, scheduling, independent result
verification, and cursor completion are service responsibilities. The one
maintenance Agent turn owns semantic edits, validation and repair, its commit,
and exact-lease publication. There is no agent-side scheduler, local wiki
installer, or provider-specific hook.

## Namespace contract used by the skills

The runtime exposes one stable local service name:

```text
$NAMESPACE/memory
$NAMESPACE/fs/memory
```

Useful operations are:

```text
r9p read memory/status
rg --glob '*.md' QUERY "$NAMESPACE/fs/memory"
rg --files "$NAMESPACE/fs/memory"
r9p rpc memory/ctl/entries
```

The runtime supervisor retains all remote addressing and authentication
material. The filesystem is read-only and cache-coherent through Memory's
blocking namespace change feed. Skills use only these local surfaces.

The maintenance skill additionally works in Memory's supplied writable Git
checkout. Its prompt carries the expected head and non-secret repository and
credential binding. It requests one short-lived GitHub App authorization with
`r9p rpc credentials/use/github-app` through the existing local namespace and
passes the resulting token only to the exact Git push child environment.

## Nix outputs

The flake exports:

- `packages.<system>.memory-validator`
- `checks.<system>.memory-validator`
- `lib.skills.recall`
- `lib.skills.create`
- `lib.skills.maintain`

Host profiles pin this flake and place the exported skill trees in the
harness-native `.codex/skills` or `.claude/skills` directory. The skills have
one source and remain ordinary provider-native profile content.

## Validator contract

Every entry is one flat `<id>.md` file. The validator enforces:

1. Required top-level fields: `id`, `title`, `kind`, `tags`, `links`, and
   `meta`.
1. A 3-240 character dot-notation ID that starts with a lowercase ASCII
   letter, uses only lowercase ASCII letters, digits, `.`, `-`, and `_`, has
   no empty namespace segment, and matches the filename.
1. Block-style, non-empty tags without spaces.
1. Bidirectional agreement between body `[[entry.id]]` references and
   frontmatter links.
1. Existing link targets with non-empty labels.
1. `meta.created`, `meta.updated`, and a `meta.sources` list.
1. Quoted ISO 8601 timestamps.

The validator deliberately does not prescribe topics, namespaces, kinds,
titles, or what is worth remembering. It types structure, not content.

## Development

The validator is a Gleam project packaged by Nix. Service implementation,
runtime projection, credentials, transcripts, and wiki contents live outside
this public repository.

Do not put credential material or a live wiki in this repository. Consumers
must pin exact Git and Nix revisions rather than copy the skills.

## License

MIT. See [LICENSE](./LICENSE).
