/// Memory CLI — the wiki compiler.
///
/// Commands:
///   validate [path]              Validate all wiki entries at path
///   recall <query> [--json]      Find entries matching query keywords
///   create [--file path]         Validate and write a new entry (markdown on stdin)
///   list [namespace]             List all entries, optionally filtered by namespace
///   hook recall [--agent X]      Run the recall hook (reads JSON from stdin)

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import memory/entry.{
  type ValidationError, BrokenLink, DuplicateId, EmptyLabel, Entry, InvalidId,
  InvalidTag, InvalidTimestamp, LinkMismatch, MissingField, ParseError,
}
import memory/frontmatter
import memory/hook
import memory/inbox
import memory/recall
import memory/store
import memory/validate
import simplifile

pub fn main() {
  case argv.load().arguments {
    ["validate", path] -> run_validate(path)
    ["validate"] -> run_validate(default_wiki_path())

    ["recall", ..rest] -> run_recall(rest)

    ["create", ..rest] -> run_create(rest)

    ["delete", id] -> run_delete(id, False)
    ["delete", id, "--force"] -> run_delete(id, True)
    ["delete", "--force", id] -> run_delete(id, True)

    ["list"] -> run_list(default_wiki_path(), None)
    ["list", namespace] -> run_list(default_wiki_path(), Some(namespace))

    ["hook", "recall", ..rest] -> run_hook_recall(rest)
    ["hook", "validate", ..rest] -> run_hook_validate(rest)
    ["hook", "permission", ..rest] -> run_hook_permission(rest)

    ["inbox", ..rest] -> run_inbox(rest)

    _ -> usage()
  }
}

fn usage() -> Nil {
  io.println("Usage:")
  io.println("  memory validate [path]              Validate wiki entries")
  io.println("  memory recall <query> [--json]      Find matching entries")
  io.println("  memory create [--file path]         Create or update an entry (markdown on stdin)")
  io.println("  memory delete <id> [--force]        Delete an entry, refusing if it would break links")
  io.println("  memory list [namespace]             List entries")
  io.println("  memory inbox <file> [--format X]    Archive a session transcript to ~/.memory/raw/inbox/")
  io.println("  memory hook recall [--agent X]      Recall hook (reads JSON from stdin)")
  io.println("  memory hook validate [--agent X]    Validation hook (reserved for future agents)")
  io.println("  memory hook permission [--agent X]  Permission hook (auto-allows wiki writes)")
}

// --- validate ---

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

// --- recall ---

fn run_recall(args: List(String)) -> Nil {
  let json_mode = list.contains(args, "--json")
  let query =
    args
    |> list.filter(fn(a) { a != "--json" })
    |> string.join(" ")

  case string.trim(query) {
    "" -> Nil
    _ -> do_recall(query, json_mode)
  }
}

fn do_recall(query: String, json_mode: Bool) -> Nil {
  let keywords = recall.extract_keywords(query)
  case keywords {
    [] -> Nil
    _ -> {
      case store.read_wiki(default_wiki_path()) {
        Error(_) -> Nil
        Ok(results) -> {
          let #(entries, _) = store.partition_results(results)
          let matches = recall.top_matches(entries, keywords, 5)
          case matches {
            [] -> Nil
            _ -> {
              let output = recall.format_output(matches)
              case json_mode {
                True -> io.println(recall.format_json(output))
                False -> io.println(output)
              }
            }
          }
        }
      }
    }
  }
}

// --- hook recall ---

/// Read JSON from stdin, dispatch to the recall hook handler for the
/// given agent (default: claude-code), print the agent's expected
/// envelope on stdout (or nothing if no matches).
fn run_hook_recall(args: List(String)) -> Nil {
  let agent = parse_agent_flag(args)
  case agent {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(a) -> {
      case read_stdin() {
        Error(_) -> Nil
        Ok(input) -> {
          let output = hook.run_recall(input, a, default_wiki_path())
          case output {
            "" -> Nil
            _ -> io.println(output)
          }
        }
      }
    }
  }
}

/// Run the stop / validate hook for the given agent. Reads stdin (the
/// hook protocol requires it), runs the validator with two-pass grace,
/// and emits the agent's blocking-response envelope on persistent errors.
fn run_hook_validate(args: List(String)) -> Nil {
  let agent = parse_agent_flag(args)
  case agent {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(a) -> {
      // Consume stdin per hook protocol; we don't actually need it.
      let _ = read_stdin()
      let output =
        hook.run_validate(
          "",
          a,
          default_wiki_path(),
          default_state_file_path(),
        )
      case output {
        "" -> Nil
        _ -> io.println(output)
      }
    }
  }
}

