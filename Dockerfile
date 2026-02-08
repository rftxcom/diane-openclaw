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

# Copy entrypoint script that patches config on every startup
# (ensures bind=lan and allowInsecureAuth=true even if a volume overrides the config)
COPY --chown=node:node entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER node
WORKDIR /home/node

ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gateway", "--port", "18789", "--bind", "lan"]
