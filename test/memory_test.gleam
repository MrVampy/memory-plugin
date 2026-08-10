import gleam/list
import gleeunit
import memory/entry.{
  type Entry, type Link, BrokenLink, Entry, Link, LinkMismatch, Meta,
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
