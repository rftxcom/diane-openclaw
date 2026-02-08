#!/bin/bash

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace"

echo "[entrypoint] OpenClaw entrypoint starting..."

# Write a clean, minimal config matching OpenClaw 2026.2.x schema.
node -e "
const fs = require('fs');

const cfg = {
  gateway: {
    bind: 'lan',
    port: 18789
  },
  env: {
    vars: {}
  }
};

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

# Skip 'openclaw doctor --fix' — it hangs indefinitely and blocks startup.

# Launch OpenClaw gateway directly
echo "[entrypoint] Launching gateway..."
exec node /app/openclaw.mjs "$@"
