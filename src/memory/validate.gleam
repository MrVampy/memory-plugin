/// Validation rules for the wiki.
/// Operates on a list of parsed entries, checks structural integrity.

import gleam/dict
import gleam/list
import gleam/string
import memory/body
import memory/entry.{
  type Entry, type ValidationError, BrokenLink, DuplicateId, EmptyLabel,
  LinkMismatch, MissingField,
}

/// Validate a list of entries. Returns a list of all errors found.
pub fn validate_all(entries: List(Entry)) -> List(ValidationError) {
  let id_set = build_id_set(entries)

  list.flatten([
    check_required_fields(entries),
    check_duplicate_ids(entries),
    check_broken_links(entries, id_set),
    check_empty_labels(entries),
    check_link_consistency(entries),
  ])
}

/// Check that every entry has required fields (non-empty).
fn check_required_fields(entries: List(Entry)) -> List(ValidationError) {
  list.flat_map(entries, fn(e) {
    let checks = [
      #(e.id, "id"),
      #(e.title, "title"),
      #(e.kind, "kind"),
      #(e.meta.created, "meta.created"),
      #(e.meta.updated, "meta.updated"),
    ]
    list.filter_map(checks, fn(check) {
      let #(value, field) = check
      case string.is_empty(string.trim(value)) {
        True -> Ok(MissingField(entry_id: e.id, field: field))
        False -> Error(Nil)
      }
    })
  })
}

/// Check for duplicate entry ids.
fn check_duplicate_ids(entries: List(Entry)) -> List(ValidationError) {
  let grouped =
    list.fold(entries, dict.new(), fn(acc, e) {
      let existing = case dict.get(acc, e.id) {
        Ok(files) -> files
        Error(_) -> []
      }
      dict.insert(acc, e.id, [e.file_path, ..existing])
    })

  dict.fold(grouped, [], fn(acc, id, files) {
    case list.length(files) > 1 {
      True -> [DuplicateId(id: id, files: files), ..acc]
      False -> acc
    }
  })
}

/// Check that all link targets resolve to existing entry ids.
fn check_broken_links(
  entries: List(Entry),
  id_set: dict.Dict(String, Nil),
) -> List(ValidationError) {
  list.flat_map(entries, fn(e) {
    list.filter_map(e.links, fn(link) {
      // Allow global: prefix for cross-boundary links
      let target = case string.starts_with(link.target, "global:") {
        True -> string.drop_start(link.target, 7)
        False -> link.target
      }
      case dict.has_key(id_set, target) {
        True -> Error(Nil)
        False -> Ok(BrokenLink(entry_id: e.id, target: link.target))
      }
    })
  })
}

/// Check that no link has an empty label.
fn check_empty_labels(entries: List(Entry)) -> List(ValidationError) {
  list.flat_map(entries, fn(e) {
    list.filter_map(e.links, fn(link) {
      case string.is_empty(string.trim(link.label)) {
        True -> Ok(EmptyLabel(entry_id: e.id, target: link.target))
        False -> Error(Nil)
      }
    })
  })
}

/// Check frontmatter links match [[refs]] in body.
fn check_link_consistency(entries: List(Entry)) -> List(ValidationError) {
  list.flat_map(entries, fn(e) {
    let body_refs = body.extract_refs(e.body)
    let fm_targets = list.map(e.links, fn(l) { l.target })

    let in_body_not_fm =
      list.filter_map(body_refs, fn(ref) {
        case list.contains(fm_targets, ref) {
          True -> Error(Nil)
          False ->
            Ok(LinkMismatch(
              entry_id: e.id,
              reason: "[[" <> ref <> "]] in body but not in frontmatter links",
            ))
        }
      })

    let in_fm_not_body =
      list.filter_map(fm_targets, fn(target) {
        case list.contains(body_refs, target) {
          True -> Error(Nil)
          False ->
            Ok(LinkMismatch(
              entry_id: e.id,
              reason: "'" <> target <> "' in frontmatter links but not [[referenced]] in body",
            ))
        }
      })

    list.flatten([in_body_not_fm, in_fm_not_body])
  })
}

/// Build a set of all entry ids for lookup.
fn build_id_set(entries: List(Entry)) -> dict.Dict(String, Nil) {
  list.fold(entries, dict.new(), fn(acc, e) { dict.insert(acc, e.id, Nil) })
}
