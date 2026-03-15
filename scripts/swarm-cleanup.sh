#!/usr/bin/env bash
# swarm-orchestra: Clean up swarm state (registry + mailbox)
# Usage: swarm-cleanup.sh [--force]
#
# Called during team shutdown. Removes registry and pending messages.

set -euo pipefail

SWARM_DIR="$HOME/.claude/swarm"

if [ ! -d "$SWARM_DIR" ]; then
  echo "No swarm state to clean up"
  exit 0
fi

if [ "${1:-}" != "--force" ]; then
  # Show what would be cleaned
  echo "Will remove:"
  [ -d "$SWARM_DIR/registry" ] && echo "  registry/ ($(ls "$SWARM_DIR/registry" 2>/dev/null | wc -l) agents)"
  PENDING=$(find "$SWARM_DIR/mailbox" -name "*.msg" 2>/dev/null | wc -l)
  [ "$PENDING" -gt 0 ] && echo "  $PENDING pending message(s)"
  [ -d "$SWARM_DIR/sessions" ] && echo "  sessions/ ($(ls "$SWARM_DIR/sessions" 2>/dev/null | wc -l) entries)"
  [ -d "$SWARM_DIR/pending" ] && echo "  pending/ ($(ls "$SWARM_DIR/pending" 2>/dev/null | wc -l) entries)"
  echo ""
  echo "Run with --force to confirm"
  exit 0
fi

rm -rf "$SWARM_DIR/mailbox" "$SWARM_DIR/sessions" "$SWARM_DIR/pending" \
       "$SWARM_DIR/registry" "$SWARM_DIR/heartbeat" \
       "$SWARM_DIR/orchestrator.session" \
       "$SWARM_DIR/.register-orchestrator" "$SWARM_DIR/.register-orchestrator.claiming"
echo "Swarm state cleaned up"
