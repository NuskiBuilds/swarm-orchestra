# Mailbox System: Setup and Usage (Orchestrator)

The mailbox system enables mid-turn message delivery to running agents. A global `PreToolUse` hook checks for messages before every tool call. When one is waiting, the tool is **blocked** and the message is injected as mandatory feedback.

## Setup (one-time)

Add to `~/.claude/settings.json` under `hooks.PreToolUse` (no matcher — fires on all tools):

```json
{ "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/mailbox-check.sh" }] }
```

> **Debug logging:** Set `SWARM_DEBUG=1` in the environment or `settings.json` env block to write hook activity to `/tmp/swarm-hook-debug.log`.

## Register Agents

Before spawning each teammate, register them:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-register.sh <agent-name> <team-name>
```

This creates a pending slot. The agent's first tool call claims it, binding their `session_id` to their name. **Chain all register calls into a single Bash command** (joined with `&&`) to minimize permission prompts.

## Send a Message (Interrupt)

To interrupt a running agent:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-send.sh <agent-name> "Urgent message here"
```

The message is delivered before their next tool call — blocking it until they handle it.

## Check Status

To see registered agents and pending messages:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-status.sh
```

## Cleanup

After the swarm completes, clean up mailbox state:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-cleanup.sh --force
```

## Technical Notes

- **Identity:** Hook uses `session_id` from the hook JSON payload — no collisions between orchestrator and teammates sharing the same working directory
- **Message storage:** Messages are written to `~/.claude/swarm/mailbox/{session_id}.msg` and consumed atomically (mv before read)
- **Hook output:** Hook writes interrupt content to **stderr** (not stdout) — exit code 2 with stderr is what gets injected into the model's context
- **Orchestrator exclusion:** `swarm-register.sh` creates a `.register-orchestrator` marker; the orchestrator's first hook fire claims it and writes `orchestrator.session`, which the hook skips forever after
- **Debug:** `SWARM_DEBUG=1` enables activity logging to `/tmp/swarm-hook-debug.log`
