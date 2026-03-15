# Peer Communication Patterns

Detailed guide for teammate-to-teammate messaging via the mailbox system.

## How It Works

The mailbox system uses a `PreToolUse` hook that checks for pending messages before every tool call. When a message is waiting, your tool call is **blocked** and the message content is injected as mandatory feedback. Handle it, then your next tool call proceeds normally.

This is mid-turn delivery — the message arrives while the peer is actively working, not after they finish.

## Discovering Peers

To see all registered agents and any pending messages:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-status.sh
```

This shows every agent on the swarm, their registration status, and whether they have unread messages.

## Sending Messages

To send a message to another teammate:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-send.sh <peer-name> "FROM [your-name]: message"
```

The message queues for delivery before their next tool call. They cannot miss it — the hook blocks their tool until they handle it.

## The FROM Convention

Always prefix messages with `FROM [your-name]:` so the recipient knows who sent it and can reply. Without this prefix, the recipient has no way to respond.

**Good:** `"FROM auth-fixer: Found a race condition in login.js line 42 — this affects your session work"`

**Bad:** `"There's a race condition in login.js"` — recipient can't reply

## When to Message a Peer

Message a peer when:
- **Found something in their domain** — a bug, dependency, or conflict that affects their assigned work
- **Blocked on their output** — you need their results before you can continue
- **Cross-cutting discovery** — something that changes the approach for multiple agents

Do NOT message a peer for:
- General status updates (use SendMessage to team-lead instead)
- Questions the orchestrator should answer
- Anything that can wait until both agents finish

## Loop Prevention

Peer messaging is for **handoffs**, not conversations.

- Send one message per topic
- If you receive a peer message: reply once, then resume your task
- Do NOT go back and forth — two agents exchanging messages queue faster than they can process them
- If a topic needs extended discussion, escalate to the orchestrator via SendMessage to team-lead

## Timing

A peer can only receive messages after their first tool call. This is when their `session_id` binds to their registered name. Sending before that returns a clear error from `swarm-send.sh`.

In practice this means: if agents are spawned simultaneously, each agent's first tool call registers them. By the time any agent has meaningful findings to share, all peers will be registered.

## Idle Peers

`swarm-send.sh` tracks peer activity via heartbeats. If the peer has been idle for more than 15 seconds, the script tells you:

```
Message queued for 'api-mapper' — but peer has been idle for 45s.
To wake them: SendMessage to api-mapper with message 'You have a mailbox message — check it now'
```

Follow the instruction — send a native `SendMessage` to wake the peer. Once they wake up and make a tool call, the hook delivers your queued mailbox message automatically. If the peer is active, the message delivers on their next tool call with no extra action needed.

## Mailbox vs Native SendMessage

| Channel | Delivery | Use for |
|---------|----------|---------|
| Mailbox (`swarm-send.sh`) | Mid-turn (before next tool call) | All peer communication |
| SendMessage to team-lead | Turn boundary | Completion reports only |
| Native SendMessage peer-to-peer | Turn boundary | Don't use — arrives after work is done |

The mailbox is the only reliable way to coordinate with peers during active work.
