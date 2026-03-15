#!/usr/bin/env bash
# swarm-orchestra mailbox hook — PreToolUse, exit code 2 = hard interrupt
#
# Fires BEFORE each tool call. If a message is waiting in the mailbox,
# BLOCKS the tool and injects the message as mandatory feedback.
# Agent cannot continue until it processes the message.
#
# Exit codes:
#   0 = no message, tool proceeds normally
#   2 = message found, tool BLOCKED, stderr injected into model context as mandatory feedback

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

SWARM_DIR="$HOME/.claude/swarm"

# Fast exit — no swarm active
[ -d "$SWARM_DIR" ] || exit 0
[ -n "$SESSION_ID" ] || exit 0

# Debug log (opt-in: set SWARM_DEBUG=1 to enable)
if [ "${SWARM_DEBUG:-0}" = "1" ]; then
  echo "$(date -u +%H:%M:%S) PRE tool=$TOOL session=${SESSION_ID:0:8}" >> /tmp/swarm-hook-debug.log 2>/dev/null
fi

# Skip orchestrator session
ORCHESTRATOR_FILE="$SWARM_DIR/orchestrator.session"
if [ -f "$ORCHESTRATOR_FILE" ]; then
  ORCHESTRATOR_SESSION=$(cat "$ORCHESTRATOR_FILE")
  [ "$SESSION_ID" = "$ORCHESTRATOR_SESSION" ] && exit 0
fi

# Handle orchestrator init marker (first fire registers orchestrator)
INIT_MARKER="$SWARM_DIR/.register-orchestrator"
if [ -f "$INIT_MARKER" ]; then
  if mv "$INIT_MARKER" "$INIT_MARKER.claiming" 2>/dev/null; then
    echo "$SESSION_ID" > "$ORCHESTRATOR_FILE"
    rm -f "$INIT_MARKER.claiming"
    if [ "${SWARM_DEBUG:-0}" = "1" ]; then
      echo "$(date -u +%H:%M:%S) *** ORCHESTRATOR: ${SESSION_ID:0:8} ***" >> /tmp/swarm-hook-debug.log 2>/dev/null
    fi
  fi
  exit 0
fi

# Self-registration for new teammate sessions
SESSION_FILE="$SWARM_DIR/sessions/$SESSION_ID"
if [ ! -f "$SESSION_FILE" ]; then
  PENDING_DIR="$SWARM_DIR/pending"
  if [ -d "$PENDING_DIR" ]; then
    for pending_file in "$PENDING_DIR"/*.pending; do
      [ -f "$pending_file" ] || continue
      AGENT_NAME=$(cat "$pending_file" 2>/dev/null)
      [ -z "$AGENT_NAME" ] && continue
      if mv "$pending_file" "$pending_file.claiming" 2>/dev/null; then
        mkdir -p "$SWARM_DIR/sessions"
        echo "$AGENT_NAME" > "$SESSION_FILE"
        rm -f "$pending_file.claiming"
        # Write session_id to per-agent registry file (no shared JSON, no race)
        if [ -d "$SWARM_DIR/registry" ] && [ -f "$SWARM_DIR/registry/$AGENT_NAME" ]; then
          TEAM=$(head -1 "$SWARM_DIR/registry/$AGENT_NAME")
          printf '%s\n%s\n' "$TEAM" "$SESSION_ID" > "$SWARM_DIR/registry/$AGENT_NAME"
        fi
        if [ "${SWARM_DEBUG:-0}" = "1" ]; then
          echo "$(date -u +%H:%M:%S) *** REGISTERED ${SESSION_ID:0:8} as $AGENT_NAME ***" >> /tmp/swarm-hook-debug.log 2>/dev/null
        fi
        break
      fi
    done
  fi
fi

# Look up agent name
[ -f "$SESSION_FILE" ] || exit 0
AGENT_NAME=$(cat "$SESSION_FILE")
[ -z "$AGENT_NAME" ] && exit 0

# Write heartbeat — lets swarm-send.sh detect idle vs active peers
mkdir -p "$SWARM_DIR/heartbeat"
date +%s > "$SWARM_DIR/heartbeat/$AGENT_NAME"

# Check mailbox
MAILBOX_FILE="$SWARM_DIR/mailbox/$SESSION_ID.msg"
[ -f "$MAILBOX_FILE" ] || exit 0

# Consume message atomically — rename first to avoid race with concurrent swarm-send writes
CONSUMED=$(mktemp "$SWARM_DIR/mailbox/.consumed.XXXXXX")
if ! mv "$MAILBOX_FILE" "$CONSUMED" 2>/dev/null; then
  exit 0  # Another concurrent fire already consumed it
fi
MESSAGE=$(cat "$CONSUMED")
rm -f "$CONSUMED"

if [ "${SWARM_DEBUG:-0}" = "1" ]; then
  echo "$(date -u +%H:%M:%S) *** INTERRUPT ${SESSION_ID:0:8} ($AGENT_NAME) before $TOOL ***" >> /tmp/swarm-hook-debug.log 2>/dev/null
fi

# Exit code 2 = block the tool, inject message via stderr as mandatory feedback
# Agent MUST process this before it can make another tool call
echo "🚨 SWARM INTERRUPT — message for $AGENT_NAME (your $TOOL call has been held):" >&2
echo "" >&2
echo "$MESSAGE" >&2
echo "" >&2
echo "Handle this message before continuing your task." >&2
exit 2
