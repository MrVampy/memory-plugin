/// Recall — keyword extraction, scoring, and summary formatting.
/// Ports the logic from hooks/recall.sh into Gleam.

import gleam/int
import gleam/json
import gleam/list
import gleam/order
import gleam/string
import memory/entry.{type Entry}

const stopwords = [
  "the", "and", "for", "are", "was", "were", "been", "being", "have", "has",
  "had", "does", "did", "will", "would", "could", "should", "can", "may",
  "might", "shall", "this", "that", "these", "those", "its", "our", "your",
  "his", "her", "him", "she", "they", "them", "their", "from", "into",
  "through", "during", "before", "after", "above", "below", "between", "out",
  "off", "over", "under", "again", "further", "then", "once", "here", "there",
  "when", "where", "why", "how", "what", "which", "who", "whom", "all", "any",
  "both", "each", "every", "few", "more", "most", "other", "some", "such",
  "nor", "not", "only", "own", "same", "than", "too", "very", "just",
  "also", "already", "still",
]

/// Extract keywords from a prompt: lowercase, ≥3 chars, no stopwords.
/// Also splits dot-notation segments so `tools.memory-recall` yields
/// `tools`, `memory-recall`, etc.
pub fn extract_keywords(prompt: String) -> List(String) {
  let lowered = string.lowercase(prompt)
  let words = split_on_non_word(lowered)
  let filtered =
    list.filter(words, fn(w) {
      string.length(w) >= 3 && !is_stopword(w)
    })
  let segments =
    list.flat_map(filtered, fn(w) { string.split(w, ".") })
    |> list.filter(fn(s) { string.length(s) >= 3 })
  list.flatten([filtered, segments])
  |> list.unique()
}

/// Score an entry by counting how many query keywords appear anywhere
/// in its searchable text (id, title, tags, body, link targets).
pub fn score_entry(entry: Entry, keywords: List(String)) -> Int {
  let searchable = searchable_text(entry)
  list.count(keywords, fn(kw) { string.contains(searchable, kw) })
}

fn searchable_text(entry: Entry) -> String {
  let link_targets =
    list.map(entry.links, fn(l) { l.target })
    |> string.join(" ")
  let tags = string.join(entry.tags, " ")
  string.lowercase(
    entry.id
    <> " "
    <> entry.title
    <> " "
    <> tags
    <> " "
    <> entry.body
    <> " "
    <> link_targets,
  )
}

/// Top N entries by score, descending. Drops entries with score 0.
pub fn top_matches(
  entries: List(Entry),
  keywords: List(String),
  limit: Int,
) -> List(Entry) {
  entries
  |> list.map(fn(e) { #(score_entry(e, keywords), e) })
  |> list.filter(fn(pair) { pair.0 > 0 })
  |> list.sort(fn(a, b) {
    case int.compare(b.0, a.0) {
      order.Eq -> string.compare(a.1.id, b.1.id)
      other -> other
    }
  })
  |> list.take(limit)
  |> list.map(fn(pair) { pair.1 })
}

/// Format a single entry as a summary block (matches recall.sh output).
pub fn format_summary(entry: Entry) -> String {
  let tags_str = string.join(entry.tags, ", ")
  let links_str =
    list.map(entry.links, fn(l) { l.target })
    |> string.join(",")
  "--- "
  <> entry.id
  <> " ---\n"
  <> "title: "
  <> entry.title
  <> "\n"
  <> "kind: "
  <> entry.kind
  <> "\n"
  <> "tags: "
  <> tags_str
  <> "\n"
  <> "links: "
  <> links_str
}

/// Format the full output text — header + all summaries.
pub fn format_output(matches: List(Entry)) -> String {
  let count = int.to_string(list.length(matches))
  let header =
    "**Recalled memories ("
    <> count
    <> " matches).** Read full entries at ~/.memory/wiki/<id>.md. Follow links for related knowledge. Use /memory:recall for deeper search."
  let summaries = list.map(matches, format_summary)
  [header, ..summaries]
  |> string.join("\n\n")
}

/// Wrap output as Claude Code UserPromptSubmit hook JSON.
pub fn format_json(output: String) -> String {
  json.object([
    #(
      "hookSpecificOutput",
      json.object([
        #("hookEventName", json.string("UserPromptSubmit")),
        #("additionalContext", json.string(output)),
      ]),
    ),
  ])
  |> json.to_string
}

// --- internal helpers ---

fn is_stopword(word: String) -> Bool {
  list.contains(stopwords, word)
}

/// Split a lowercased string into tokens, treating any character
/// that isn't [a-z0-9.-] as a separator.
fn split_on_non_word(s: String) -> List(String) {
  s
  |> string.to_graphemes()
  |> list.fold(#([], ""), fn(acc, ch) {
    let #(words, current) = acc
    case is_word_char(ch) {
      True -> #(words, current <> ch)
      False ->
        case current {
          "" -> #(words, "")
          _ -> #([current, ..words], "")
        }
    }
  })
  |> fn(acc) {
    let #(words, current) = acc
    case current {
      "" -> words
      _ -> [current, ..words]
    }
  }
  |> list.reverse()
}

fn is_word_char(ch: String) -> Bool {
  case ch {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" -> True
    "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" -> True
    "u" | "v" | "w" | "x" | "y" | "z" -> True
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    "." | "-" -> True
    _ -> False
  }
}
