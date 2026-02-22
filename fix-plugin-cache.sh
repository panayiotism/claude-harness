#!/bin/bash
# Claude Harness — Fix Stale Plugin Cache
#
# Fixes the known Claude Code bug where `claude plugin update` does not
# re-download plugin files (#19197, #14061, #13799, #15642).
#
# This script:
#   1. Updates the marketplace git cache (git pull)
#   2. Downloads latest plugin source from GitHub
#   3. Creates correct cache directory
#   4. Updates installed_plugins.json registry
#
# Usage (run in your terminal, NOT inside Claude Code):
#   bash <(curl -sf https://raw.githubusercontent.com/panayiotism/claude-harness/main/fix-plugin-cache.sh)
#   bash <(curl -sf https://raw.githubusercontent.com/panayiotism/claude-harness/main/fix-plugin-cache.sh) --branch development

set -euo pipefail

# --- Argument parsing ---
BRANCH="main"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch|-b)
            BRANCH="${2:?'--branch requires a branch name'}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--branch <name>]"
            exit 1
            ;;
    esac
done

REPO="panayiotism/claude-harness"
PLUGIN_KEY="claude-harness@claude-harness"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/claude-harness"
CACHE_BASE="$HOME/.claude/plugins/cache/claude-harness/claude-harness"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

echo "=== Claude Harness: Fix Plugin Cache ==="
[ "$BRANCH" != "main" ] && echo "  Branch: $BRANCH"
echo ""

# --- Prerequisites ---
if [ ! -f "$INSTALLED_PLUGINS" ]; then
    echo "Plugin not installed. Installing fresh..."
    echo "  Run: claude plugin install claude-harness github:$REPO"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required"; exit 1
fi

# --- Step 1: Update marketplace git cache ---
if [ -d "$MARKETPLACE_DIR/.git" ]; then
    echo "[1/4] Updating marketplace cache..."
    (cd "$MARKETPLACE_DIR" && git fetch origin "$BRANCH" 2>/dev/null && git reset --hard "origin/$BRANCH" 2>/dev/null) \
        && echo "  Marketplace updated." \
        || echo "  WARN: Could not update marketplace (non-critical, continuing...)"
else
    echo "[1/4] No marketplace cache found (skipping)"
fi

# --- Step 2: Fetch latest version ---
echo "[2/4] Checking latest version on GitHub..."

LATEST_VERSION=""
LATEST_SHA=""

if command -v gh &>/dev/null; then
    LATEST_VERSION=$(gh api "repos/$REPO/contents/claude-harness/.claude-plugin/plugin.json?ref=$BRANCH" \
        --jq '.content' 2>/dev/null | base64 -d 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || true)
    LATEST_SHA=$(gh api "repos/$REPO/commits/$BRANCH" --jq '.sha' 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -sf --max-time 10 \
        "https://raw.githubusercontent.com/$REPO/$BRANCH/claude-harness/.claude-plugin/plugin.json" 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || true)
fi

if [ -z "$LATEST_SHA" ]; then
    LATEST_SHA=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/$REPO/commits/$BRANCH" 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])" 2>/dev/null || true)
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not fetch latest version from GitHub."
    echo "Check your network connection and try again."
    exit 1
fi

