#!/usr/bin/env node
/**
 * memory-mcp — MCP server exposing the memory CLI's write operations as tools.
 *
 * Reads (recall, list, read full entries) are NOT exposed here. They go
 * through the agent's native Read/Glob/Grep tools against `~/.memory/wiki/`,
 * with the recall skill description teaching the patterns. The grep/glob
 * approach has fewer composition steps than an MCP read tool would, and
 * native tools are always in the agent's tool list with their own schemas.
 *
 * Writes still need MCP because:
 *   1. Native Write/Edit bypass our type validator
 *   2. memory_create wraps validate-on-write in a named tool
 *   3. The alternative (Bash → CLI) has the composition friction that
 *      was the failure mode of the lean experiment
 *
 * Tools exposed:
 *   memory_create(markdown)         — upsert with validate-on-write
 *   memory_delete(id, force?)       — delete with cross-entry validation
 *   memory_inbox(transcript_path)   — archive a transcript for later processing
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js"
import { spawnSync } from "node:child_process"

const MEMORY_BIN = process.env.MEMORY_BIN || "memory"

const server = new Server(
  { name: "memory", version: "0.1.0" },
  { capabilities: { tools: {} } },
)

// --- tool definitions ---

const TOOLS = [
  {
    name: "memory_create",
    description:
      "Create or update a wiki entry in the user's persistent memory at ~/.memory/wiki/. Pass the full markdown including YAML frontmatter (id, title, kind, tags, links, meta). The entry is validated on write — if frontmatter is malformed, links are broken, or tags use flow-style instead of block-style, the call returns errors and nothing is written. This is an upsert: if an entry with the same id exists, it is replaced. CALL THIS PROACTIVELY whenever you learn or decide something worth keeping for future sessions: user preferences, technical decisions, project context, design rationale, personal facts. Always read existing related entries first (via Grep on ~/.memory/wiki/) so you can update an existing entry rather than create a duplicate.",
    inputSchema: {
      type: "object",
      properties: {
        markdown: {
          type: "string",
          description:
            "Full entry markdown including YAML frontmatter. Required fields: id (dot-notation, must match filename), title, kind, tags (block-style YAML list, NOT flow-style [a, b]), links (each with target and label), meta.created, meta.updated, meta.sources. Body must contain [[id]] inline references matching every frontmatter link target.",
        },
      },
      required: ["markdown"],
    },
  },
  {
    name: "memory_delete",
    description:
      "Delete a wiki entry by id from ~/.memory/wiki/. The CLI validates the post-delete state and refuses if removing this entry would break links from other entries. Pass force=true to override.",
    inputSchema: {
      type: "object",
      properties: {
        id: {
          type: "string",
          description: "The entry id to delete (e.g. 'cognitive.intp.profile').",
        },
        force: {
          type: "boolean",
          description:
            "If true, delete even if it would break links in other entries.",
        },
      },
      required: ["id"],
    },
  },
  {
    name: "memory_inbox",
    description:
      "Archive a session transcript file into ~/.memory/raw/inbox/ for later processing by the memory:process skill. Format (Claude Code or Codex JSONL) is auto-detected. Use this at the end of substantial conversations as a fallback when proactive memory_create may have missed something — it is NOT the primary path. The primary path is calling memory_create live during the conversation.",
    inputSchema: {
      type: "object",
      properties: {
        transcript_path: {
          type: "string",
          description:
            "Absolute path to the transcript file. Claude Code: ~/.claude/projects/<slug>/<session-id>.jsonl. Codex: ~/.codex/sessions/<year>/<month>/<day>/rollout-...jsonl.",
        },
      },
      required: ["transcript_path"],
    },
  },
]

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }))

// --- tool dispatch ---

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params
  try {
    switch (name) {
      case "memory_create":
        return runWithStdin(["create"], args.markdown)

      case "memory_delete": {
        const cmd = args.force
          ? ["delete", args.id, "--force"]
          : ["delete", args.id]
        return runCapturing(cmd)
      }

      case "memory_inbox":
        return runCapturing(["inbox", args.transcript_path])

      default:
        return err(`unknown tool: ${name}`)
    }
  } catch (e) {
    return err(e?.message || String(e))
  }
})

// --- helpers ---

function runWithStdin(args, stdin) {
  const r = spawnSync(MEMORY_BIN, args, { input: stdin, encoding: "utf8" })
  const output = (r.stdout || "") + (r.stderr || "")
  if (r.status === 0) return ok(output.trim() || "ok")
  return err(output.trim() || `${MEMORY_BIN} ${args.join(" ")} failed`)
}

function runCapturing(args) {
  const r = spawnSync(MEMORY_BIN, args, { encoding: "utf8" })
  const output = (r.stdout || "") + (r.stderr || "")
  if (r.status === 0) return ok(output.trim() || "ok")
  return err(output.trim() || `${MEMORY_BIN} ${args.join(" ")} failed`)
}

function ok(text) {
  return { content: [{ type: "text", text }] }
}

function err(text) {
  return { content: [{ type: "text", text }], isError: true }
}

// --- start ---

const transport = new StdioServerTransport()
await server.connect(transport)
