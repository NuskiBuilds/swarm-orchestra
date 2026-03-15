#!/usr/bin/env bash
# swarm-orchestra: Register an agent in the swarm registry
# Usage: swarm-register.sh <agent-name> [team-name]
#
# Called by the orchestrator BEFORE spawning each teammate.
# Creates a "pending" slot — the teammate's first tool call claims it via the hook,
# binding session_id → agent_name. No cwd needed, no collision with orchestrator.

set -euo pipefail

SWARM_DIR="$HOME/.claude/swarm"

if [ $# -lt 1 ]; then
  echo "Usage: swarm-register.sh <agent-name> [team-name]"
  exit 1
fi

AGENT_NAME="$1"
TEAM_NAME="${2:-default}"

mkdir -p "$SWARM_DIR/mailbox" "$SWARM_DIR/sessions" "$SWARM_DIR/pending" "$SWARM_DIR/registry"

# Create per-agent registry entry (session_id filled in later by hook self-registration)
printf '%s\n%s\n' "$TEAM_NAME" "" > "$SWARM_DIR/registry/$AGENT_NAME"
# Line 1 = team name, Line 2 = session_id (empty until hook claims it)

# Write pending slot — hook claims this on first fire from the teammate's session
echo "$AGENT_NAME" > "$SWARM_DIR/pending/$AGENT_NAME.pending"

# Ensure orchestrator is registered on its next tool call (skipped if already registered)
if [ ! -f "$SWARM_DIR/orchestrator.session" ]; then
  touch "$SWARM_DIR/.register-orchestrator"
fi

echo "Pending slot created for '$AGENT_NAME' (team: $TEAM_NAME) — will bind on first teammate tool call"
