#!/bin/bash
set -e

CONFIG="/home/node/.openclaw/openclaw.json"

# Ensure config directory exists
mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace

# If no config exists at all, create one from scratch
if [ ! -f "$CONFIG" ]; then
  echo '{"gateway":{"bind":"lan","controlUi":{"allowInsecureAuth":true}}}' > "$CONFIG"
  echo "[entrypoint] Created default openclaw.json"
fi

# Patch existing config to ensure bind=lan and allowInsecureAuth=true
# Uses node since jq isn't available in node:22-bookworm by default
node -e "
const fs = require('fs');
const path = '$CONFIG';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path, 'utf8')); } catch(e) {}
if (!cfg.gateway) cfg.gateway = {};
cfg.gateway.bind = 'lan';
if (!cfg.gateway.controlUi) cfg.gateway.controlUi = {};
cfg.gateway.controlUi.allowInsecureAuth = true;
fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Patched config:', JSON.stringify({bind: cfg.gateway.bind, allowInsecureAuth: cfg.gateway.controlUi.allowInsecureAuth}));
"

# Launch OpenClaw with all passed arguments
exec node /app/dist/index.js "$@"
