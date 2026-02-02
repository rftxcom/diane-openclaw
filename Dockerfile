FROM ghcr.io/phioranex/openclaw-docker:latest
CMD ["gateway", "--port", "18789", "--bind", "lan"]
