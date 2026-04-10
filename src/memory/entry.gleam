/// Wiki entry types — the structural schema.
/// Gleam enforces the shape; the LLM decides the content.

pub type Entry {
  Entry(
    id: String,
    title: String,
    kind: String,
    tags: List(String),
    links: List(Link),
    meta: Meta,
    body: String,
    file_path: String,
  )
}

pub type Link {
  Link(target: String, label: String)
}

pub type Meta {
  Meta(created: String, updated: String, sources: List(String))
}

pub type ValidationError {
  MissingField(entry_id: String, field: String)
  BrokenLink(entry_id: String, target: String)
  DuplicateId(id: String, files: List(String))
  LinkMismatch(entry_id: String, reason: String)
  EmptyLabel(entry_id: String, target: String)
  InvalidTimestamp(entry_id: String, field: String, value: String)
  InvalidTag(entry_id: String, tag: String)
  InvalidId(entry_id: String, reason: String)
  ParseError(file: String, reason: String)
}

/// Format a validation error as a human-readable string
pub fn format_error(error: ValidationError) -> String {
  case error {
    MissingField(id, field) ->
      id <> ": missing required field '" <> field <> "'"
    BrokenLink(id, target) ->
      id <> ": broken link → '" <> target <> "' (entry does not exist)"
    DuplicateId(id, files) ->
      "duplicate id '" <> id <> "' in: " <> string_join(files, ", ")
    LinkMismatch(id, reason) ->
      id <> ": link mismatch → " <> reason
    EmptyLabel(id, target) ->
      id <> ": empty label for link → '" <> target <> "'"
    InvalidTimestamp(id, field, value) ->
      id <> ": invalid timestamp in '" <> field <> "': " <> value
    InvalidTag(id, tag) ->
      id <> ": invalid tag '" <> tag <> "' (must be non-empty lowercase slug)"
    InvalidId(id, reason) ->
      id <> ": invalid id → " <> reason
    ParseError(file, reason) ->
      file <> ": parse error → " <> reason
  }
}

fn string_join(items: List(String), sep: String) -> String {
  case items {
    [] -> ""
    [x] -> x
    [x, ..rest] -> x <> sep <> string_join(rest, sep)
  }
}
