/// Hook handlers — agent-aware envelopes around the core operations.
///
/// Each coding agent (Claude Code, Codex, OpenCode) sends a slightly
/// different JSON envelope to its hook scripts on stdin and expects a
/// slightly different envelope back. This module owns those differences
/// so the underlying logic (recall, validate, capture) stays agent-agnostic.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import memory/entry
import memory/recall
import memory/store
import memory/validate
import simplifile

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

// --- recall hook ---

/// Run the recall hook end-to-end. Reads stdin (already captured by the
/// caller as `stdin_input`), produces the agent-specific JSON envelope
/// to print on stdout. Empty string means "emit nothing".
pub fn run_recall(stdin_input: String, agent: Agent, wiki_path: String) -> String {
  case extract_prompt(stdin_input) {
    Error(_) -> ""
    Ok("") -> ""
    Ok(prompt) -> {
      let keywords = recall.extract_keywords(prompt)
      case keywords {
        [] -> ""
        _ ->
          case store.read_wiki(wiki_path) {
            Error(_) -> ""
            Ok(results) -> {
              let #(entries, _) = store.partition_results(results)
              let matches = recall.top_matches(entries, keywords, 5)
              case matches {
                [] -> ""
                _ -> {
                  let body = recall.format_output(matches)
                  format_recall_envelope(body, agent)
                }
              }
            }
          }
      }
    }
  }
}

fn format_recall_envelope(body: String, agent: Agent) -> String {
  case agent {
    // Codex deliberately mirrors Claude Code's hook protocol — same
    // input fields, same UserPromptSubmitHookSpecificOutput envelope.
    // Verified against codex/codex-rs/hooks/schema/generated/.
    ClaudeCode | Codex ->
      json.object([
        #(
          "hookSpecificOutput",
          json.object([
            #("hookEventName", json.string("UserPromptSubmit")),
            #("additionalContext", json.string(body)),
          ]),
        ),
      ])
      |> json.to_string

    OpenCode ->
      // OpenCode plugins are TypeScript, not stdout-based hooks. The TS
      // plugin shells out to `memory hook recall` and inserts the body
      // into the system prompt directly, so emit plain text here.
      body
  }
}

// --- validate (stop) hook ---

/// Run the stop-hook validator. Reads no useful input — the protocol just
/// requires us to consume stdin. Validates the wiki and returns the agent's
/// blocking-response envelope, with a two-pass grace period: the first
/// occurrence of any errors is saved to a state file but does not block,
/// giving any in-flight subagent a chance to fix them. If the same errors
/// persist on the next call, we block.
///
/// Returns the empty string when there's nothing to emit.
pub fn run_validate(
  _stdin_input: String,
  agent: Agent,
  wiki_path: String,
  state_file: String,
) -> String {
  case collect_errors(wiki_path) {
    "" -> {
      // Wiki is clean — clear any stale grace-period state and emit nothing.
      let _ = simplifile.delete(state_file)
      ""
    }
    errors_text -> {
      let prev =
        simplifile.read(state_file)
        |> result.unwrap("")

      case errors_text == prev {
        True -> {
          // Same errors twice in a row — block.
          let _ = simplifile.delete(state_file)
          format_validate_envelope(errors_text, agent)
        }
        False -> {
          // First occurrence — save and let it through.
          let _ = simplifile.write(state_file, errors_text)
          ""
        }
      }
    }
  }
}

fn collect_errors(wiki_path: String) -> String {
  case store.read_wiki(wiki_path) {
    Error(_) -> ""
    Ok(results) -> {
      let #(entries, parse_errors) = store.partition_results(results)
      let validation_errors = validate.validate_all(entries)
      let all_errors = list.flatten([parse_errors, validation_errors])
      case all_errors {
        [] -> ""
        errs ->
          "Wiki validation errors:\n"
          <> {
            errs
            |> list.map(fn(e) { "  ✗ " <> entry.format_error(e) })
            |> string.join("\n")
          }
          <> "\n("
          <> int.to_string(list.length(errs))
          <> " error(s))"
      }
    }
  }
}

fn format_validate_envelope(errors_text: String, agent: Agent) -> String {
  case agent {
    // Codex's stop schema accepts both `continue + stopReason` and
    // `decision + reason`. The Claude Code shape works on both.
    ClaudeCode | Codex ->
      json.object([
        #("continue", json.bool(False)),
        #("stopReason", json.string(errors_text)),
      ])
      |> json.to_string

    OpenCode ->
      // No stop-hook equivalent on OpenCode. Emit plain text — the TS
      // plugin (if any) decides whether to surface it.
      errors_text
  }
}

// --- permission hook ---

/// Run the permission-request hook. Auto-allows Write/Edit on the wiki
/// directory and Bash mv operations between raw/ and processed/ — this
/// is what lets background subagents touch the memory system without
/// triggering interactive prompts.
///
/// Returns "" for "no decision" (the agent falls through to normal
/// permission handling).
pub fn run_permission(
  stdin_input: String,
  agent: Agent,
  wiki_path: String,
  raw_path: String,
  processed_path: String,
) -> String {
  case parse_permission_input(stdin_input) {
    Error(_) -> ""
    Ok(#(tool_name, file_path, command)) -> {
      let should_allow = case tool_name {
        "Write" | "Edit" -> string.starts_with(file_path, wiki_path)
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
      // Codex has no PermissionRequest hook. The CLI shouldn't be wired
      // to call this branch on Codex; emit nothing if it somehow is.
      ""
    OpenCode ->
      // OpenCode's TS plugin shells out to this CLI and checks for the
      // string "allow" to decide whether to allow the operation.
      "{\"decision\":\"allow\"}"
  }
}

// --- input parsing ---

/// All three agents send a JSON object containing a `prompt` field on
/// stdin for the user-message hook. Extract it.
fn extract_prompt(input: String) -> Result(String, String) {
  let decoder = {
    use prompt <- decode.field("prompt", decode.string)
    decode.success(prompt)
  }
  json.parse(from: input, using: decoder)
  |> result.map_error(fn(_) { "failed to parse hook input" })
}
