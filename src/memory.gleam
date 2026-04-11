/// Memory CLI — the wiki validator.
///
/// The CLI has exactly one responsibility: validate a wiki directory.
/// Every other operation (create, update, delete, recall, capture,
/// processing) is done by coding agents using their native filesystem
/// tools (Read, Edit, Write, Bash `rm`, Grep, Glob) with the validator
/// as the single gate. This is the "one tool, everything else native"
/// design — see `plugins/skills/` for the skills that drive it.

import argv
import gleam/int
import gleam/io
import gleam/list
import memory/entry
import memory/store
import memory/validate

pub fn main() {
  case argv.load().arguments {
    ["validate", path] -> run_validate(path)
    ["validate"] -> run_validate(default_wiki_path())
    _ -> usage()
  }
}

fn usage() -> Nil {
  io.println("Usage:")
  io.println("  memory validate [path]    Validate wiki entries (default: $MEMORY_HOME/wiki or ~/.memory/wiki)")
}

fn run_validate(path: String) -> Nil {
  case store.read_wiki(path) {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(results) -> {
      let #(entries, parse_errors) = store.partition_results(results)
      let validation_errors = validate.validate_all(entries)
      let all_errors = list.flatten([parse_errors, validation_errors])

      case all_errors {
        [] -> {
          io.println(
            "✓ " <> int.to_string(list.length(entries)) <> " entries, 0 errors",
          )
        }
        errors -> {
          list.each(errors, fn(e) { io.println("✗ " <> entry.format_error(e)) })
          io.println(int.to_string(list.length(errors)) <> " error(s)")
          exit(1)
        }
      }
    }
  }
}

/// Default wiki path. MEMORY_HOME overrides; otherwise ~/.memory/wiki.
fn default_wiki_path() -> String {
  case get_env("MEMORY_HOME") {
    Ok(root) -> root <> "/wiki"
    Error(_) ->
      case get_env("HOME") {
        Ok(home) -> home <> "/.memory/wiki"
        Error(_) -> ".memory/wiki"
      }
  }
}

@external(javascript, "./ffi/env.mjs", "getEnv")
fn get_env(name: String) -> Result(String, Nil)

@external(javascript, "./ffi/env.mjs", "exit")
fn exit(code: Int) -> Nil
