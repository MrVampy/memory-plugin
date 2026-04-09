/// Index generator — produces INDEX.md from a list of entries.

import gleam/list
import gleam/string
import memory/entry.{type Entry}
import simplifile

/// Generate index content as a string.
pub fn generate(entries: List(Entry)) -> String {
  let header = "# Wiki Index\n\n"

  let lines =
    entries
    |> list.sort(fn(a, b) { string.compare(a.id, b.id) })
    |> list.map(format_entry)
    |> string.join("\n")

  header <> lines <> "\n"
}

/// Format a single entry for the index.
fn format_entry(e: Entry) -> String {
  let links_str = case e.links {
    [] -> ""
    links -> {
      let labels =
        list.map(links, fn(l) { "  - → " <> l.target <> ": " <> l.label })
        |> string.join("\n")
      "\n" <> labels
    }
  }

  "- **" <> e.id <> "** — " <> e.title <> " [" <> e.kind <> "]" <> links_str
}

/// Write index to a file.
pub fn write(entries: List(Entry), dir: String) -> Result(Nil, String) {
  let content = generate(entries)
  let path = dir <> "/INDEX.md"
  case simplifile.write(path, content) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("failed to write index to " <> path)
  }
}
