#!/bin/bash
# Start Anvil on a different port
anvil --port 8546 --chain-id 31337 &
ANVIL_PID=$!

# Wait a moment for Anvil to start
sleep 2

# Start socat to forward from 0.0.0.0:8545 to localhost:8546
socat TCP-LISTEN:8545,fork,reuseaddr TCP:localhost:8546 &

SOCAT_PID=$!

# Wait for Anvil process
wait $ANVIL_PID