fn default_state_file_path() -> String {
  memory_home_subpath("/.last_validation_errors")
}

fn default_raw_path() -> String {
  memory_home_subpath("/raw")
}

fn default_processed_path() -> String {
  memory_home_subpath("/processed")
}

fn memory_home_subpath(suffix: String) -> String {
  case get_env("MEMORY_HOME") {
    Ok(root) -> root <> suffix
    Error(_) ->
      case get_env("HOME") {
        Ok(home) -> home <> "/.memory" <> suffix
        Error(_) -> ".memory" <> suffix
      }
  }
}

/// Run the permission hook for the given agent.
fn run_hook_permission(args: List(String)) -> Nil {
  case parse_agent_flag(args) {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(a) -> {
      case read_stdin() {
        Error(_) -> Nil
        Ok(input) -> {
          let output =
            hook.run_permission(
              input,
              a,
              default_wiki_path(),
              default_raw_path(),
              default_processed_path(),
            )
          case output {
            "" -> Nil
            _ -> io.println(output)
          }
        }
      }
    }
  }
}

/// Archive a transcript file into ~/.memory/raw/inbox/. Format is
/// auto-detected unless overridden with --format claude-code|codex.
fn run_inbox(args: List(String)) -> Nil {
  let #(format, file_arg) = parse_inbox_args(args)
  case format, file_arg {
    Error(msg), _ -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(_), None -> {
      io.println("Usage: memory inbox <file> [--format claude-code|codex|auto]")
      exit(1)
    }
    Ok(fmt), Some(path) -> {
      case inbox.archive(path, default_inbox_path(), fmt) {
        Ok(out) -> io.println("✓ archived → " <> out)
        Error(reason) -> {
          io.println("✗ " <> reason)
          exit(1)
        }
      }
    }
  }
}

/// Parse `[--format X] <file>` in either order. Returns the parsed
/// format and an optional file path.
fn parse_inbox_args(
  args: List(String),
) -> #(Result(inbox.Format, String), Option(String)) {
  do_parse_inbox(args, Ok(inbox.Unknown), None)
}

fn do_parse_inbox(
  args: List(String),
  format: Result(inbox.Format, String),
  file: Option(String),
) -> #(Result(inbox.Format, String), Option(String)) {
  case args {
    [] -> #(format, file)
    ["--format", value, ..rest] ->
      do_parse_inbox(rest, inbox.parse_format(value), file)
    [arg, ..rest] -> do_parse_inbox(rest, format, Some(arg))
  }
}

fn default_inbox_path() -> String {
  memory_home_subpath("/raw/inbox")
}

/// Look for `--agent X` in args. Default to ClaudeCode if absent.
fn parse_agent_flag(args: List(String)) -> Result(hook.Agent, String) {
  case args {
    [] -> Ok(hook.ClaudeCode)
    ["--agent", name, ..] -> hook.parse_agent(name)
    [_, ..rest] -> parse_agent_flag(rest)
  }
}

// --- create ---

fn run_create(args: List(String)) -> Nil {
  let content_result = case args {
    ["--file", path] -> simplifile.read(path)
    [] -> read_stdin_result()
    _ -> {
      io.println("Usage: memory create [--file path]")
      exit(1)
      Error(simplifile.Unknown(""))
    }
  }

  case content_result {
    Error(_) -> {
      io.println("✗ failed to read input")
      exit(1)
    }
    Ok(content) -> do_create(content)
  }
}

