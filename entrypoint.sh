#!/bin/bash
set -e

CONFIG="/home/node/.openclaw/openclaw.json"

# Ensure config directory exists
mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace

# If no config exists at all, create a minimal one
if [ ! -f "$CONFIG" ]; then
  echo '{}' > "$CONFIG"
  echo "[entrypoint] Created empty openclaw.json"
fi

# Patch config for reverse proxy deployment behind Coolify/Traefik
node -e "
const fs = require('fs');
const cfgPath = '$CONFIG';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8')); } catch(e) {}

// Gateway: bind to all interfaces so Traefik can reach us
if (!cfg.gateway) cfg.gateway = {};
cfg.gateway.bind = 'lan';

// Trust RFC 1918 networks so Traefik's forwarded headers are respected
cfg.gateway.trustedProxies = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'];

// Allow HTTP + token auth (Traefik terminates TLS upstream)
if (!cfg.gateway.controlUi) cfg.gateway.controlUi = {};
cfg.gateway.controlUi.allowInsecureAuth = true;

fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Config patched:', JSON.stringify({
  bind: cfg.gateway.bind,
  trustedProxies: cfg.gateway.trustedProxies,
  allowInsecureAuth: cfg.gateway.controlUi.allowInsecureAuth
}));
"

# Auto-fix any invalid/deprecated config keys left over from older versions.
# This replaces manual key-by-key cleanup — doctor --fix handles everything.
echo "[entrypoint] Running openclaw doctor --fix ..."
node /app/openclaw.mjs doctor --fix 2>&1 || true
echo "[entrypoint] Doctor complete."

# Launch OpenClaw (official entrypoint)
exec node /app/openclaw.mjs "$@"
