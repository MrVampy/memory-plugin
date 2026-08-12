# Memory project guide

This repository owns three reusable namespace-native skills and the structural
wiki validator. The private Memory service consumes these artifacts; it owns
live wiki state, automatic maintenance scheduling, mutation validation, Git
history, and publication.

Read [README.md](./README.md) before changing the architecture.

## Boundaries

- Keep `plugins/skills/recall` and `plugins/skills/create` provider-neutral.
  They use only the stable local `memory` 9P projection through r9p.
- Do not put endpoints, certificates, principals, host names, wiki contents,
  transcripts, or credentials in a skill.
- Do not restore the retired local `~/.memory/wiki` workflow, agent-side
  scheduler, installer, hooks, transcript scanners, cursor files, direct wiki
  writes, or provider-specific copies.
- `plugins/skills/maintain` owns the semantic maintenance method used by a
  dedicated Memory reasoning profile. It processes the service-supplied
  bounded oldest-first session pass, reads the admitted read-only Memory
  projection, and returns one typed proposal; it never schedules itself or
  owns state.
- Memory service owns automatic transcript maintenance. `create` is only for
  direct user requests to mutate persistent knowledge.
- The Gleam validator enforces structure only. Never add content policy such
  as approved topics, tag vocabulary, namespace choices, or kind values.
- Skills are source artifacts exported by `flake.nix`; profile repositories
  consume exact pinned paths instead of copying them.

## Validator rules

The validator requires identity and filename agreement, required frontmatter,
block-style tags, quoted timestamps, complete metadata, and bidirectional link
integrity. Every target must exist. It intentionally leaves semantic content
to the agent and user.

## Change discipline

- Keep one current contract and delete retired machinery in the same cutover.
- Do not inspect or commit the user's live wiki.
- Validate skill metadata with the Codex skill validator after edits.
- Run compiling and Nix checks through the infrastructure's declared M7 build
  lane when this repository is consumed by `vault-apps` or `nix-flake`.
- Commit exact pathspecs and publish source before dependency propagation.
