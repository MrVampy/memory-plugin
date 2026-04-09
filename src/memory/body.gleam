/// Body parser — extract [[refs]] from markdown body text.

import gleam/list
import gleam/string

/// Extract all [[entry-id]] references from a body string.
/// Returns a list of unique entry ids referenced.
pub fn extract_refs(body: String) -> List(String) {
  do_extract_refs(body, [])
  |> list.unique()
}

fn do_extract_refs(remaining: String, acc: List(String)) -> List(String) {
  case string.split_once(remaining, "[[") {
    Error(_) -> acc
    Ok(#(_, after_open)) -> {
      case string.split_once(after_open, "]]") {
        Error(_) -> acc
        Ok(#(ref, rest)) -> {
          let trimmed = string.trim(ref)
          case trimmed {
            "" -> do_extract_refs(rest, acc)
            _ -> do_extract_refs(rest, [trimmed, ..acc])
          }
        }
      }
    }
  }
}
