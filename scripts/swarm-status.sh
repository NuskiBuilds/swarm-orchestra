#!/usr/bin/env bash
# swarm-orchestra: Show swarm status — registered agents and pending messages
# Usage: swarm-status.sh

set -euo pipefail

SWARM_DIR="$HOME/.claude/swarm"

echo "=== Swarm Status ==="
echo ""

# Registry (per-agent files)
if [ -d "$SWARM_DIR/registry" ]; then
  AGENT_COUNT=0
  for f in "$SWARM_DIR/registry"/*; do
    [ -f "$f" ] || continue
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done
  echo "Registered agents: $AGENT_COUNT"
  for f in "$SWARM_DIR/registry"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    team=$(head -1 "$f")
    sid=$(sed -n '2p' "$f")
    echo "  $name → session=${sid:-pending} [$team]"
  done
else
  echo "No registry found (no swarm active)"
fi

echo ""

# Mailbox
if [ -d "$SWARM_DIR/mailbox" ]; then
  PENDING=$(find "$SWARM_DIR/mailbox" -name "*.msg" 2>/dev/null | wc -l)
  echo "Pending messages: $PENDING"
  while IFS= read -r -d '' msg_file; do
    SID=$(basename "$msg_file" .msg)
    # Reverse lookup: find agent name from session_id
    AGENT_DISPLAY="$SID"
    if [ -d "$SWARM_DIR/sessions" ] && [ -f "$SWARM_DIR/sessions/$SID" ]; then
      AGENT_DISPLAY=$(cat "$SWARM_DIR/sessions/$SID")
    fi
    LINES=$(wc -l < "$msg_file")
    echo "  $AGENT_DISPLAY: $LINES line(s) waiting"
  done < <(find "$SWARM_DIR/mailbox" -name "*.msg" -print0 2>/dev/null)
else
  echo "No mailbox directory"
fi
