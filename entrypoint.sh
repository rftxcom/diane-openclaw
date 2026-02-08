#!/bin/bash
set -e

CONFIG="/home/node/.openclaw/openclaw.json"

# Ensure config directory exists
mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace

# Patch config for server deployment behind Coolify/Traefik.
# Matches the exact schema expected by OpenClaw 2026.2.x.
# Only sets gateway.bind to lan — everything else is preserved as-is.
node -e "
const fs = require('fs');
const cfgPath = '$CONFIG';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8')); } catch(e) {}

// Gateway: bind to all interfaces so Traefik can reach us
if (!cfg.gateway) cfg.gateway = {};
cfg.gateway.bind = 'lan';
cfg.gateway.port = 18789;

fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Config patched: gateway.bind=lan');
"

# Auto-fix any invalid/deprecated config keys
echo "[entrypoint] Running openclaw doctor --fix ..."
node /app/openclaw.mjs doctor --fix 2>&1 || true
echo "[entrypoint] Doctor complete."

# Launch OpenClaw (official entrypoint)
exec node /app/openclaw.mjs "$@"
