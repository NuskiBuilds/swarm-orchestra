# swarm-orchestra

**Structured orchestration for Claude Code agent teams.**

Turn "run these in parallel" into a coordinated swarm — with planning, delegation, and cleanup that actually works.

> TeamCreate is an experimental Claude Code feature. This plugin encodes hard-won patterns for using it effectively, but the underlying API may change.

---

## Why This Exists

Claude Code's agent teams are genuinely powerful. Multiple agents, each with fresh context, communicating with each other, following tasks delegated by the main Claude — when it works, it's beautiful.

The problem? Getting there is painful. TeamCreate is experimental and Claude struggles to invoke it correctly. You can say "create a swarm", "use teammates", "spin up agents" — doesn't matter how you word it, it takes multiple attempts to get the structure right. And when it finally does spawn agents, without guardrails you get:

- Teammates spawning new teammates, which spawn more teammates — **20+ runaway agents**
- Context exhausted from reading too many files
- No structured planning — Claude just guesses the team structure
- Cleanup failing silently, leaving stale team state

This plugin makes it work on the first try.

## What It Does

One skill fires automatically when you ask for parallel work. It:

1. **Plans** — walks you through multiple rounds of questions to understand the task, how to slice it, and what depth you need
2. **Proposes** — presents a team structure for your explicit approval before anything spawns
3. **Executes** — creates team, tasks, and teammates with proper delegation rules
4. **Prevents explosion** — every teammate prompt includes a mandatory delegation block that stops runaway spawning
5. **Cleans up** — handles shutdown with a force-clean fallback for when TeamDelete inevitably fails

Works for any parallel task — code audits, feature builds, research synthesis, debugging investigations, competitive analysis, or anything that benefits from multiple agents.

## Quick Start

### 1. Enable agent teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or just ask Claude: *"enable agent teams in my settings"*

### 2. Install

```bash
# Add the marketplace (one-time)
claude plugin marketplace add NuskiBuilds/swarm-orchestra

# Install the plugin
claude plugin install swarm-orchestra
```

### 3. Use it

```
> create a swarm to audit the codebase
> run these 4 features in parallel
> split this research across agents
```

The skill triggers automatically. Claude asks questions, proposes a plan, you approve, agents spawn.

## How the Planning Works

The planning phase uses structured questions — one concern per round, each answer shaping the next:

```
Round 1:  What's the goal?                    → Code audit
Round 2:  What's the focus?                   → Security + auth
Round 3:  How should we slice it?             → By module
Round 4:  What should each agent check?       → [select concerns]

Proposal: 4 agents — opus
          - auth-auditor:     Login, JWT, sessions
          - api-auditor:      Routes, validation, CORS
          - data-auditor:     Models, migrations, queries
          - frontend-auditor: XSS, input handling, state

Shall I proceed?
```

A simple task might need 2 rounds. A massive codebase might need 5. Notes you add on any question can override the approach, agent count, or model choice.

## The #1 Rule

**Teammates must NOT spawn new teammates.** They spawn child subagents instead.

| | Teammate | Child Subagent |
|---|---|---|
| Spawned with | Agent tool + `team_name` | Agent tool (no `team_name`) |
| Runs in | Own pane / in-process | Parent's process |
| Communication | `SendMessage` | Return value |
| Use for | Long-running parallel work | Short investigation within a teammate |

Without this distinction, you get exponential agent explosion. The plugin includes a mandatory delegation block in every teammate prompt to prevent it.

## Display Modes

**In-process (default):** Single terminal pane, cycle between teammates with `Shift+Down`.

**Grid (optional):** Install [tmux](https://github.com/tmux/tmux/wiki/Installing) and add `"teammateMode": "tmux"` to settings for side-by-side view.

## Lessons Learned (the hard way)

1. **The delegation block is non-negotiable.** Nested teams CAN happen — the docs say they can't, but they do.
2. **Spawn all agents in ONE message.** Keystrokes during spawning corrupt prompts.
3. **Start with fewer agents.** 2-3 is often enough. Scale up, not down.
4. **Never use Explore subagents for deep work.** Read-only, no reasoning tools.
5. **TeamDelete is unreliable.** The plugin includes a force-clean fallback.
6. **Opus for depth, sonnet for execution.** Match the model to the task.

## Project Structure

```
swarm-orchestra/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── swarm/
│       └── SKILL.md          ← the entire plugin
├── README.md
└── LICENSE
```

## Contributing

Found a new pattern or pitfall? PRs welcome.

## License

MIT
