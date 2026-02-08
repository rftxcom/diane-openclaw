FROM ghcr.io/openclaw/openclaw:main

LABEL org.opencontainers.image.source="https://github.com/rftxcom/diane-openclaw"
LABEL org.opencontainers.image.description="Diane gateway — OpenClaw behind Coolify/Traefik"

# Switch to root to copy entrypoint, then back to node
USER root
COPY --chown=node:node entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
USER node

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gateway", "--port", "18789", "--bind", "lan", "--allow-unconfigured"]
