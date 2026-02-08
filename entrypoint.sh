#!/bin/bash
set -e

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"

echo "[entrypoint] OpenClaw entrypoint starting..."
echo "[entrypoint] Node version: $(node --version)"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace"

# Back up existing config (if any) and write a clean minimal config.
# The persistent volume may have stale/invalid keys from older versions.
if [ -f "$CONFIG" ]; then
  cp "$CONFIG" "$OCDIR/openclaw.json.bak" 2>/dev/null || true
  echo "[entrypoint] Backed up existing config to openclaw.json.bak"
fi

# Write a clean, minimal config matching OpenClaw 2026.2.x schema.
# This ensures no stale keys can crash the gateway.
node -e "
const fs = require('fs');

// Start with a minimal valid config
const cfg = {
  gateway: {
    bind: 'lan',
    port: 18789
  },
  env: {
    vars: {}
  }
};

// Inject API keys from environment
if (process.env.ANTHROPIC_API_KEY) {
  cfg.env.vars.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  console.log('[entrypoint] Set ANTHROPIC_API_KEY in env.vars');
}
if (process.env.OPENROUTER_API_KEY) {
  cfg.env.vars.OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
  console.log('[entrypoint] Set OPENROUTER_API_KEY in env.vars');
}

// Try to preserve safe fields from existing config backup
try {
  const old = JSON.parse(fs.readFileSync('$OCDIR/openclaw.json.bak', 'utf8'));

  // Preserve auth settings if they exist and look valid
  if (old.gateway && old.gateway.auth) {
    cfg.gateway.auth = old.gateway.auth;
    console.log('[entrypoint] Preserved gateway.auth from backup');
  }

  // Preserve agents if configured
  if (old.agents) {
    cfg.agents = old.agents;
    console.log('[entrypoint] Preserved agents from backup');
  }

  // Preserve auth profiles
  if (old.auth) {
    cfg.auth = old.auth;
    console.log('[entrypoint] Preserved auth from backup');
  }
} catch(e) {
  console.log('[entrypoint] No valid backup to restore from, using fresh config');
}

fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\\n');
console.log('[entrypoint] Config written with keys:', Object.keys(cfg).join(', '));
"

# Auto-fix any invalid/deprecated config keys
echo "[entrypoint] Running openclaw doctor --fix ..."
node /app/openclaw.mjs doctor --fix 2>&1 || true
echo "[entrypoint] Doctor complete."

# Launch OpenClaw (official entrypoint)
echo "[entrypoint] Launching: node /app/openclaw.mjs $@"
exec node /app/openclaw.mjs "$@"
