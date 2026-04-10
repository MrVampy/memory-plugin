/**
 * Memory plugin for OpenCode.
 *
 * Wires the `memory` CLI into OpenCode's hook surface:
 *
 * - chat.message:                  capture latest user prompt per session
 * - experimental.chat.system.transform:
 *                                  inject recall context based on captured prompt
 * - permission.ask:                auto-allow Write/Edit on ~/.memory wiki paths,
 *                                  and bash mv between raw/ and processed/
 *
 * The actual recall and permission logic lives in the Gleam `memory` CLI;
 * this plugin is a thin shim that translates OpenCode's plugin API into
 * stdin/stdout calls against the binary on PATH.
 */

import { execFileSync } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const MEMORY_BIN = "memory"

// Per-session: most recent user prompt text. We need this because
// experimental.chat.system.transform doesn't receive the user message —
// only sessionID and model — so we have to capture it from chat.message
// and look it up later.
const lastPromptBySession = new Map<string, string>()

const MemoryPlugin: Plugin = async () => {
  return {
    "chat.message": async (_input, output) => {
      const text = extractText(output.parts)
      if (text) {
        lastPromptBySession.set(output.message.sessionID, text)
      }
    },

    "experimental.chat.system.transform": async (input, output) => {
      if (!input.sessionID) return
      const prompt = lastPromptBySession.get(input.sessionID)
      if (!prompt) return

      const recall = callMemory(
        ["hook", "recall", "--agent", "opencode"],
        JSON.stringify({ prompt }),
      )
      // Plain text body — the OpenCode branch in memory hook recall emits
      // unwrapped text instead of a JSON envelope. Append to the system
      // prompt so the model sees it for this turn.
      if (recall.trim()) {
        output.system.push(recall)
      }
    },

    "permission.ask": async (input, output) => {
      const decision = callMemory(
        ["hook", "permission", "--agent", "opencode"],
        JSON.stringify({
          tool_name: opencodeToolName(input),
          tool_input: opencodeToolInput(input),
        }),
      )
      // The permission hook returns the Claude Code envelope by default.
      // For OpenCode we just check whether the CLI decided "allow".
      if (decision.includes('"allow"')) {
        output.status = "allow"
      }
    },
  }
}

// --- helpers ---

function extractText(parts: Array<{ type: string; text?: string }>): string {
  return parts
    .filter((p) => p.type === "text" && typeof p.text === "string")
    .map((p) => p.text!)
    .join("\n")
    .trim()
}

function callMemory(args: string[], stdin: string): string {
  try {
    return execFileSync(MEMORY_BIN, args, {
      input: stdin,
      encoding: "utf8",
      timeout: 5000,
    })
  } catch {
    return ""
  }
}

// OpenCode's Permission shape differs from Claude Code's. We need to
// map it to the {tool_name, tool_input: {file_path|command}} shape that
// `memory hook permission` expects.
//
// Permission has: { id, type, pattern, sessionID, messageID, callID, title, metadata }
// where `metadata` typically holds the tool's args. We do best-effort
// mapping based on `type` and `metadata`.
function opencodeToolName(p: any): string {
  if (p.type === "edit" || p.type === "write") return "Write"
  if (p.type === "bash" || p.type === "shell") return "Bash"
  return p.type ?? ""
}

function opencodeToolInput(p: any): Record<string, unknown> {
  const md = p.metadata ?? {}
  return {
    file_path: md.file_path ?? md.filePath ?? md.path ?? "",
    command: md.command ?? md.cmd ?? "",
  }
}

export default MemoryPlugin
