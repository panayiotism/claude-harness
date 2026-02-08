#!/bin/bash
# Claude Harness - Fix Stale Plugin Cache
#
# The Claude Code plugin cache can become stale because `claude plugin update`
# updates metadata but does not re-download plugin files. This script fixes that
# by downloading the latest version from GitHub and replacing the cache.
#
# Usage (run in your terminal, NOT inside Claude Code):
#   bash <(curl -sf https://raw.githubusercontent.com/panayiotism/claude-harness/main/fix-stale-cache.sh)
#
# After running, restart Claude Code for changes to take effect,
# then run /claude-harness:setup in your project.

set -euo pipefail

INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
PLUGIN_KEY="claude-harness@claude-harness"
REPO="panayiotism/claude-harness"
CACHE_BASE="$HOME/.claude/plugins/cache/claude-harness/claude-harness"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/claude-harness"

echo "=== Claude Harness: Fix Stale Plugin Cache ==="
echo ""

# Step 1: Check prerequisites
if [ ! -f "$INSTALLED_PLUGINS" ]; then
    echo "ERROR: Plugin not installed ($INSTALLED_PLUGINS not found)"
    echo "Install the plugin first:"
    echo "  claude plugin install claude-harness github:panayiotism/claude-harness"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required but not found"
    exit 1
fi

# Step 2: Get current install info
CURRENT_PATH=$(python3 -c "
import json
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
plugins = data.get('plugins', {}).get('$PLUGIN_KEY', [])
print(plugins[0]['installPath'] if plugins else '')
" 2>/dev/null)

CURRENT_VERSION=$(python3 -c "
import json
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
plugins = data.get('plugins', {}).get('$PLUGIN_KEY', [])
print(plugins[0].get('version', 'unknown') if plugins else 'unknown')
" 2>/dev/null)

if [ -z "$CURRENT_PATH" ]; then
    echo "ERROR: Plugin '$PLUGIN_KEY' not found in installed_plugins.json"
    exit 1
fi

echo "Current cache: v$CURRENT_VERSION"
echo "  Path: $CURRENT_PATH"

# Step 3: Fetch latest version from GitHub
echo ""
echo "Checking GitHub for latest version..."

LATEST_VERSION=""
LATEST_SHA=""

# Get latest version from plugin.json on main branch
if command -v gh &>/dev/null; then
    LATEST_VERSION=$(gh api "repos/$REPO/contents/.claude-plugin/plugin.json" \
        --jq '.content' 2>/dev/null | base64 -d 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || true)
    LATEST_SHA=$(gh api "repos/$REPO/commits/main" --jq '.sha' 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -sf --max-time 10 \
        "https://raw.githubusercontent.com/$REPO/main/.claude-plugin/plugin.json" 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || true)
fi

if [ -z "$LATEST_SHA" ]; then
    LATEST_SHA=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/$REPO/commits/main" 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])" 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not fetch latest version from GitHub"
    echo "Check your network connection and try again."
    exit 1
fi

echo "Latest version: v$LATEST_VERSION (SHA: ${LATEST_SHA:0:7})"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo ""
    echo "Plugin is already up to date! No action needed."
    exit 0
fi

echo ""
echo "Updating v$CURRENT_VERSION -> v$LATEST_VERSION..."

# Step 4: Download the latest version
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading from GitHub..."
DOWNLOAD_OK=false

if command -v gh &>/dev/null; then
    if gh api "repos/$REPO/tarball/main" > "$TMPDIR/repo.tar.gz" 2>/dev/null; then
        DOWNLOAD_OK=true
    fi
fi

if [ "$DOWNLOAD_OK" = false ]; then
    if curl -sfL --max-time 60 "https://github.com/$REPO/archive/refs/heads/main.tar.gz" \
        -o "$TMPDIR/repo.tar.gz" 2>/dev/null; then
        DOWNLOAD_OK=true
    fi
fi

if [ "$DOWNLOAD_OK" = false ]; then
    echo "ERROR: Could not download from GitHub"
    exit 1
fi

# Extract
tar -xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR"
EXTRACTED_DIR=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -1)

if [ ! -f "$EXTRACTED_DIR/.claude-plugin/plugin.json" ]; then
    echo "ERROR: Downloaded archive does not contain a valid plugin"
    exit 1
fi

# Step 5: Create new cache directory
NEW_CACHE_PATH="$CACHE_BASE/$LATEST_VERSION"
echo "Creating new cache at: $NEW_CACHE_PATH"

if [ -d "$NEW_CACHE_PATH" ]; then
    rm -rf "$NEW_CACHE_PATH"
fi

mkdir -p "$NEW_CACHE_PATH"
cp -r "$EXTRACTED_DIR/." "$NEW_CACHE_PATH/"
rm -rf "$NEW_CACHE_PATH/.git" 2>/dev/null || true

# Make scripts executable
chmod +x "$NEW_CACHE_PATH/hooks/"*.sh 2>/dev/null || true
chmod +x "$NEW_CACHE_PATH/setup.sh" 2>/dev/null || true
chmod +x "$NEW_CACHE_PATH/dev-mode.sh" 2>/dev/null || true
chmod +x "$NEW_CACHE_PATH/fix-stale-cache.sh" 2>/dev/null || true

# Step 6: Update installed_plugins.json
echo "Updating plugin registry..."
python3 -c "
import json
from datetime import datetime, timezone

with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)

plugins = data.get('plugins', {}).get('$PLUGIN_KEY', [])
if plugins:
    plugins[0]['installPath'] = '$NEW_CACHE_PATH'
    plugins[0]['version'] = '$LATEST_VERSION'
    if '$LATEST_SHA':
        plugins[0]['gitCommitSha'] = '$LATEST_SHA'
    plugins[0]['lastUpdated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'

with open('$INSTALLED_PLUGINS', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

# Step 7: Update marketplace directory if it's a git repo
if [ -d "$MARKETPLACE_DIR/.git" ]; then
    echo "Updating marketplace cache..."
    (cd "$MARKETPLACE_DIR" && git fetch origin main 2>/dev/null && git reset --hard origin/main 2>/dev/null) || \
        echo "  [WARN] Could not update marketplace git repo (non-critical)"
fi

# Step 8: Back up old cache
if [ -d "$CURRENT_PATH" ] && [ "$CURRENT_PATH" != "$NEW_CACHE_PATH" ]; then
    BACKUP_PATH="${CURRENT_PATH}.backup-$(date +%Y%m%d%H%M%S)"
    mv "$CURRENT_PATH" "$BACKUP_PATH" 2>/dev/null || true
    echo "Old cache backed up to: $BACKUP_PATH"
fi

# Clear version check cache so session-start doesn't show stale warning
rm -f "$HOME/.claude/plugins/cache/claude-harness/.version-check" 2>/dev/null || true

echo ""
echo "=== Update Complete ==="
echo "  v$CURRENT_VERSION -> v$LATEST_VERSION"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (exit all sessions, start fresh)"
echo "  2. Run /claude-harness:setup in your project to sync commands"
echo ""
