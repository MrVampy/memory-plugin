/// Hook handlers — agent-aware envelopes for the remaining hook surface.
///
/// After the lean refactor, almost all integration moved to agent-driven
/// CLI calls. The only hook still alive is permission auto-allow on
/// Claude Code (so background subagents can `mv` files between raw/ and
/// processed/ during /memory:process without prompting), and the
/// equivalent permission.ask callback on OpenCode that shells out to
/// this same handler.
///
/// Recall and validation are no longer hook-driven — agents call
/// `memory recall` and `memory create` directly via the create skill.

import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string

pub type Agent {
  ClaudeCode
  Codex
  OpenCode
}

/// Parse an agent name from a CLI flag value.
pub fn parse_agent(name: String) -> Result(Agent, String) {
  case name {
    "claude-code" | "claude" -> Ok(ClaudeCode)
    "codex" -> Ok(Codex)
    "opencode" -> Ok(OpenCode)
    _ -> Error("unknown agent: " <> name)
  }
}

// --- permission hook ---

/// Run the permission-request hook. Auto-allows Bash mv operations
/// between raw/ and processed/ — this lets background subagents touch
/// the memory system during /memory:process without triggering
/// interactive prompts.
///
/// Note: with the agent-driven CLI workflow, wiki writes go through
/// `memory create` (a Bash invocation), not the Write tool. We no
/// longer need to auto-allow Write/Edit on wiki paths — that path
/// doesn't exist anymore. The remaining auto-allow is just for the
/// raw → processed file move during processing.
///
/// Returns "" for "no decision" (the agent falls through to normal
/// permission handling).
pub fn run_permission(
  stdin_input: String,
  agent: Agent,
  raw_path: String,
  processed_path: String,
) -> String {
  case parse_permission_input(stdin_input) {
    Error(_) -> ""
    Ok(#(tool_name, _file_path, command)) -> {
      let should_allow = case tool_name {
        "Bash" ->
          string.contains(command, raw_path)
          && string.contains(command, processed_path)
        _ -> False
      }
      case should_allow {
        True -> format_permission_envelope(agent)
        False -> ""
      }
    }
  }
}

fn parse_permission_input(
  input: String,
) -> Result(#(String, String, String), String) {
  let inner_decoder = {
    use file_path <- decode.optional_field("file_path", "", decode.string)
    use command <- decode.optional_field("command", "", decode.string)
    decode.success(#(file_path, command))
  }
  let decoder = {
    use tool_name <- decode.field("tool_name", decode.string)
    use tool_input <- decode.field("tool_input", inner_decoder)
    let #(file_path, command) = tool_input
    decode.success(#(tool_name, file_path, command))
  }
  json.parse(from: input, using: decoder)
  |> result.map_error(fn(_) { "failed to parse permission input" })
}

fn format_permission_envelope(agent: Agent) -> String {
  case agent {
    ClaudeCode ->
      "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}"
    Codex ->
      // Codex has no PermissionRequest hook. Emit nothing.
      ""
    OpenCode ->
      // OpenCode's TS plugin shells out to this CLI and checks for the
      // string "allow" to decide whether to allow the operation.
      "{\"decision\":\"allow\"}"
  }
}
