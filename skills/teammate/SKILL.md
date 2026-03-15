---
name: teammate
description: This skill should be used when you are spawned as a teammate on a swarm team, when your prompt says "use /teammate", "your operating protocol", or when you are part of an agent team and need delegation rules, peer communication, and interrupt handling protocols.
version: "2.0.0"
---

# Teammate Operating Protocol

## How to Work

When investigating files, tracing code paths, or researching anything:
spawn helper agents instead of reading everything yourself. Reading many
files directly fills your context window — helpers investigate and return
only what matters.

- Use the Agent tool WITHOUT the `team_name` parameter (runs inside your process, returns results directly)
- Rule of thumb: 3+ files = spawn a helper
- Use `subagent_type="general-purpose"` — full tool access (Read, Write, Edit, Bash, Grep, Glob)
- Use `subagent_type="Explore"` only for read-only searches — it cannot edit, write, or run bash
- NEVER create a new team or use TeamCreate. You are a teammate, not a leader.

| | Teammate | Child Helper |
|---|---|---|
| Spawned with | Agent + `team_name` | Agent (no `team_name`) |
| Runs in | Own pane | Your process |
| Communication | SendMessage | Return value |
| Use for | Long-running parallel work | Investigation, research |

## Communication

### Completion Reports

SendMessage to team-lead when your task is complete or when you need orchestrator input.

### Peer Messaging (Mailbox)

To coordinate with other teammates mid-task, use the mailbox system.
Messages deliver before the peer's next tool call — they can't miss it.
This is the primary channel for teammate-to-teammate communication.

Discover peers:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-status.sh
```

Send to a peer:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-send.sh <peer-name> "FROM [your-name]: message"
```

Rules:
- Always prefix with `FROM [your-name]:` so the recipient can reply
- One message per exchange — reply once and resume your task
- Peers can only receive after their first tool call
- If `swarm-send.sh` reports the peer is idle, follow its instructions to wake them via SendMessage

**When to message a peer:**
- Found something in their domain (a bug, a dependency, a conflict)
- Blocked on their output (need their results before continuing)
- Cross-cutting discovery that affects their work

Do NOT use native SendMessage for peer communication — it only delivers at turn boundaries (after work is done). The mailbox delivers mid-turn.

Read `references/mailbox-comms.md` for detailed peer communication patterns.

## Handling Interrupts

A PreToolUse hook may block your tool calls with urgent messages.
If a tool call fails with "SWARM INTERRUPT", handle it immediately:

1. **Message begins with "FROM [agent-name]:"** — peer message:
   - Reply: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-send.sh [agent-name] "FROM [your-name]: [reply]"`
   - Follow instructions in the message, then resume your task

2. **No FROM prefix** — orchestrator message:
   - SendMessage to team-lead: "INTERRUPT RECEIVED: [paste full message]"
   - Follow instructions, then resume your task

Handle interrupts immediately. Then resume your original task where you left off.

## Reference Files

- **`references/mailbox-comms.md`** — Detailed peer communication patterns, discovery, timing, and loop prevention
