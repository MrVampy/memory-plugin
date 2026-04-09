/// Memory CLI — the wiki compiler.
///
/// Commands:
///   validate [path]   Validate all wiki entries at path
///   index [path]      Regenerate INDEX.md at path

import argv
import gleam/int
import gleam/io
import gleam/list
import memory/entry
import memory/index
import memory/store
import memory/validate

pub fn main() {
  case argv.load().arguments {
    ["validate", path] -> run_validate(path)
    ["validate"] -> run_validate(default_wiki_path())
    ["index", path] -> run_index(path)
    ["index"] -> run_index(default_wiki_path())
    _ -> {
      io.println("Usage:")
      io.println("  memory validate [path]   Validate wiki entries")
      io.println("  memory index [path]      Regenerate INDEX.md")
    }
  }
}

fn run_validate(path: String) -> Nil {
  case store.read_wiki(path) {
    Error(msg) -> {
      io.println("✗ " <> msg)
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
          list.each(errors, fn(e) {
            io.println("✗ " <> entry.format_error(e))
          })
          io.println(int.to_string(list.length(errors)) <> " error(s)")
        }
      }
    }
  }
}

fn run_index(path: String) -> Nil {
  case store.read_wiki(path) {
    Error(msg) -> {
      io.println("✗ " <> msg)
    }
    Ok(results) -> {
      let #(entries, _) = store.partition_results(results)
      case index.write(entries, path) {
        Ok(_) -> {
          io.println(
            "✓ INDEX.md generated ("
            <> int.to_string(list.length(entries))
            <> " entries)",
          )
        }
        Error(msg) -> io.println("✗ " <> msg)
      }
    }
  }
}

fn default_wiki_path() -> String {
  case get_env("HOME") {
    Ok(home) -> home <> "/.claude/.memory/wiki"
    Error(_) -> ".memory/wiki"
  }
}

@external(javascript, "./ffi/env.mjs", "getEnv")
fn get_env(name: String) -> Result(String, Nil)
