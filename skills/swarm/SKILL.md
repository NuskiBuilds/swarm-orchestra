---
name: swarm
description: This skill should be used when the user asks to "create a swarm", "launch a team", "spin up agents", "use teammates", "run agents in parallel", "implement these in parallel", "research competing approaches", "run a parallel audit", or "split this work across agents". Covers the full lifecycle from team creation through task assignment, teammate management, result collection, and cleanup.
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

### 3. Spawn Teammates

Spawn **ALL** teammates in a **single message** with multiple Agent tool calls. User keystrokes during spawning corrupt prompts.

Each teammate needs: `name`, `team_name`, `subagent_type`, `model`, `prompt`, `description`.

For `subagent_type`: check if the project has custom agents in `.claude/agents/` — they carry domain knowledge. Otherwise use `general-purpose`.

**Tell the user not to type until all agents confirm spawned.**

**Every teammate prompt MUST include the delegation block** (see The Rule below). This is non-negotiable.

### 4. Manage

- **Idle is normal.** Teammates go idle after every turn. Send a message to wake them.
- **Collect results.** Teammates report via SendMessage. Track which have reported.
- **Nudge stragglers.** If a teammate goes idle without reporting, send explicit instructions.

### 5. Shutdown and Cleanup

TeamDelete is unreliable. Follow this procedure:

1. Send `shutdown_request` to all teammates, wait for confirmations
2. Call `TeamDelete()`
3. If TeamDelete fails (active members error), force-clean:
   ```bash
   rm -rf ~/.claude/teams/{team-name} ~/.claude/tasks/{team-name}
   ```
4. Call `TeamDelete()` again to clear session state
5. Verify: `ls ~/.claude/teams/` — no stale entries

## The Rule

**This is the single most important thing in this plugin.**

In plain language: each teammate can spawn their own helper agents to do research without cluttering their own context window. Reading many files yourself exhausts your context — spawn helpers to investigate and return only the findings you need.

Every teammate prompt MUST include this delegation block (adapt the wording but keep the rules):

```
### How to Work
When you need to investigate files, trace code paths, or research anything:
spawn helper agents instead of reading everything yourself. Reading many
files directly fills your context window — helpers investigate and return
only what matters.

Use the Agent tool WITHOUT the team_name parameter. This runs the helper
inside your own process and returns results directly to you.

Rule of thumb: if you need to read 3+ files for something, spawn a helper.

Use subagent_type="general-purpose" — these have full tool access
(Read, Write, Edit, Bash, Grep, Glob). Do NOT use subagent_type="Explore"
— those are read-only with no edit or reasoning tools.

NEVER create a new team or use TeamCreate. You are a teammate, not a leader.
```

**Why this exists:** Without it, teammates try to read everything themselves and exhaust their context, or worse — spawn new teammates instead of internal helpers. This creates exponential agent explosion (12-20+ agents from what should have been 3). The block prevents both failure modes.

### Teammate vs Child Subagent (Helper)

| | Teammate | Child Subagent (Helper) |
|---|---|---|
| Spawned with | Agent tool + `team_name` | Agent tool (no `team_name`) |
| Runs in | Own pane or in-process | Parent's process |
| Communication | `SendMessage` | Return value |
| Tools | Full access | Depends on `subagent_type` |
| Use for | Long-running parallel work | Investigation, research, deep dives |

**When to spawn a helper:** If you need to read 3+ files, trace a code path, search across modules, or do any investigation that would consume significant context — spawn a `general-purpose` helper and let it return a summary.

## Pitfalls

- **Keystroke injection:** Spawn all agents in one message. User typing mid-spawn corrupts prompts.
- **Context exhaustion:** Teammates reading too many files themselves. Delegation block fixes this — they should spawn child subagents for investigation.
- **Explore subagents:** Never use for deep work. They're read-only with no reasoning tools.
- **TeamDelete failures:** Always follow the cleanup procedure in step 5 above.
