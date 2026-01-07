# Claude Code Container - Minimal setup for autonomous claude-orchestrate
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install required dependencies for claude-orchestrate
RUN apt-get update && apt-get install -y \
    jq \
    coreutils \
    git \
    bash \
    curl \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (required for Claude CLI)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI
RUN npm install -g @anthropic-ai/claude-code

# Copy claude-orchestrate script from cache (populated by initializeCommand on host)
# This runs AFTER initializeCommand, so .claude-code-cache exists
COPY .claude-code-cache/scripts/claude-orchestrate /usr/local/bin/co
RUN chmod +x /usr/local/bin/co

# Copy CLAUDE.md to default location
COPY .claude-code-cache/claude/CLAUDE.md /etc/claude/CLAUDE.md

# Set sandbox environment indicator
ENV DOTFILES_CONTAINER=true

SHELL ["/bin/bash", "-c"]
