#!/usr/bin/env node
/**
 * memory-mcp — MCP server exposing the memory CLI as native tools.
 *
 * Wraps the existing `memory` binary so coding agents (Claude Code,
 * Codex, OpenCode) see typed tool definitions in their tool list
 * instead of needing to remember a shell command. Each tool shells
 * out to `memory` under the hood — no business logic lives here.
 *
 * Tools exposed:
 *   memory_recall(query)         — keyword search, returns top matches
 *   memory_list(namespace?)      — list entries
 *   memory_read(id)              — read a full entry by id
 *   memory_create(markdown)      — upsert an entry (validates on write)
 *   memory_delete(id, force?)    — delete with cross-entry validation
 *   memory_inbox(transcript_path) — archive a transcript for later processing
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js"
import { execFileSync, spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const MEMORY_BIN = process.env.MEMORY_BIN || "memory"
const WIKI_DIR = process.env.MEMORY_HOME
  ? join(process.env.MEMORY_HOME, "wiki")
  : join(homedir(), ".memory", "wiki")

const server = new Server(
  { name: "memory", version: "0.1.0" },
  { capabilities: { tools: {} } },
)

// --- tool definitions ---

const TOOLS = [
  {
    name: "memory_recall",
    description:
      "Search persistent memory for entries matching the query keywords. Returns the top 5 matching wiki entries with id, title, kind, tags, and links. CALL THIS at the start of any non-trivial task — the cost of an unnecessary recall is small, the cost of acting without context is large. Use distinctive keywords from the topic, not generic words.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Search keywords. Distinctive terms work best.",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "memory_list",
    description:
      "List all wiki entries, optionally filtered by namespace prefix (e.g. 'lang.gleam' lists everything under lang.gleam.*). Returns id and title for each entry. Use this to browse a topic area when you don't have specific keywords.",
    inputSchema: {
      type: "object",
      properties: {
        namespace: {
          type: "string",
          description:
            "Optional namespace prefix to filter by (e.g. 'cognitive', 'lang.gleam', 'tools.memory').",
        },
      },
    },
  },
  {
    name: "memory_read",
    description:
      "Read the full content of a wiki entry by id. Use this after memory_recall or memory_list when you need the body of an entry, not just the summary.",
    inputSchema: {
      type: "object",
      properties: {
        id: {
          type: "string",
          description: "The entry id (e.g. 'cognitive.intp.profile').",
        },
      },
      required: ["id"],
    },
  },
  {
    name: "memory_create",
    description:
      "Create or update a wiki entry. Pass the full markdown including YAML frontmatter. The entry is validated on write — if frontmatter is malformed, links are broken, or tags are invalid, the call returns errors and nothing is written. This is an upsert: if an entry with the same id exists, it is replaced. CALL THIS proactively whenever you learn something worth keeping — user preferences, technical decisions, project context, design rationale.",
    inputSchema: {
      type: "object",
      properties: {
        markdown: {
          type: "string",
          description:
            "Full entry markdown including YAML frontmatter with id, title, kind, tags (block-style list), links, and meta (created/updated/sources). See an existing entry via memory_read for the format.",
        },
      },
      required: ["markdown"],
    },
  },
  {
    name: "memory_delete",
    description:
      "Delete a wiki entry by id. The CLI validates the post-delete state and refuses if removing this entry would break links from other entries. Pass force=true to override.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "The entry id to delete." },
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
      "Archive a session transcript file into ~/.memory/raw/inbox/ for later processing by the memory:process skill. Format (Claude Code or Codex JSONL) is auto-detected. Use this at the end of substantial conversations as a fallback when proactive memory_create may have missed something.",
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
      case "memory_recall":
        return ok(callMemory(["recall", args.query]))

      case "memory_list":
        return ok(
          args.namespace
            ? callMemory(["list", args.namespace])
            : callMemory(["list"]),
        )

      case "memory_read": {
        const path = join(WIKI_DIR, `${args.id}.md`)
        try {
          return ok(readFileSync(path, "utf8"))
        } catch {
          return err(`entry not found: ${args.id}`)
        }
      }

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

function callMemory(args) {
  return execFileSync(MEMORY_BIN, args, { encoding: "utf8" })
}

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