CURRENT_VERSION=$(python3 -c "
import json
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
p = data.get('plugins', {}).get('$PLUGIN_KEY', [])
print(p[0].get('version', 'unknown') if p else 'not-installed')
" 2>/dev/null || echo "unknown")

echo "  Installed: v$CURRENT_VERSION"
echo "  Latest:    v$LATEST_VERSION"

# Patch marketplace plugin.json so Claude Code resolves to the correct version directory.
# Claude Code reads the marketplace cache (not installed_plugins.json) to determine
# which cache version to load. If the git update in Step 1 failed, the marketplace
# still points to the old version and Claude Code ignores the new cache directory.
MARKETPLACE_PLUGIN_JSON="$MARKETPLACE_DIR/claude-harness/.claude-plugin/plugin.json"
if [ -f "$MARKETPLACE_PLUGIN_JSON" ]; then
    MARKETPLACE_VERSION=$(python3 -c "import json; print(json.load(open('$MARKETPLACE_PLUGIN_JSON'))['version'])" 2>/dev/null || true)
    if [ -n "$MARKETPLACE_VERSION" ] && [ "$MARKETPLACE_VERSION" != "$LATEST_VERSION" ]; then
        python3 -c "
import json
with open('$MARKETPLACE_PLUGIN_JSON') as f:
    data = json.load(f)
data['version'] = '$LATEST_VERSION'
with open('$MARKETPLACE_PLUGIN_JSON', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        echo "  Marketplace version patched: v$MARKETPLACE_VERSION -> v$LATEST_VERSION"
    fi
fi

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    # Verify cache directory exists for the installed version
    if [ -d "$CACHE_BASE/$LATEST_VERSION" ]; then
        echo ""
        echo "Already up to date! No action needed."
        exit 0
    fi
    echo "  Cache directory missing for v$LATEST_VERSION, re-downloading..."
fi

# --- Step 3: Download and extract ---
echo "[3/4] Downloading v$LATEST_VERSION..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DOWNLOAD_OK=false
if command -v gh &>/dev/null; then
    gh api "repos/$REPO/tarball/$BRANCH" > "$TMPDIR/repo.tar.gz" 2>/dev/null && DOWNLOAD_OK=true
fi
if [ "$DOWNLOAD_OK" = false ]; then
    curl -sfL --max-time 60 "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
        -o "$TMPDIR/repo.tar.gz" 2>/dev/null && DOWNLOAD_OK=true
fi
if [ "$DOWNLOAD_OK" = false ]; then
    echo "ERROR: Could not download from GitHub"; exit 1
fi

tar -xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR"
EXTRACTED_DIR=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -1)
PLUGIN_SRC="$EXTRACTED_DIR/claude-harness"

if [ ! -f "$PLUGIN_SRC/.claude-plugin/plugin.json" ]; then
    echo "ERROR: Downloaded archive missing plugin.json"; exit 1
fi

# --- Step 4: Install to cache and update registry ---
echo "[4/4] Installing to cache..."

# Remove ALL existing version cache directories so Claude Code can only find the new one
for old_dir in "$CACHE_BASE"/*/; do
    [ -d "$old_dir" ] || continue
    rm -rf "$old_dir"
    echo "  Removed stale cache: $(basename "$old_dir")/"
done

NEW_CACHE="$CACHE_BASE/$LATEST_VERSION"
mkdir -p "$NEW_CACHE"
cp -r "$PLUGIN_SRC/." "$NEW_CACHE/"
chmod +x "$NEW_CACHE/hooks/"*.sh "$NEW_CACHE/setup.sh" 2>/dev/null || true

# Update registry
python3 -c "
import json
from datetime import datetime, timezone

with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)

key = '$PLUGIN_KEY'
plugins = data.get('plugins', {}).get(key, [])
if plugins:
    plugins[0]['installPath'] = '$NEW_CACHE'
    plugins[0]['version'] = '$LATEST_VERSION'
    if '$LATEST_SHA':
        plugins[0]['gitCommitSha'] = '$LATEST_SHA'
    plugins[0]['lastUpdated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
else:
    data.setdefault('plugins', {}).setdefault(key, []).append({
        'scope': 'user',
        'installPath': '$NEW_CACHE',
        'version': '$LATEST_VERSION',
        'installedAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z',
        'lastUpdated': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z',
        'gitCommitSha': '$LATEST_SHA'
    })

with open('$INSTALLED_PLUGINS', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

# Persist branch preference so the session-start.sh auto-update pulls from the right branch
echo "$BRANCH" > "$CACHE_BASE/.branch"

# Clear stale version check (forces re-fetch on next session start)
rm -f "$HOME/.claude/plugins/cache/claude-harness/.version-check" 2>/dev/null

echo ""
echo "=== Updated: v$CURRENT_VERSION -> v$LATEST_VERSION ==="
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (exit all sessions)"
echo "  2. Run /claude-harness:setup in your project"
echo ""
