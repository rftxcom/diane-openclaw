FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/rftxcom/diane-openclaw"
LABEL org.opencontainers.image.description="OpenClaw Docker image for Diane gateway"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Clone and build OpenClaw from official repo - main branch has latest release
RUN git clone --depth 1 https://github.com/openclaw/openclaw.git . && \
    echo "Building OpenClaw version:" && \
    grep '"version"' package.json && \
    git rev-parse HEAD > /app/openclaw-commit.txt

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Build UI
RUN npm_config_script_shell=bash pnpm ui:install
RUN npm_config_script_shell=bash pnpm ui:build

# Clean up to reduce image size
RUN rm -rf .git node_modules/.cache

# Create directories for config
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace \
    && chown -R node:node /home/node /app

USER node
WORKDIR /home/node

# Seed default config:
# - bind: lan — listen on 0.0.0.0 so Coolify's reverse proxy can reach the gateway
# - allowInsecureAuth: true — allow HTTP + token auth, bypasses device pairing
#   (needed because Coolify terminates TLS and forwards plain HTTP to the container)
RUN printf '{\n  "gateway": {\n    "bind": "lan",\n    "controlUi": {\n      "allowInsecureAuth": true\n    }\n  }\n}\n' > /home/node/.openclaw/openclaw.json

ENV NODE_ENV=production
ENV OPENCLAW_GATEWAY_BIND=lan
ENV PATH="/app/node_modules/.bin:${PATH}"

ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["gateway", "--port", "18789", "--bind", "lan"]
