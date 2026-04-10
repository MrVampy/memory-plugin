/**
 * Memory plugin for OpenCode.
 *
 * After the lean refactor, this plugin only handles permission auto-allow
 * for raw → processed file moves. Recall and create are agent-driven via
 * the `memory` CLI — no system prompt injection, no transcript capture.
 *
 * - permission.ask: auto-allow Bash mv between ~/.memory/raw and
 *                   ~/.memory/processed (used by the process skill).
 *
 * The actual permission logic lives in the Gleam `memory` CLI; this
 * plugin shells out to `memory hook permission --agent opencode`.
 */

import { execFileSync } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const MEMORY_BIN = "memory"

const MemoryPlugin: Plugin = async () => {
  return {
    "permission.ask": async (input, output) => {
      const decision = callMemory(
        ["hook", "permission", "--agent", "opencode"],
        JSON.stringify({
          tool_name: opencodeToolName(input),
          tool_input: opencodeToolInput(input),
        }),
      )
      if (decision.includes('"allow"')) {
        output.status = "allow"
      }
    },
  }
}

// --- helpers ---

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

// OpenCode's Permission shape differs from Claude Code's. We map it to
// the {tool_name, tool_input: {file_path|command}} shape that
// `memory hook permission` expects.
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
