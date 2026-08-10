/// Memory CLI — the wiki validator.
///
/// The CLI has exactly one responsibility: validate a wiki directory.
/// The Memory service supplies an explicit staged wiki path and owns every
/// mutation. Recall and explicit user-directed writes use its 9P namespace;
/// no coding agent edits a host-local wiki tree.
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
    _ -> usage()
  }
}

fn usage() -> Nil {
  io.println("Usage:")
  io.println("  memory validate path    Validate one complete staged wiki tree")
}

fn run_validate(path: String) -> Nil {
  case store.read_wiki(path) {
    Error(msg) -> {
      io.println("ERROR: " <> msg)
      exit(1)
    }
    Ok(results) -> {
      let #(entries, parse_errors) = store.partition_results(results)
      let validation_errors = validate.validate_all(entries)
      let all_errors = list.flatten([parse_errors, validation_errors])

      case all_errors {
        [] -> {
          io.println(
            "OK: "
            <> int.to_string(list.length(entries))
            <> " entries, 0 errors",
          )
        }
        errors -> {
          list.each(errors, fn(e) {
            io.println("ERROR: " <> entry.format_error(e))
          })
          io.println(int.to_string(list.length(errors)) <> " error(s)")
          exit(1)
        }
      }
    }
  }
}

@external(javascript, "./ffi/env.mjs", "exit")
fn exit(code: Int) -> Nil
