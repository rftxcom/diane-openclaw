#!/bin/bash

OCDIR="/home/node/.openclaw"
CONFIG="$OCDIR/openclaw.json"

# Ensure config directory exists
mkdir -p "$OCDIR" "$OCDIR/workspace" "$OCDIR/workspace-chris" "$OCDIR/workspace-ryan"

echo "[entrypoint] OpenClaw entrypoint starting..."

# Write the full restored config from the Feb 3 2026 backup.
# Only the gateway section is modified for Coolify/Traefik deployment:
#   - bind: lan (instead of loopback, so Traefik can reach us)
#   - port: 18789
#   - dangerouslyDisableDeviceAuth: true (original setting from backup)
#   - trustedProxies for RFC 1918 ranges (Docker/Traefik networks)
# API keys injected from environment variables at runtime.
node -e "
const fs = require('fs');

const cfg = {
  meta: {
    lastTouchedVersion: '2026.2.1',
    lastTouchedAt: new Date().toISOString()
  },
  env: {
    vars: {
      OPENROUTER_API_KEY: process.env.OPENROUTER_API_KEY || '',
      OPENAI_API_KEY: process.env.OPENAI_API_KEY || '',
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || '',
      BRAVE_API_KEY: process.env.BRAVE_API_KEY || 'BSAWMNzBDJf66Uz4V2z6mjE06EhOZs7'
    }
  },
  models: {
    mode: 'merge',
    providers: {
      openrouter: {
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: process.env.OPENROUTER_API_KEY || '',
        api: 'openai-completions',
        models: [
          {
            id: 'moonshotai/kimi-k2.5',
            name: 'Kimi K2.5',
            reasoning: true,
            input: ['text'],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 131072,
            maxTokens: 8192
          }
        ]
      }
    }
  },
  agents: {
    defaults: {
      model: {
        primary: 'anthropic/claude-sonnet-4-5',
        fallbacks: [
          'anthropic/claude-opus-4-5',
          'openrouter/moonshotai/kimi-k2.5'
        ]
      },
      models: {
        'openrouter/moonshotai/kimi-k2.5': {
          alias: 'kimi',
          params: { max_tokens: 4000 }
        },
        'anthropic/claude-opus-4-5': {
          alias: 'opus',
          params: { cacheControlTtl: '1h' }
        },
        'anthropic/claude-sonnet-4-5': {
          alias: 'sonnet',
          params: { cacheControlTtl: '1h' }
        }
      },
      contextPruning: { mode: 'cache-ttl', ttl: '1h' },
      compaction: { mode: 'safeguard' },
      heartbeat: { every: '30m' },
      maxConcurrent: 4,
      subagents: {
        maxConcurrent: 8,
        model: 'anthropic/claude-sonnet-4-5'
      }
    },
    list: [
      {
        id: 'main',
        default: true,
        workspace: '/home/node/.openclaw/workspace',
        identity: { name: 'Diane Evans', emoji: '⭐' },
        groupChat: {
          mentionPatterns: ['Diane', 'diane', '@DianeEvansRFT_bot']
        }
      },
      {
        id: 'chris',
        workspace: '/home/node/.openclaw/workspace-chris',
        identity: { name: 'Chris Sullivan', emoji: '📢' },
        groupChat: {
          mentionPatterns: ['Chris', 'chris', '@ChrisSullivan_TNMbot']
        }
      },
      {
        id: 'ryan',
        workspace: '/home/node/.openclaw/workspace-ryan',
        identity: { name: 'Ryan Mitchell', emoji: '📈' },
        groupChat: {
          mentionPatterns: ['Ryan', 'ryan']
        }
      }
    ]
  },
  bindings: [
    {
      agentId: 'chris',
      match: { channel: 'telegram', accountId: 'chris' }
    }
  ],
  messages: {
    ackReactionScope: 'group-mentions'
  },
  commands: {
    native: 'auto',
    nativeSkills: 'auto'
  },
  channels: {
    telegram: {
      enabled: true,
      dmPolicy: 'allowlist',
      groups: {
        '-4877530471': { requireMention: true }
      },
      allowFrom: ['8340570584'],
      groupPolicy: 'allowlist',
      streamMode: 'partial',
      accounts: {
        default: {
          name: 'Diane',
          dmPolicy: 'pairing',
          botToken: process.env.TELEGRAM_BOT_TOKEN_DIANE || '8561247056:AAEFXtGZKKF7Cb6lDcJw1IF6zuM_YSleJpg',
          groupPolicy: 'allowlist',
          streamMode: 'partial'
        },
        chris: {
          name: 'Chris',
          dmPolicy: 'pairing',
          botToken: process.env.TELEGRAM_BOT_TOKEN_CHRIS || '8145763077:AAEkt18xzAmMOpjrDF1l092e-cmc3tHOo5k',
          groupPolicy: 'allowlist',
          streamMode: 'partial'
        }
      }
    }
  },
  gateway: {
    mode: 'local',
    bind: 'lan',
    port: 18789,
    controlUi: {
      dangerouslyDisableDeviceAuth: true
    },
    trustedProxies: ['172.16.0.0/12', '10.0.0.0/8', '192.168.0.0/16'],
    auth: {
      token: process.env.OPENCLAW_GATEWAY_TOKEN || ''
    }
  },
  skills: {
    entries: {
      'local-places': {
        apiKey: process.env.GOOGLE_PLACES_API_KEY || 'AIzaSyAiPCrql8r9nHPaXKRwfWi2TgXjCzkJ7LM'
      }
    }
  },
  plugins: {
    entries: {
      telegram: { enabled: true }
    }
  }
};

// Remove empty string values for keys not set
Object.keys(cfg.env.vars).forEach(k => {
  if (!cfg.env.vars[k]) delete cfg.env.vars[k];
});
if (!cfg.gateway.auth.token) delete cfg.gateway.auth.token;
if (!cfg.models.providers.openrouter.apiKey) delete cfg.models.providers.openrouter.apiKey;

fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
console.log('[entrypoint] Full config restored from Feb 3 backup');
console.log('[entrypoint] Agents:', cfg.agents.list.map(a => a.id).join(', '));
console.log('[entrypoint] Telegram:', cfg.channels.telegram.enabled ? 'enabled' : 'disabled');
console.log('[entrypoint] Gateway bind:', cfg.gateway.bind);
"

# Launch OpenClaw gateway directly
echo "[entrypoint] Launching gateway..."
exec node /app/openclaw.mjs "$@"
