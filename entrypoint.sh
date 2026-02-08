#!/bin/bash
set -e

CONFIG="/home/node/.openclaw/openclaw.json"

# Ensure config directory exists
mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace

echo "[entrypoint] OpenClaw entrypoint starting..."
echo "[entrypoint] Node version: $(node --version)"

# Patch config for server deployment behind Coolify/Traefik.
# Matches the exact schema expected by OpenClaw 2026.2.x.
node -e "
const fs = require('fs');
const cfgPath = '$CONFIG';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8')); } catch(e) {
  console.log('[entrypoint] No existing config or parse error, starting fresh');
}

// Gateway: bind to all interfaces so Traefik can reach us
if (!cfg.gateway) cfg.gateway = {};
cfg.gateway.bind = 'lan';
cfg.gateway.port = 18789;

// Inject API keys from environment into env.vars
// OpenClaw 2026.2.x expects keys in env.vars, not in provider configs
if (!cfg.env) cfg.env = {};
if (!cfg.env.vars) cfg.env.vars = {};

if (process.env.ANTHROPIC_API_KEY) {
  cfg.env.vars.ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
  console.log('[entrypoint] Injected ANTHROPIC_API_KEY into env.vars');
}
if (process.env.OPENROUTER_API_KEY) {
  cfg.env.vars.OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
  console.log('[entrypoint] Injected OPENROUTER_API_KEY into env.vars');
}

fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Config patched successfully');
console.log('[entrypoint] Config keys:', Object.keys(cfg).join(', '));
"

# Auto-fix any invalid/deprecated config keys
echo "[entrypoint] Running openclaw doctor --fix ..."
node /app/openclaw.mjs doctor --fix 2>&1 || true
echo "[entrypoint] Doctor complete."

# Show final config keys (no values) for debugging
echo "[entrypoint] Final config structure:"
node -e "
const fs = require('fs');
try {
  const cfg = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
  const show = (obj, prefix='') => {
    for (const [k,v] of Object.entries(obj)) {
      if (v && typeof v === 'object' && !Array.isArray(v)) {
        show(v, prefix + k + '.');
      } else {
        const val = typeof v === 'string' && v.length > 8 ? v.substring(0,4)+'...' : v;
        console.log('  ' + prefix + k + ':', val);
      }
    }
  };
  show(cfg);
} catch(e) { console.log('  Error reading config:', e.message); }
" 2>&1 || true

# Launch OpenClaw (official entrypoint)
echo "[entrypoint] Launching: node /app/openclaw.mjs $@"
exec node /app/openclaw.mjs "$@"
