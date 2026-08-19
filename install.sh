#!/bin/bash
# Scope plugin installer for Omarchy Quattro
#
# Usage: ./install.sh [--uninstall]
#
# This installer:
#   - Copies the plugin to ~/.config/omarchy/plugins/goblin.scope/
#   - Adds the keybinding SUPER+SHIFT+Q to summon Scope
#   - Makes no privileged modifications (no sudo)
#   - Does not modify unrelated configuration
#
# To install the keybinding, we create a user bindings fragment that the
# Omarchy Hyprland config picks up. The user can modify or remove it freely.

set -euo pipefail

PLUGIN_ID="goblin.scope"
PLUGIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DST="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
BINDINGS_DST="${HOME}/.config/hypr/bindings.lua"
BINDINGS_BACKUP="${BINDINGS_DST}.scope-backup.$(date +%s)"

DEFAULT_SHORTCUT="SUPER + SHIFT + Q"

# ── helpers ────────────────────────────────────────────────────────────────

info() { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
step() { echo "→ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

check_prerequisites() {
  command -v grim  >/dev/null 2>&1 || warn "grim not found — screen capture will fail"
  command -v convert >/dev/null 2>&1 || warn "imagemagick (convert) not found — lasso masking will be degraded"
  command -v jq >/dev/null 2>&1 || warn "jq not found — Claude adapter may not work"

  # Check for at least one agent
  if ! command -v codex >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
    warn "Neither codex nor claude found — install at least one AI agent CLI to use Scope"
  fi
}

do_install() {
  step "Installing Scope plugin..."

  # Create plugin directory
  mkdir -p "$PLUGIN_DST"

  # Copy plugin files (exclude install/test infrastructure from deployment)
  rsync -av --exclude='.git' --exclude='tests' \
    "$PLUGIN_SRC/" "$PLUGIN_DST/" \
    2>/dev/null || {
    # Fallback if rsync not available
    cp -r "$PLUGIN_SRC/." "$PLUGIN_DST/"
    rm -rf "$PLUGIN_DST/.git" "$PLUGIN_DST/tests" 2>/dev/null || true
  }

  # Ensure helper scripts are executable
  chmod +x "$PLUGIN_DST/scripts/scope-helper"
  chmod +x "$PLUGIN_DST/scripts/scope-detect-agent"

  info "Plugin files copied to $PLUGIN_DST"

  # Add keybinding (if it doesn't already exist)
  install_keybinding

  step "Installation complete!"
  echo ""
  echo "  Shortcut: $DEFAULT_SHORTCUT"
  echo ""
  echo "  Reload the Omarchy shell to activate:"
  echo "    omarchy-shell shell reload"
  echo ""
  echo "  Or log out and log back in."
  echo ""
  echo "  See README.md and SECURITY.md for full documentation."
}

install_keybinding() {
  local binding_line="o.bind(\"$DEFAULT_SHORTCUT\", \"Scope\", \"omarchy-shell shell toggle $PLUGIN_ID\")"

  if [[ -f $BINDINGS_DST ]] && grep -qF "goblin.scope" "$BINDINGS_DST" 2>/dev/null; then
    info "Keybinding already present in $BINDINGS_DST"
    return
  fi

  # Append to user bindings file
  if [[ -f $BINDINGS_DST ]]; then
    cp "$BINDINGS_DST" "$BINDINGS_BACKUP"
    info "Backed up existing bindings to $BINDINGS_BACKUP"
  fi

  mkdir -p "$(dirname "$BINDINGS_DST")"
  cat >> "$BINDINGS_DST" << EOF

-- Scope: circle anything on screen and ask your AI agent
-- Installed by the Scope plugin. Remove this block to uninstall the shortcut.
$binding_line
EOF

  info "Keybinding added: $DEFAULT_SHORTCUT → Scope"
}

do_uninstall() {
  step "Uninstalling Scope plugin..."

  if [[ -d $PLUGIN_DST ]]; then
    rm -rf "$PLUGIN_DST"
    info "Removed plugin directory: $PLUGIN_DST"
  else
    warn "Plugin directory not found: $PLUGIN_DST"
  fi

  # Remove keybinding lines
  if [[ -f $BINDINGS_DST ]] && grep -qF "goblin.scope" "$BINDINGS_DST" 2>/dev/null; then
    # Remove the Scope binding block (comment header + bind line)
    sed -i '/-- Scope: circle anything/,/goblin\.scope/d' "$BINDINGS_DST"
    # Also remove blank trailing lines added by the block
    sed -i '/^[[:space:]]*$/{ /./!d }' "$BINDINGS_DST" 2>/dev/null || true
    info "Removed keybinding from $BINDINGS_DST"
  fi

  # Clean runtime files
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/scope"
  if [[ -d $runtime_dir ]]; then
    rm -rf "$runtime_dir"
    info "Removed runtime directory: $runtime_dir"
  fi

  step "Uninstall complete. No sensitive data remains."
}

# ── main ────────────────────────────────────────────────────────────────────

case "${1:-}" in
  --uninstall|-u)
    do_uninstall
    ;;
  *)
    check_prerequisites
    do_install
    ;;
esac
