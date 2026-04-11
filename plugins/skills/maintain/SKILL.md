---
name: maintain
description: Memory maintenance trigger. Invoke this when the user asks to "run memory maintenance", "maintain memory", "process session transcripts", "update the wiki from recent sessions", or similar — AND when the scheduled hourly cron fires. Both paths converge here. Your job as the agent handling the trigger is to SPAWN A BACKGROUND SUBAGENT that does the actual work; you do NOT do maintenance work in the current session. The subagent walks session transcripts from Claude Code, Codex, and OpenCode, extracts knowledge into the wiki at ~/.memory/wiki/, and runs semantic maintenance passes. Spawn it, then return to whatever the user was doing.
---

# Memory maintenance dispatcher

When this skill is invoked — either because the user asked for maintenance, or because the hourly cron fired a prompt — **you are the dispatcher, not the executor**. Your only job is to spawn a background subagent and return immediately. Do not read transcripts, do not touch the wiki, do not do any maintenance work yourself in this session.

## What to do

Use the Agent tool to spawn a background subagent with these exact parameters:

```
Agent({
  description: "Memory maintenance",
  model: "sonnet",
  run_in_background: true,
  prompt: "You are the memory maintenance subagent. Your working context is the memory maintenance skill at ~/.claude/plugins/memory/skills/maintain/. Read ~/.claude/plugins/memory/skills/maintain/references/workflow.md and follow the runbook exactly. All scripts it references are at ~/.claude/plugins/memory/skills/maintain/scripts/. Work silently and print only a final summary when done."
})
```

(If the skill isn't installed at the Claude Code path above — for example, on Codex or OpenCode — the subagent should instead Read the runbook at whatever path the skill is installed. The runbook file is always `references/workflow.md` inside the skill directory.)

Then return to whatever the user was doing. Do not wait for the subagent. Do not report its progress. The subagent prints its own summary when it finishes, which you'll see in the transcript later.

## Why the split

The main agent (you, right now) must not do maintenance work in the current session because:

- It would clutter the user's conversation with dozens of tool calls
- It would consume the user's session context budget
- It would block the user's active work behind a batch operation

The subagent runs in isolation with a fresh context, sonnet model, and no interference. The same pattern is used for both the cron and manual triggers — one code path, consistent behavior.

## Rules

- **Do NOT read `references/workflow.md` yourself.** That file is for the subagent's runbook. If you read it, you'll start following the runbook in the main session, which is exactly what this skill is designed to prevent.
- **Do NOT run any of the scripts in `scripts/`.** Those are tools for the subagent's runbook, not for you.
- **Do NOT start processing transcripts.** That's the subagent's job.
- **Do spawn the subagent and return.** One tool call, then back to the user.

## If the user wants to see what maintenance does

If the user asks *why* you're spawning a subagent or what it will do, you can briefly explain the high-level flow (discover new transcripts → filter → extract knowledge into wiki → validate → optional semantic passes) without reading the runbook. The runbook has the details; the subagent will follow them.
