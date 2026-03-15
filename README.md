# swarm-orchestra

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-v2.1.32+-blueviolet)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/version-2.0.0-green)](.claude-plugin/plugin.json)

**Structured orchestration for Claude Code agent teams.**

Turn "run these in parallel" into a coordinated swarm — with planning, delegation, inter-agent messaging, and cleanup that actually works. Built for anyone using Claude Code who wants parallel agents without the chaos.

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

Two skills handle everything automatically:

- **`/swarm`** — invoke it or just ask for parallel work. It plans the team structure, gets your approval, spawns agents, manages their lifecycle, and cleans up when done.
- **`/teammate`** — loads automatically on each spawned agent. It teaches them how to delegate work, talk to each other, and handle interrupts — without the orchestrator having to spell it all out.

The result: you describe the work, approve a plan, and agents coordinate autonomously.

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

## How It Works

### Planning

The orchestrator walks you through structured questions — one concern per round, each answer shaping the next:

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

You control the agent count, model choice, and scope. Nothing spawns without your approval.

### Teammate Self-Configuration

Each teammate loads the `/teammate` skill automatically on spawn. It gives them:

- **Delegation rules** — spawn lightweight helper agents for research instead of reading everything themselves (prevents context exhaustion)
- **Peer messaging** — discover other teammates and send them findings mid-task via the mailbox system
- **Interrupt handling** — receive and respond to urgent messages from peers or the orchestrator

No prompt engineering required. The orchestrator just says *"Use /teammate for your operating protocol"* and the agent configures itself.

### Inter-Agent Messaging

By default, Claude Code messages only deliver between turns — after an agent finishes working. That's useless for mid-task coordination.

The **mailbox system** fixes this. A `PreToolUse` hook checks for messages before every tool call. When one is waiting, the tool is blocked and the message is injected as mandatory feedback. The agent handles it immediately, then resumes.

This works in all directions:
- **Orchestrator → teammate** — course-correct an agent mid-task
- **Teammate → teammate** — share findings directly with the agent who needs them
- **Idle detection** — if a peer has gone idle, the script tells the sender how to wake them

Teammates discover each other and exchange messages autonomously. No manual routing needed.

## Display Modes

**In-process (default):** Single terminal pane, cycle between teammates with `Shift+Down`.

**Grid (optional):** Install [tmux](https://github.com/tmux/tmux/wiki/Installing) and add `"teammateMode": "tmux"` to settings for side-by-side view.

## Lessons Learned (the hard way)

1. **Delegation rules are non-negotiable.** Nested teams CAN happen — the docs say they can't, but they do. The `/teammate` skill enforces this automatically.
2. **Spawn all agents in ONE message.** Keystrokes during spawning corrupt prompts.
3. **Start with fewer agents.** 2-3 is often enough. Scale up, not down.
4. **Explore subagents are read-only.** Fine for searching, but they can't edit, write, or run bash.
5. **TeamDelete is unreliable.** The plugin includes a force-clean fallback.
6. **Opus for depth, sonnet for execution.** Match the model to the task.
7. **Pre-swarm research pays off.** For implementation swarms, spawn a research agent first. Agents making changes without understanding the codebase produce wrong fixes.

## Project Structure

```
swarm-orchestra/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── swarm/
│   │   ├── SKILL.md          ← orchestration skill
│   │   └── references/
│   │       └── mailbox-setup.md
│   └── teammate/
│       ├── SKILL.md          ← teammate self-configuration
│       └── references/
│           └── mailbox-comms.md
├── hooks/
│   └── mailbox-check.sh      ← PreToolUse hook for mid-turn messaging
├── scripts/
│   ├── swarm-register.sh     ← register agent before spawning
│   ├── swarm-send.sh         ← send message to running agent
│   ├── swarm-status.sh       ← show active agents + pending messages
│   └── swarm-cleanup.sh      ← tear down swarm state
├── README.md
└── LICENSE
```

## Contributing

Found a new pattern or pitfall? PRs welcome.

## Note

TeamCreate is an experimental Claude Code feature. This plugin encodes hard-won patterns for using it effectively, but the underlying API may change.

## License

MIT
