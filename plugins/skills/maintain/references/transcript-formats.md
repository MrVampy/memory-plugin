# Transcript formats per agent

The filter scripts in `scripts/` handle the common cases. This document is for debugging when a filter misses something or produces unexpected output.

## Claude Code

**Location:** `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl`

Subagent transcripts live at `<session-id>/subagents/agent-*.jsonl` — `find-new-transcripts.sh` deliberately skips these because subagent outputs are already summarized in the parent session's transcript.

**Format:** one JSON object per line. Each line has a top-level `type` field:

| `type` | Meaning | Keep? |
|--------|---------|-------|
| `user` | User message | yes |
| `assistant` | Assistant message | yes |
| `file-history-snapshot` | Filesystem snapshot | no |
| `system` | System messages | no |

User/assistant messages have a `message` object with:

- `role` — `"user"` or `"assistant"`
- `content` — either a string (rare) or a list of content blocks

Content blocks:

- `{"type": "text", "text": "..."}` — **keep text**
- `{"type": "tool_use", ...}` — skip
- `{"type": "tool_result", ...}` — skip
- `{"type": "thinking", ...}` — skip

**Noise prefixes to strip from text blocks:**

- `<system-reminder>` — Claude Code injected reminders
- `<command-` — command name tags
- `<local-command` — local command tags
- `<task-notification>` — subagent task notifications

The filter script is `filter-claude-code.py`.

## Codex

**Location:** `~/.codex/sessions/<year>/<month>/<day>/rollout-<timestamp>-<uuid>.jsonl`

**Format:** one JSON object per line. Each line: `{timestamp, type, payload}`.

| `type` | `payload.type` | Keep? |
|--------|----------------|-------|
| `session_meta` | — | no |
| `response_item` | `message` | yes (mostly) |
| `response_item` | `reasoning` | no |
| `event_msg` | — | no |
| `turn_context` | — | no |

Message payload has:

- `role` — `"user"`, `"assistant"`, or `"developer"`
- `content` — list of blocks

The `developer` role contains Codex's internal instructions (permissions, environment context, system setup). **Skip `developer` messages entirely.**

Content block types for user/assistant messages:

- `{"type": "input_text", "text": "..."}` — **keep (user)**
- `{"type": "output_text", "text": "..."}` — **keep (assistant)**
- Other types — skip

**Noise prefixes to strip:**

- `<environment_context>` — environment metadata Codex injects
- `<permissions instructions>` — sandbox permission docs
- `<system-reminder>` — cross-agent convention
- `<command-` — command tags

The filter script is `filter-codex.py`.

## OpenCode

**Location:** `~/.local/share/opencode/opencode.db` (SQLite database)

**Schema** (relevant tables):

```sql
CREATE TABLE message (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data TEXT NOT NULL  -- JSON blob
);

CREATE TABLE part (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data TEXT NOT NULL  -- JSON blob
);

CREATE TABLE session (
  id TEXT PRIMARY KEY,
  ...
);
```

**Message `data` JSON:**

```json
{
  "role": "user" | "assistant",
  "time": {...},
  "agent": "...",
  "model": "...",
  "...": "..."
}
```

**Part `data` JSON:**

```json
{
  "type": "text" | "reasoning" | "tool" | "step-start" | ...,
  "text": "...",
  "...": "..."
}
```

**Query pattern:**

1. Get all messages for a session: `SELECT id, data FROM message WHERE session_id = ? ORDER BY time_created`
2. Parse each `data` JSON; skip if `role` not in `{"user", "assistant"}`
3. Get parts for that message: `SELECT data FROM part WHERE message_id = ? ORDER BY time_created`
4. Parse each part `data`; keep only `type == "text"`; collect `text` field

**Noise to strip:**

- `<environment_context>` — environment metadata
- Empty text parts
- Non-text part types (`step-start`, `reasoning`, `tool`, etc.)

The filter/extract script is `extract-opencode.py`. It takes a session id (not a file path) because the data lives in a database, not a flat file.

## Discovery details

`find-new-transcripts.sh` walks:

- `~/.claude/projects/**/*.jsonl` (excluding `**/subagents/*`)
- `~/.codex/sessions/**/*.jsonl`
- `SELECT DISTINCT session_id FROM message` in `opencode.db`

"Already processed" is determined by the presence of a file named `<id>` in `~/.memory/processed/sessions/`. The check is a simple existence test, not content comparison — if you want to reprocess a transcript, delete the corresponding file in `processed/sessions/`.

## When a filter misses an edge case

If a transcript has text that the filter skips incorrectly:

1. Run the filter on a single transcript with `python3 scripts/filter-<agent>.py <path> | head`
2. Compare to the raw JSONL to see what structure was expected vs what was actually there
3. Update the filter script to handle the new case
4. Re-run the maintain skill — unprocessed transcripts will be reprocessed

Common causes:

- **Unknown block types** — filter script only whitelists known types, new ones get skipped
- **Role variations** — an agent might add a new role (e.g. `tool`) the filter doesn't know about
- **Nested content** — content might be an object rather than a string or list in edge cases
- **Encoding issues** — bad UTF-8 or control characters in the text
