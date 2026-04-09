/// YAML frontmatter parser using yay (pure Gleam YAML parser).
/// Splits markdown into frontmatter + body, parses frontmatter into Entry.

import gleam/result
import gleam/string
import memory/entry.{type Entry, type Link, Entry, Link, Meta}
import yay

/// Split a markdown file into raw frontmatter string and body string.
/// Expects --- delimiters.
pub fn split(content: String) -> Result(#(String, String), String) {
  case string.starts_with(content, "---") {
    False -> Error("file does not start with '---' frontmatter delimiter")
    True -> {
      let rest = string.drop_start(content, 3)
      let rest = string.trim_start(rest)
      case string.split_once(rest, "\n---") {
        Error(_) -> Error("missing closing '---' frontmatter delimiter")
        Ok(#(fm, body)) -> {
          let body = case string.starts_with(body, "\n") {
            True -> string.drop_start(body, 1)
            False -> body
          }
          Ok(#(string.trim(fm), body))
        }
      }
    }
  }
}

/// Parse a full markdown file (frontmatter + body) into an Entry.
pub fn parse_file(content: String, file_path: String) -> Result(Entry, String) {
  use #(yaml_str, body) <- result.try(split(content))
  use docs <- result.try(
    yay.parse_string(yaml_str)
    |> result.map_error(fn(_) { "YAML parse error" }),
  )
  use doc <- result.try(case docs {
    [doc] -> Ok(doc)
    _ -> Error("expected exactly one YAML document in frontmatter")
  })

  let root = yay.document_root(doc)

  use id <- result.try(extract(root, "id"))
  use title <- result.try(extract(root, "title"))
  use kind <- result.try(extract(root, "kind"))
  use created <- result.try(extract(root, "meta.created"))
  use updated <- result.try(extract(root, "meta.updated"))
  use sources <- result.try(extract_list(root, "meta.sources"))
  use links <- result.try(parse_links(root))

  Ok(Entry(
    id: id,
    title: title,
    kind: kind,
    links: links,
    meta: Meta(created: created, updated: updated, sources: sources),
    body: body,
    file_path: file_path,
  ))
}

/// Extract a string field, mapping error to a readable message.
fn extract(node: yay.Node, key: String) -> Result(String, String) {
  yay.extract_string(node, key)
  |> result.map_error(fn(_) { "missing or invalid '" <> key <> "' field" })
}

/// Extract a string list field, mapping error to a readable message.
fn extract_list(node: yay.Node, key: String) -> Result(List(String), String) {
  yay.extract_string_list(node, key)
  |> result.map_error(fn(_) { "missing or invalid '" <> key <> "' field" })
}

/// Parse the links array from the YAML root node.
fn parse_links(root: yay.Node) -> Result(List(Link), String) {
  case yay.extract_list_with(root, "links", parse_single_link) {
    Ok(links) -> Ok(links)
    // If links key is missing, that's fine — no links
    Error(yay.KeyMissing(..)) -> Ok([])
    Error(yay.KeyValueEmpty(..)) -> Ok([])
    Error(err) ->
      Error("invalid 'links' field: " <> yay.extraction_error_to_string(err))
  }
}

/// Parse a single link node.
fn parse_single_link(node: yay.Node) -> Result(Link, yay.ExtractionError) {
  use target <- result.try(yay.extract_string(node, "target"))
  use label <- result.try(yay.extract_string(node, "label"))
  Ok(Link(target: target, label: label))
}
