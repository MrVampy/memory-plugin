/// File I/O — scan wiki directory, read and parse entries.
import gleam/list
import gleam/string
import memory/entry.{type Entry, type ValidationError, ParseError}
import memory/frontmatter
import simplifile

/// Read all .md entries from a wiki directory (excluding INDEX.md).
pub fn read_wiki(
  dir: String,
) -> Result(List(Result(Entry, ValidationError)), String) {
  case simplifile.read_directory(dir) {
    Error(_) -> Error("cannot read directory: " <> dir)
    Ok(files) -> {
      let md_files =
        list.filter(files, fn(f) {
          string.ends_with(f, ".md") && f != "INDEX.md"
        })

      let results =
        list.map(md_files, fn(filename) {
          let path = dir <> "/" <> filename
          case simplifile.read(path) {
            Error(_) ->
              Error(ParseError(file: filename, reason: "cannot read file"))
            Ok(content) -> {
              case frontmatter.parse_file(content, filename) {
                Error(reason) ->
                  Error(ParseError(file: filename, reason: reason))
                Ok(entry) -> Ok(entry)
              }
            }
          }
        })

      Ok(results)
    }
  }
}

/// Separate parse results into entries and parse errors.
pub fn partition_results(
  results: List(Result(Entry, ValidationError)),
) -> #(List(Entry), List(ValidationError)) {
  list.fold(results, #([], []), fn(acc, r) {
    let #(entries, errors) = acc
    case r {
      Ok(entry) -> #([entry, ..entries], errors)
      Error(err) -> #(entries, [err, ..errors])
    }
  })
}
