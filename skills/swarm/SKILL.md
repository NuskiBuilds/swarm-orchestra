---
name: swarm
description: This skill should be used when the user asks to "create a swarm", "launch a team", "spin up agents", "use teammates", "run agents in parallel", "implement these in parallel", "research competing approaches", "run a parallel audit", or "split this work across agents". Covers the full lifecycle from team creation through task assignment, teammate management, result collection, and cleanup.
version: "2.0.0"
---

# Swarm Lifecycle

Manage the full lifecycle of a Claude Code agent team: plan, create, task, spawn, manage, collect, shutdown, cleanup.

> **Stop.** Do NOT create a team, spawn agents, or call TeamCreate until you have:
> 1. Understood what the task is
> 2. Proposed a team structure (agent count, model, roles)
> 3. Received explicit user approval
>
> Spawning first and thinking later wastes tokens and causes chaos.

## Planning Phase

This phase has two separate steps. Do NOT combine them.

### Step 1: Gather Input

Use **separate `AskUserQuestion` calls** to understand the task. Each call asks about ONE thing, and each answer informs the next question. Do NOT combine multiple concerns into a single call. Use as many rounds as needed — a simple task might need 2, a massive codebase or complex plan might need 4-5 for precision.

**What** — What's the goal? What are we parallelizing? Adapt your language to the user's domain.

**How to Slice** — Based on what you now know, how should the work be divided? Propose the axis:
- By domain or topic area
- By hypothesis or perspective
- By task or deliverable
- By layer or concern
- By any other natural boundary

The right axis depends on the task. A code audit slices by module. A research project slices by question or source. A feature build slices by feature. You figure it out. **Do NOT bake agent counts into the slice options** — "By layer" is a slicing choice, "By layer (3 agents)" pre-decides scale. Keep them separate.

**Depth, priorities, constraints, or anything else** — If the task is large or ambiguous, keep asking. Clarify scope boundaries, priority ordering, depth expectations, output format, or anything that would change how you structure the team. Each answer shapes the next question. Stop asking when you have enough to write a confident proposal.

**Scale** is determined by YOU in Step 2 based on the chosen axis. **Bias toward fewer agents — propose the minimum that covers the work, not the maximum that could.** When uncertain, start with 2-3. The user adjusts in the proposal step.

Model guidance (use in Step 2, not in AskUserQuestion):
- **opus** — complex reasoning, deep analysis, nuanced judgment
- **sonnet** — implementation, straightforward analysis, most tasks
- **haiku** — quick lookups, simple checks, lowest cost

The `model` parameter passed at spawn time **overrides** both `CLAUDE_CODE_SUBAGENT_MODEL` and the agent definition's `model` frontmatter. This means you can use a specialized `subagent_type` (e.g., `frontend-ui-specialist` with `model: sonnet` in its frontmatter) but spawn it at `model: "opus"` for complex tasks — the spawn-time model wins. The agent keeps its specialized system prompt and tools; only the model changes.

**AskUserQuestion rules:**
- One concern per call. Each answer shapes the next question.
- Adapt options to the user's domain — don't force code terminology on a researcher
- Use `markdown` previews on options when it helps compare approaches (show what each axis covers, NOT how many agents)
- Check `annotations` (user notes) after they respond — notes can override anything: the approach, agent count, model, scope. **Notes always win over the selected option.**
- Always go through multiple rounds — even when the task seems specific. A user saying "audit these 4 modules" still benefits from confirming the slicing axis and verifying assumptions before you propose. Over-verify, never skip.

### Step 2: Propose and Wait

**This is a separate step. Do NOT embed the proposal inside AskUserQuestion.**

After gathering input, present the proposal as plain text in your response:

```
Agents:  N — model
Roles:
  - name: what it owns
  - name: what it owns

Shall I proceed?
```

Wait for the user to explicitly confirm before calling TeamCreate. The proposal is their chance to adjust roles, rename agents, change the model, add or remove agents. Do not skip this step.

## The Lifecycle

