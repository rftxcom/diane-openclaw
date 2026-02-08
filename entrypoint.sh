#!/bin/bash

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"
LOGFILE="$OCDIR/entrypoint.log"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace"

# Tee all output to persistent log file for debugging
exec > >(tee -a "$LOGFILE") 2>&1

echo ""
echo "=========================================="
echo "[entrypoint] Starting at $(date -u)"
echo "=========================================="
echo "[entrypoint] Node version: $(node --version)"
echo "[entrypoint] Args: $@"
echo "[entrypoint] PWD: $(pwd)"
echo "[entrypoint] User: $(whoami)"

# List what's in the config directory
echo "[entrypoint] Config directory contents:"
ls -la "$OCDIR/" 2>&1 || true

# Show existing config if any
if [ -f "$CONFIG" ]; then
  echo "[entrypoint] Existing config (first 500 chars):"
  head -c 500 "$CONFIG" 2>&1 || true
  echo ""
  # Back up
  cp "$CONFIG" "$OCDIR/openclaw.json.bak" 2>/dev/null || true
  echo "[entrypoint] Backed up existing config"
else
  echo "[entrypoint] No existing config file"
fi

# Write a clean, minimal config matching OpenClaw 2026.2.x schema.
echo "[entrypoint] Writing fresh config..."
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
console.log('[entrypoint] Fresh config written');
console.log('[entrypoint] Config:', JSON.stringify(cfg, null, 2));
" || {
  echo "[entrypoint] ERROR: Failed to write config!"
  exit 1
}

# Auto-fix any invalid/deprecated config keys
echo "[entrypoint] Running openclaw doctor --fix ..."
node /app/openclaw.mjs doctor --fix 2>&1 || echo "[entrypoint] WARNING: doctor --fix returned non-zero"
echo "[entrypoint] Doctor complete."

# Show what doctor left us with
echo "[entrypoint] Config after doctor:"
cat "$CONFIG" 2>&1 || true

# Verify openclaw.mjs exists and is executable
echo "[entrypoint] Checking openclaw.mjs:"
ls -la /app/openclaw.mjs 2>&1 || echo "[entrypoint] ERROR: openclaw.mjs not found!"

# Launch OpenClaw
echo "[entrypoint] Launching: node /app/openclaw.mjs $@"
echo "=========================================="
exec node /app/openclaw.mjs "$@"
