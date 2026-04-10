/// Inbox — agent-driven transcript archival.
///
/// Reads a session transcript from the host coding agent (Claude Code,
/// Codex, etc.), filters it down to user/assistant text content, and
/// writes the result to ~/.memory/raw/inbox/<basename>.jsonl where the
/// process skill picks it up later.
///
/// Format detection is automatic — the first line of the file determines
/// whether it's a Claude Code transcript or a Codex transcript. An
/// explicit format hint can override detection if needed.

import gleam/string
import simplifile

pub type Format {
  ClaudeCode
  Codex
  Unknown
}

/// Archive a transcript file into the inbox. Returns Ok(output_path)
/// on success, Error(reason) on failure.
pub fn archive(
  source_path: String,
  inbox_dir: String,
  format_override: Format,
) -> Result(String, String) {
  case simplifile.read(source_path) {
    Error(_) -> Error("cannot read " <> source_path)
    Ok(content) -> {
      let format = case format_override {
        Unknown -> detect(content)
        f -> f
      }
      let filtered = case format {
        ClaudeCode -> filter_claude_code(content)
        Codex -> filter_codex(content)
        Unknown -> ""
      }
      case filtered {
        "" -> Error("nothing to archive (empty after filtering or unknown format)")
        _ -> {
          let _ = simplifile.create_directory_all(inbox_dir)
          let out_path = inbox_dir <> "/" <> basename(source_path)
          case simplifile.write(out_path, filtered) {
            Error(_) -> Error("failed to write " <> out_path)
            Ok(_) -> Ok(out_path)
          }
        }
      }
    }
  }
}

/// Parse a format string from a CLI flag value.
pub fn parse_format(name: String) -> Result(Format, String) {
  case name {
    "claude-code" | "claude" -> Ok(ClaudeCode)
    "codex" -> Ok(Codex)
    "auto" -> Ok(Unknown)
    _ -> Error("unknown format: " <> name)
  }
}

fn detect(content: String) -> Format {
  case detect_format_js(content) {
    "claude-code" -> ClaudeCode
    "codex" -> Codex
    _ -> Unknown
  }
}

fn basename(path: String) -> String {
  case string.split(path, "/") {
    [] -> path
    parts ->
      case last(parts) {
        Ok(name) -> name
        Error(_) -> path
      }
  }
}

fn last(items: List(String)) -> Result(String, Nil) {
  case items {
    [] -> Error(Nil)
    [x] -> Ok(x)
    [_, ..rest] -> last(rest)
  }
}

@external(javascript, "../ffi/transcript.mjs", "filterClaudeCode")
fn filter_claude_code(content: String) -> String

@external(javascript, "../ffi/transcript.mjs", "filterCodex")
fn filter_codex(content: String) -> String

@external(javascript, "../ffi/transcript.mjs", "detectFormat")
fn detect_format_js(content: String) -> String
