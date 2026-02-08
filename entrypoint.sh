#!/bin/bash

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace"

echo "[entrypoint] OpenClaw entrypoint starting..."
echo "[entrypoint] Node: $(node --version), User: $(whoami)"

# Clean stale config files from persistent volume that can crash the gateway.
# Only openclaw.json and workspace/ should persist between restarts.
echo "[entrypoint] Cleaning stale config files..."
for f in "$OCDIR"/auth-profiles.json "$OCDIR"/openclaw.json.bak "$OCDIR"/entrypoint.log; do
  if [ -f "$f" ]; then
    rm -f "$f" && echo "[entrypoint] Removed stale: $(basename $f)"
  fi
done

# List directory contents for debugging
echo "[entrypoint] Config dir:"
ls -la "$OCDIR/" 2>&1

# Write a clean, minimal config matching OpenClaw 2026.2.x schema.
# Gateway auth token is read from OPENCLAW_GATEWAY_TOKEN env var.
node -e "
const fs = require('fs');

const cfg = {
  gateway: {
    bind: 'lan',
    port: 18789,
    auth: {
      mode: 'token'
    }
  },
  env: {
    vars: {}
  }
};

// Set gateway auth token from environment
if (process.env.OPENCLAW_GATEWAY_TOKEN) {
  cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
  console.log('[entrypoint] Set gateway auth token');
} else {
  console.log('[entrypoint] WARNING: No OPENCLAW_GATEWAY_TOKEN set!');
}

// Inject API keys into env.vars
if (process.env.ANTHROPIC_API_KEY) {
  cfg.env.vars.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  console.log('[entrypoint] Set ANTHROPIC_API_KEY');
}
if (process.env.OPENROUTER_API_KEY) {
  cfg.env.vars.OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
  console.log('[entrypoint] Set OPENROUTER_API_KEY');
}

fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Config written successfully');
"

# Verify config was written
echo "[entrypoint] Config file check:"
ls -la "$CONFIG" 2>&1

# Launch OpenClaw gateway directly
echo "[entrypoint] Launching: node /app/openclaw.mjs $@"
exec node /app/openclaw.mjs "$@"