### 1. Create Team

```
TeamCreate({ team_name: "descriptive-name", description: "What the team is doing" })
```

### 2. Create Tasks

One task per unit of work, created before spawning teammates:

```
TaskCreate({ subject: "Task title", description: "Details...", activeForm: "Working on X" })
```

### 3. Pre-Swarm Research (when needed)

For tasks where agents will **make changes** to code they don't fully understand, consider spawning a single **research agent before spawning the implementation teammates**. Its job: read the components, APIs, or domain each agent will touch and return a context doc that gets included in their prompts.

Without this: agents make assumptions, produce wrong fixes, and you spend a turn on revisions.
With this: agents understand what they're changing before they change it.

**When to do it:** Implementation tasks (fixing, refactoring, auditing) with >=3 agents working on unfamiliar domains. Skip for pure research/analysis swarms where agents are only reading and summarizing.

### 4. Spawn Teammates

Spawn **ALL** teammates in a **single message** with multiple Agent tool calls.
User keystrokes during spawning corrupt prompts.

Each teammate needs: `name`, `team_name`, `subagent_type`, `model`, `prompt`, `description`.
For `subagent_type`: check if the project has custom agents in `.claude/agents/` — they carry domain knowledge. Otherwise use `general-purpose`.

**Working directory:** Agents MUST spawn in the orchestrator's current working directory. NEVER cd into a subdirectory or specify a child folder. Agents access files using full paths from the project root.

**`mode`:** ALWAYS set `mode: "auto"` on every Agent() call. Without this, each agent prompts the user for every file read/write — with multiple agents running, this is unusable.

**Tell the user not to type until all agents confirm spawned.**

Each teammate prompt follows this pattern:

```
"You are [agent-name]. Use /teammate for your operating protocol.
 Your task: [specific instructions, include pre-swarm research if applicable]"
```

The `/teammate` skill handles delegation rules, peer communication, and interrupt handling automatically. Do not manually include these blocks in the prompt.

If using the mailbox system, register agents before spawning:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm-register.sh <name> <team>
```

Chain all register calls with `&&` in a single Bash command.
See `references/mailbox-setup.md` for full setup and usage.

### 5. Manage

- **Idle is normal.** Teammates go idle after every turn. Send a message to wake them.
- **Collect results.** Teammates report via SendMessage. Track which have reported.
- **Nudge stragglers.** If a teammate goes idle without reporting, send explicit instructions.
- **Mid-turn corrections:** If you need to course-correct an agent while it's actively working, use the mailbox system — standard SendMessage only delivers at turn boundaries. See `references/mailbox-setup.md` for usage.

### 6. Shutdown and Cleanup

TeamDelete is unreliable. Follow this procedure:

1. Send `shutdown_request` to all teammates, wait for confirmations
2. Call `TeamDelete()`
3. If TeamDelete fails (active members error), force-clean:
   ```bash
   rm -rf ~/.claude/teams/{team-name} ~/.claude/tasks/{team-name}
   ```
4. Call `TeamDelete()` again to clear session state
5. Verify: `ls ~/.claude/teams/` — no stale entries

## Pitfalls

- **Keystroke injection:** Spawn all agents in one message. User typing mid-spawn corrupts prompts.
- **Context exhaustion:** Teammates reading too many files themselves. The `/teammate` skill includes delegation rules to prevent this — they should spawn child subagents for investigation.
- **Explore subagents:** Read-only — no edit, write, or bash. Fine for searching, not for implementation.
- **TeamDelete failures:** Always follow the cleanup procedure in step 6 above.
- **Too many files per agent:** For implementation tasks, more files = more assumptions = more wrong changes. The fix is not a bigger team — it's ensuring each teammate is spawning child subagents for investigation rather than reading everything itself.
- **Agents confirming success without running tests:** For fix/refactor tasks, require agents to run the relevant tests before reporting complete.

## Reference Files

- **`references/mailbox-setup.md`** — Mailbox setup, agent registration, sending interrupts, and technical notes.
