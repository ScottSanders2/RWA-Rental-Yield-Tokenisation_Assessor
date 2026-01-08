#!/bin/bash
# Start Anvil with persistent state (Iteration 13+)
# --state: Save/load blockchain state from disk
# --state-interval: Auto-save every N seconds (must be non-zero, 1 = every second)
# --host: Bind to all interfaces (0.0.0.0) for Docker network access

# Use /home/foundry instead of /root (Anvil runs as 'foundry' user)
STATE_DIR="/home/foundry/.foundry/anvil"
mkdir -p "$STATE_DIR"
chmod 755 "$STATE_DIR"

anvil --host 0.0.0.0 --port 8546 --chain-id 31337 \
  --state "$STATE_DIR/state.json" \
  --state-interval 1 &
ANVIL_PID=$!

# Wait for Anvil process
wait $ANVIL_PID
