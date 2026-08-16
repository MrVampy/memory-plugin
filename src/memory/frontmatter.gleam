/// YAML frontmatter parser.
/// Splits markdown into frontmatter and body, then decodes the frontmatter into
/// the typed Entry schema.
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import memory/entry.{type Entry, type Link, Entry, Link, Meta}

type FrontmatterDocument {
  FrontmatterDocument(
    id: String,
    title: String,
    kind: String,
    tags: List(String),
    links: List(Link),
    meta: FrontmatterMeta,
  )
}

type FrontmatterMeta {
  FrontmatterMeta(created: String, updated: String, sources: List(String))
}

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
  use #(yaml_source, body) <- result.try(split(content))
  use json_source <- result.try(
    parse_document(yaml_source)
    |> result.map_error(fn(_) { "YAML parse error" }),
  )
  use document <- result.try(
    json.parse(json_source, frontmatter_decoder())
    |> result.map_error(fn(_) { "invalid frontmatter structure" }),
  )

  Ok(Entry(
    id: document.id,
    title: document.title,
    kind: document.kind,
    tags: document.tags,
    links: document.links,
    meta: Meta(
      created: document.meta.created,
      updated: document.meta.updated,
      sources: document.meta.sources,
    ),
    body: body,
    file_path: file_path,
  ))
}

fn frontmatter_decoder() -> decode.Decoder(FrontmatterDocument) {
  {
    use id <- decode.field("id", decode.string)
    use title <- decode.field("title", decode.string)
    use kind <- decode.field("kind", decode.string)
    use tags <- optional_list_field("tags", decode.string)
    use links <- optional_list_field("links", link_decoder())
    use meta <- decode.field("meta", meta_decoder())
    decode.success(FrontmatterDocument(id:, title:, kind:, tags:, links:, meta:))
  }
}

fn link_decoder() -> decode.Decoder(Link) {
  {
    use target <- decode.field("target", decode.string)
    use label <- decode.field("label", decode.string)
    decode.success(Link(target:, label:))
  }
}

fn meta_decoder() -> decode.Decoder(FrontmatterMeta) {
  {
    use created <- decode.field("created", decode.string)
    use updated <- decode.field("updated", decode.string)
    use sources <- decode.field("sources", decode.list(of: decode.string))
    decode.success(FrontmatterMeta(created:, updated:, sources:))
  }
}

fn optional_list_field(
  name: String,
  item_decoder: decode.Decoder(item),
) -> decode.Decoder(List(item)) {
  decode.optional_field(
    name,
    None,
    decode.optional(decode.list(of: item_decoder)),
  )
  |> decode.map(fn(value) {
    case value {
      Some(items) -> items
      None -> []
    }
  })
}

@external(javascript, "./ffi/yaml.mjs", "parseDocument")
fn parse_document(content: String) -> Result(String, Nil)
