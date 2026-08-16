import gleam/list
import gleeunit
import memory/entry.{
  type Entry, type Link, BrokenLink, Entry, InvalidId, Link, LinkMismatch, Meta,
}
import memory/frontmatter
import memory/validate

pub fn main() -> Nil {
  gleeunit.main()
}

const valid_document = "---\nid: test.basic\ntitle: Basic fixture\nkind: fixture\ntags:\n  - test\nlinks: []\nmeta:\n  created: \"2026-08-10T00:00:00\"\n  updated: \"2026-08-10T00:00:00\"\n  sources:\n    - test\n---\n\n# Basic fixture\n"

pub fn parses_and_validates_a_structural_entry_test() {
  let assert Ok(entry) = frontmatter.parse_file(valid_document, "test.basic.md")
  assert entry.id == "test.basic"
  assert validate.validate_all([entry]) == []
}

pub fn parses_repeated_link_fields_and_colon_bearing_sources_test() {
  let document =
    "---\nid: test.links\ntitle: Link fixture\nkind: fixture\ntags:\n  - test\nlinks:\n  - target: test.first\n    label: first\n  - target: test.second\n    label: second\nmeta:\n  created: \"2026-08-10T00:00:00\"\n  updated: \"2026-08-10T00:00:00\"\n  sources:\n    - \"tuxedo:session:one\"\n---\n\nSee [[test.first]] and [[test.second]].\n"

  let assert Ok(entry) = frontmatter.parse_file(document, "test.links.md")
  assert entry.links
    == [
      Link(target: "test.first", label: "first"),
      Link(target: "test.second", label: "second"),
    ]
  assert entry.meta.sources == ["tuxedo:session:one"]
}

pub fn rejects_duplicate_yaml_keys_test() {
  let document =
    "---\nid: test.first\nid: test.second\ntitle: Duplicate fixture\nkind: fixture\nmeta:\n  created: \"2026-08-10T00:00:00\"\n  updated: \"2026-08-10T00:00:00\"\n  sources: []\n---\n\nDuplicate fixture.\n"

  let assert Error(_) = frontmatter.parse_file(document, "test.duplicate.md")
}

pub fn rejects_implicitly_typed_yaml_timestamps_test() {
  let document =
    "---\nid: test.timestamp\ntitle: Timestamp fixture\nkind: fixture\nmeta:\n  created: 2026-08-10T00:00:00.000Z\n  updated: \"2026-08-10T00:00:00\"\n  sources: []\n---\n\nTimestamp fixture.\n"

  let assert Error(_) = frontmatter.parse_file(document, "test.timestamp.md")
}

pub fn rejects_a_link_to_an_absent_entry_test() {
  let entry =
    fixture_entry(
      [Link(target: "test.missing", label: "missing")],
      "See [[test.missing]].",
    )
  let errors = validate.validate_all([entry])
  assert list.contains(
    errors,
    BrokenLink(entry_id: "test.source", target: "test.missing"),
  )
}

pub fn rejects_body_and_frontmatter_link_drift_test() {
  let entry = fixture_entry([], "See [[test.target]].")
  let errors = validate.validate_all([entry])
  assert list.contains(
    errors,
    LinkMismatch(
      entry_id: "test.source",
      reason: "[[test.target]] in body but not in frontmatter links",
    ),
  )
}

pub fn accepts_underscores_in_a_safe_entry_id_test() {
  let entry = fixture_entry_with_id("lang.rust.to_string")
  assert validate.validate_all([entry]) == []
}

pub fn rejects_unsafe_entry_id_characters_test() {
  let entry = fixture_entry_with_id("lang.rust/to_string")
  let errors = validate.validate_all([entry])
  assert list.contains(
    errors,
    InvalidId(
      entry_id: "lang.rust/to_string",
      reason: "id must be a 3-240 character dot-notation identifier using lowercase ASCII letters, digits, '.', '-', or '_'",
    ),
  )
}

pub fn rejects_empty_namespace_segments_test() {
  let entry = fixture_entry_with_id("lang..rust")
  let errors = validate.validate_all([entry])
  assert list.contains(
    errors,
    InvalidId(
      entry_id: "lang..rust",
      reason: "id must be a 3-240 character dot-notation identifier using lowercase ASCII letters, digits, '.', '-', or '_'",
    ),
  )
}

fn fixture_entry(links: List(Link), body: String) -> Entry {
  Entry(
    id: "test.source",
    title: "Source",
    kind: "fixture",
    tags: ["test"],
    links: links,
    meta: Meta(
      created: "2026-08-10T00:00:00",
      updated: "2026-08-10T00:00:00",
      sources: ["test"],
    ),
    body: body,
    file_path: "test.source.md",
  )
}

fn fixture_entry_with_id(id: String) -> Entry {
  Entry(
    id: id,
    title: "Source",
    kind: "fixture",
    tags: ["test"],
    links: [],
    meta: Meta(
      created: "2026-08-10T00:00:00",
      updated: "2026-08-10T00:00:00",
      sources: ["test"],
    ),
    body: "Fixture.",
    file_path: id <> ".md",
  )
}
