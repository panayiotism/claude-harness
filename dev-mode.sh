#!/bin/bash
# Claude Harness Dev Mode Toggle
# Replaces the plugin cache directory with a symlink to the source repo
# so that changes are immediately reflected in Claude Code.
#
# Usage: ./dev-mode.sh [enable|disable|status]

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
BACKUP_SUFFIX=".dev-mode-backup"

get_install_path() {
  python3 -c "
import json
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
plugins = data.get('plugins', {}).get('claude-harness@claude-harness', [])
if plugins:
    print(plugins[0].get('installPath', ''))
else:
    print('')
" 2>/dev/null
}

get_source_version() {
  python3 -c "
import json
with open('$SOURCE_DIR/.claude-plugin/plugin.json') as f:
    print(json.load(f)['version'])
"
}

cmd_enable() {
  if [ ! -f "$SOURCE_DIR/.claude-plugin/plugin.json" ]; then
    echo "ERROR: Source repo not found at $SOURCE_DIR"
    exit 1
  fi

  local install_path
  install_path="$(get_install_path)"
  if [ -z "$install_path" ]; then
    echo "ERROR: Plugin not found in installed_plugins.json"
    echo "Install the plugin first, then enable dev mode."
    exit 1
  fi

  local source_version
  source_version="$(get_source_version)"

  if [ -L "$install_path" ]; then
    echo "Dev mode already enabled."
    echo "  Symlink: $install_path -> $(readlink -f "$install_path")"
    echo "  Source version: $source_version"
    return 0
  fi

  if [ -d "$install_path" ]; then
    echo "Backing up cache: $install_path -> ${install_path}${BACKUP_SUFFIX}"
    mv "$install_path" "${install_path}${BACKUP_SUFFIX}"
  fi

  echo "Creating symlink: $install_path -> $SOURCE_DIR"
  ln -s "$SOURCE_DIR" "$install_path"

  echo ""
  echo "Dev mode ENABLED (source v$source_version)"
  echo "Restart Claude Code for changes to take effect."
}

cmd_disable() {
  local install_path
  install_path="$(get_install_path)"
  if [ -z "$install_path" ]; then
    echo "ERROR: Plugin not found in installed_plugins.json"
    exit 1
  fi

  # Find backup directory
  local found_backup=""
  if [ -d "${install_path}${BACKUP_SUFFIX}" ]; then
    found_backup="${install_path}${BACKUP_SUFFIX}"
  fi

  if [ -L "$install_path" ]; then
    echo "Removing symlink: $install_path"
    rm "$install_path"
  elif [ -z "$found_backup" ]; then
    echo "Dev mode is not enabled (no symlink found)."
    return 0
  fi

  if [ -n "$found_backup" ]; then
    echo "Restoring cache from backup: $found_backup -> $install_path"
    mv "$found_backup" "$install_path"

    local restored_version
    restored_version="$(python3 -c "
import json
with open('${install_path}/.claude-plugin/plugin.json') as f:
    print(json.load(f)['version'])
")"
    echo ""
    echo "Dev mode DISABLED (restored to cache v$restored_version)"
  else
    echo ""
    echo "WARNING: No backup found. You may need to reinstall the plugin."
    echo "Dev mode DISABLED."
  fi

  echo "Restart Claude Code for changes to take effect."
}

cmd_status() {
  local install_path
  install_path="$(get_install_path)"
  if [ -z "$install_path" ]; then
    echo "Plugin not installed."
    return 0
  fi

  local source_version
  source_version="$(get_source_version)"

  echo "Source repo:  $SOURCE_DIR (v$source_version)"
  echo "Install path: $install_path"

  if [ -L "$install_path" ]; then
    echo "Dev mode:     ENABLED"
    echo "  Symlink -> $(readlink -f "$install_path")"
  else
    local cache_version
    cache_version="$(python3 -c "
import json
with open('${install_path}/.claude-plugin/plugin.json') as f:
    print(json.load(f)['version'])
" 2>/dev/null || echo "unknown")"
    echo "Dev mode:     DISABLED"
    echo "  Cache version: $cache_version"
  fi
}

case "${1:-status}" in
  enable)  cmd_enable ;;
  disable) cmd_disable ;;
  status)  cmd_status ;;
  *)
    echo "Usage: $0 [enable|disable|status]"
    exit 1
    ;;
esac
