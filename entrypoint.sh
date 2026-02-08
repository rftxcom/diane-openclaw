#!/bin/bash

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace"

echo "[entrypoint] OpenClaw entrypoint starting..."

# Write a clean, minimal config matching OpenClaw 2026.2.x schema.
# Gateway auth token is read from OPENCLAW_GATEWAY_TOKEN env var
# (set in the docker-compose environment section).
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
console.log('[entrypoint] Config written');
"

# Launch OpenClaw gateway directly
echo "[entrypoint] Launching gateway..."
exec node /app/openclaw.mjs "$@"
