// Transcript filters — agent-specific JSONL → filtered JSONL.
// Each function takes the raw transcript content and returns the
// filtered content as a string (newline-separated JSONL).

/// Claude Code transcript: {type: user|assistant, message: {role, content}}
/// where content is either a string or a list of {type, text} blocks.
/// Drops tool_use, system reminders, command tags, and empty messages.
export function filterClaudeCode(content) {
  const out = [];
  for (const line of content.split("\n")) {
    if (!line.trim()) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }

    const type = msg.type;
    if (type !== "user" && type !== "assistant") continue;

    const inner = msg.message || {};
    const role = inner.role || type;
    const c = inner.content;

    let texts = [];
    if (Array.isArray(c)) {
      for (const block of c) {
        if (!block || typeof block !== "object") continue;
        if (block.type !== "text") continue;
        const text = block.text || "";
        if (isFiltered(text)) continue;
        if (text.trim()) texts.push(text);
      }
    } else if (typeof c === "string" && c.trim()) {
      if (!isFiltered(c)) texts.push(c);
    }

    if (texts.length > 0) {
      out.push(JSON.stringify({ role, content: texts }));
    }
  }
  return out.join("\n") + (out.length > 0 ? "\n" : "");
}

/// Codex transcript: {timestamp, type, payload} where message lines have
/// type="response_item" and payload={type:"message", role, content:[{type, text}]}.
/// Drops developer role, environment_context blocks, and non-message types.
export function filterCodex(content) {
  const out = [];
  for (const line of content.split("\n")) {
    if (!line.trim()) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }

    if (msg.type !== "response_item") continue;
    const p = msg.payload;
    if (!p || p.type !== "message") continue;

    const role = p.role;
    if (role !== "user" && role !== "assistant") continue;

    const c = p.content;
    if (!Array.isArray(c)) continue;

    let texts = [];
    for (const block of c) {
      if (!block || typeof block !== "object") continue;
      if (block.type !== "input_text" && block.type !== "output_text") continue;
      const text = block.text || "";
      if (isFiltered(text)) continue;
      if (text.trim()) texts.push(text);
    }

    if (texts.length > 0) {
      out.push(JSON.stringify({ role, content: texts }));
    }
  }
  return out.join("\n") + (out.length > 0 ? "\n" : "");
}

/// Detect transcript format by scanning until a recognizable line is
/// found. Returns "claude-code", "codex", or "" if neither shape appears.
export function detectFormat(content) {
  let scanned = 0;
  for (const line of content.split("\n")) {
    if (scanned > 50) break;
    if (!line.trim()) continue;
    scanned++;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    // Codex lines: {timestamp, type, payload}
    if (msg.payload && msg.timestamp) return "codex";
    // Claude Code message lines: {type: user|assistant, message: {...}}
    if ((msg.type === "user" || msg.type === "assistant") && msg.message) return "claude-code";
  }
  return "";
}

function isFiltered(text) {
  return text.startsWith("<system-reminder>")
    || text.startsWith("<command-")
    || text.startsWith("<local-command")
    || text.startsWith("<environment_context>")
    || text.startsWith("<permissions instructions>");
}
