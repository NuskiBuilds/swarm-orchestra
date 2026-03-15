#!/usr/bin/env bash
# swarm-orchestra: Send a message to a swarm agent
# Usage: swarm-send.sh <agent-name> <message>
#    or: swarm-send.sh <agent-name> -  (reads message from stdin)
#
# Message is keyed by session_id — no cwd collision between orchestrator and teammate.
# Delivery happens via PreToolUse hook — blocks the agent's next tool call until handled.

set -euo pipefail

SWARM_DIR="$HOME/.claude/swarm"
MAILBOX_DIR="$SWARM_DIR/mailbox"

if [ $# -lt 2 ]; then
  echo "Usage: swarm-send.sh <agent-name> <message|->"
  echo "  Use '-' to read message from stdin"
  exit 1
fi

AGENT_NAME="$1"
shift

if [ "$1" = "-" ]; then
  MESSAGE=$(cat)
else
  MESSAGE="$*"
fi

# Look up session_id from per-agent registry file
SESSION_ID=""
REGISTRY_FILE="$SWARM_DIR/registry/$AGENT_NAME"
if [ -f "$REGISTRY_FILE" ]; then
  SESSION_ID=$(sed -n '2p' "$REGISTRY_FILE")
fi

if [ -z "$SESSION_ID" ]; then
  echo "Error: agent '$AGENT_NAME' not yet registered (session_id unknown)."
  echo "The agent must make at least one tool call before it can receive messages."
  echo "Known agents:"
  if [ -d "$SWARM_DIR/registry" ]; then
    for f in "$SWARM_DIR/registry"/*; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      sid=$(sed -n '2p' "$f")
      echo "  $name: session_id=${sid:-pending}"
    done
  fi
  exit 1
fi

# Write message atomically, keyed by session_id
mkdir -p "$MAILBOX_DIR"
MAILBOX_FILE="$MAILBOX_DIR/$SESSION_ID.msg"
TEMP_MSG=$(mktemp "$MAILBOX_DIR/.tmp.XXXXXX")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Append if message already pending
if [ -f "$MAILBOX_FILE" ]; then
  cat "$MAILBOX_FILE" >> "$TEMP_MSG" 2>/dev/null || true
  printf '\n---\n' >> "$TEMP_MSG"
fi

printf '[%s] %s' "$TIMESTAMP" "$MESSAGE" >> "$TEMP_MSG"
mv "$TEMP_MSG" "$MAILBOX_FILE"

# Check heartbeat to determine if peer is active or idle
IDLE_THRESHOLD=15  # seconds
HEARTBEAT_FILE="$SWARM_DIR/heartbeat/$AGENT_NAME"
if [ -f "$HEARTBEAT_FILE" ]; then
  LAST_BEAT=$(cat "$HEARTBEAT_FILE")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_BEAT))
  if [ "$DIFF" -gt "$IDLE_THRESHOLD" ]; then
    echo "Message queued for '$AGENT_NAME' (session ${SESSION_ID:0:8}...) — but peer has been idle for ${DIFF}s."
    echo "To wake them: SendMessage to $AGENT_NAME with message 'You have a mailbox message — check it now'"
  else
    echo "Message queued for '$AGENT_NAME' (session ${SESSION_ID:0:8}...) — will be delivered on next tool call"
  fi
else
  echo "Message queued for '$AGENT_NAME' (session ${SESSION_ID:0:8}...) — will be delivered on next tool call"
fi
