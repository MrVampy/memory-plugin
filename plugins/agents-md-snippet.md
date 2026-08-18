<!-- memory-plugin:begin -->
## Persistent Memory service

The user's prior decisions, preferences, project history, and personal context
live in the host-native `${HOME}/.memory/wiki` checkout maintained by Memory.
Before acting on a topic that may have prior context, use the `recall` skill to
search and read that local replica with native filesystem tools.

Use the `create` skill only when the user explicitly asks to remember, update,
forget, or delete persistent knowledge. Treat the local checkout as read-only;
submit explicit changes through the current host's admitted Memory control
namespace. Memory owns validation, atomic Git mutation, automatic transcript
maintenance, and publication.
<!-- memory-plugin:end -->