fn do_create(content: String) -> Nil {
  case frontmatter.parse_file(content, "stdin") {
    Error(msg) -> {
      io.println("✗ parse error: " <> msg)
      exit(1)
    }
    Ok(parsed) -> {
      // Set file_path to match id so the validator's id-format check passes.
      let new_entry = Entry(..parsed, file_path: parsed.id <> ".md")
      let wiki_path = default_wiki_path()

      case store.read_wiki(wiki_path) {
        Error(msg) -> {
          io.println("✗ " <> msg)
          exit(1)
        }
        Ok(results) -> {
          let #(existing, _parse_errors) = store.partition_results(results)
          // Drop any existing entry with the same id (replace semantics).
          let others = list.filter(existing, fn(e) { e.id != new_entry.id })
          let union = [new_entry, ..others]
          let all_errors = validate.validate_all(union)
          // Only block on errors involving the new entry. Pre-existing
          // errors in unrelated entries are not the new entry's problem.
          let errors =
            list.filter(all_errors, fn(e) {
              error_about_entry(e, new_entry.id, new_entry.file_path)
            })

          case errors {
            [] -> {
              let path = wiki_path <> "/" <> new_entry.id <> ".md"
              case simplifile.write(path, content) {
                Ok(_) -> io.println("✓ created " <> new_entry.id)
                Error(_) -> {
                  io.println("✗ failed to write " <> path)
                  exit(1)
                }
              }
            }
            _ -> {
              list.each(errors, fn(e) {
                io.println("✗ " <> entry.format_error(e))
              })
              exit(1)
            }
          }
        }
      }
    }
  }
}

// --- delete ---

fn run_delete(id: String, force: Bool) -> Nil {
  let wiki_path = default_wiki_path()
  case store.read_wiki(wiki_path) {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(results) -> {
      let #(entries, _parse_errors) = store.partition_results(results)
      case list.find(entries, fn(e) { e.id == id }) {
        Error(_) -> {
          io.println("✗ entry not found: " <> id)
          exit(1)
        }
        Ok(found) -> {
          // Validate the wiki state AFTER deletion to catch broken links.
          let post_delete = list.filter(entries, fn(e) { e.id != id })
          let errors = validate.validate_all(post_delete)
          let path = wiki_path <> "/" <> found.file_path

          case errors, force {
            [], _ -> do_delete_file(path, id, "")
            _, True ->
              do_delete_file(
                path,
                id,
                " (--force, "
                  <> int.to_string(list.length(errors))
                  <> " validation error(s) introduced)",
              )
            _, False -> {
              io.println(
                "✗ delete would break "
                <> int.to_string(list.length(errors))
                <> " entries:",
              )
              list.each(errors, fn(e) {
                io.println("  ✗ " <> entry.format_error(e))
              })
              io.println("Use --force to delete anyway.")
              exit(1)
            }
          }
        }
      }
    }
  }
}

fn do_delete_file(path: String, id: String, suffix: String) -> Nil {
  case simplifile.delete(path) {
    Ok(_) -> io.println("✓ deleted " <> id <> suffix)
    Error(_) -> {
      io.println("✗ failed to delete " <> path)
      exit(1)
    }
  }
}

// --- list ---

fn run_list(path: String, namespace: Option(String)) -> Nil {
  case store.read_wiki(path) {
    Error(msg) -> {
      io.println("✗ " <> msg)
      exit(1)
    }
    Ok(results) -> {
      let #(entries, _) = store.partition_results(results)
      let filtered = case namespace {
        None -> entries
        Some(ns) ->
          list.filter(entries, fn(e) { string.starts_with(e.id, ns <> ".") })
      }
      let sorted = list.sort(filtered, fn(a, b) { string.compare(a.id, b.id) })
      list.each(sorted, fn(e) { io.println(e.id <> "\t" <> e.title) })
    }
  }
}

/// True if the validation error is about the given entry (by id or filename).
fn error_about_entry(
  err: ValidationError,
  entry_id: String,
  file_path: String,
) -> Bool {
  case err {
    MissingField(id, _) -> id == entry_id
    BrokenLink(id, _) -> id == entry_id
    EmptyLabel(id, _) -> id == entry_id
    LinkMismatch(id, _) -> id == entry_id
    InvalidTimestamp(id, _, _) -> id == entry_id
    InvalidTag(id, _) -> id == entry_id
    InvalidId(id, _) -> id == entry_id
    DuplicateId(id, _) -> id == entry_id
    ParseError(file, _) -> file == file_path
  }
}

// --- helpers ---

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

fn read_stdin_result() -> Result(String, simplifile.FileError) {
  case read_stdin() {
    Ok(s) -> Ok(s)
    Error(_) -> Error(simplifile.Unknown("stdin read failed"))
  }
}

@external(javascript, "./ffi/env.mjs", "getEnv")
fn get_env(name: String) -> Result(String, Nil)

@external(javascript, "./ffi/env.mjs", "readStdin")
fn read_stdin() -> Result(String, Nil)

@external(javascript, "./ffi/env.mjs", "exit")
fn exit(code: Int) -> Nil
