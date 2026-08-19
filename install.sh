#!/bin/bash
# Scope plugin installer for Omarchy Quattro
#
# Usage: ./install.sh [--uninstall]
#
# This installer:
#   - Copies only the runtime/release files to ~/.config/omarchy/plugins/goblin.scope/
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
SCOPE_BINDING_COMMENT="-- Scope: circle anything, search anything"
SCOPE_BINDING_NOTE="-- Installed by the Scope plugin. Remove this block to uninstall the shortcut."
SCOPE_BINDING_LINE="o.bind(\"$DEFAULT_SHORTCUT\", \"Scope\", \"omarchy-shell shell summon $PLUGIN_ID '{}'\")"

# ── helpers ────────────────────────────────────────────────────────────────

info() { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }
step() { echo "→ $*"; }
die()  { echo "✗ ERROR: $*" >&2; exit 1; }

reload_hyprland() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl reload >/dev/null || {
    warn "Hyprland did not reload; reload it manually to apply the shortcut"
    return 0
  }
  local config_errors
  config_errors=$(hyprctl configerrors 2>/dev/null || true)
  [[ -z $config_errors ]] \
    || warn "Hyprland reports configuration errors; review 'hyprctl configerrors'"
}

check_prerequisites() {
  command -v omarchy >/dev/null 2>&1 || die "Omarchy CLI not found"
  command -v omarchy-shell >/dev/null 2>&1 || die "Omarchy shell CLI not found"
  command -v jq >/dev/null 2>&1 || die "jq not found — required for plugin status checks"
  command -v grim  >/dev/null 2>&1 || warn "grim not found — screen capture will fail"
  command -v convert >/dev/null 2>&1 || warn "imagemagick (convert) not found — lasso masking will be degraded"

  # Check for at least one agent
  if ! command -v codex >/dev/null 2>&1; then
    warn "Codex not found — install/configure Codex to use Scope Search"
  fi
}

do_install() {
  step "Installing Scope plugin..."

  # When this script is run from an official `omarchy plugin add` checkout,
  # the source already is the installed plugin. For local development installs,
  # copy an explicit allowlist so tests and development output never ship.
  if [[ $(realpath -m -- "$PLUGIN_SRC") != $(realpath -m -- "$PLUGIN_DST") ]]; then
    mkdir -p "$PLUGIN_DST/components" "$PLUGIN_DST/scripts/adapters"
    install -m 0644 \
      "$PLUGIN_SRC/manifest.json" \
      "$PLUGIN_SRC/Scope.qml" \
      "$PLUGIN_SRC/ScopeOverlay.qml" \
      "$PLUGIN_SRC/ScopeService.qml" \
      "$PLUGIN_SRC/README.md" \
      "$PLUGIN_SRC/SECURITY.md" \
      "$PLUGIN_SRC/LICENSE" \
      "$PLUGIN_DST/"
    install -m 0644 "$PLUGIN_SRC"/components/*.qml "$PLUGIN_DST/components/"
    install -m 0755 "$PLUGIN_SRC/install.sh" "$PLUGIN_DST/"
    install -m 0755 \
      "$PLUGIN_SRC/scripts/scope-helper" \
      "$PLUGIN_SRC/scripts/scope-detect-agent" \
      "$PLUGIN_DST/scripts/"
    install -m 0755 "$PLUGIN_SRC"/scripts/adapters/* "$PLUGIN_DST/scripts/adapters/"
    info "Plugin runtime files copied to $PLUGIN_DST"
  else
    info "Using the existing Omarchy plugin checkout at $PLUGIN_DST"
  fi

  # Rescan and enable through the current supported Omarchy plugin commands.
  omarchy-shell shell rescanPlugins >/dev/null
  local discovered=false
  for _ in {1..40}; do
    if omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" \
        'any(.[]; .id == $id)' >/dev/null; then
      discovered=true
      break
    fi
    sleep 0.05
  done
  [[ $discovered == true ]] || die "Plugin was copied but Quattro did not discover it"
  omarchy plugin enable "$PLUGIN_ID" >/dev/null \
    || die "Plugin was discovered but could not be enabled"
  info "Plugin activated in running shell"

  # Add the shortcut only after Quattro has accepted and enabled the plugin.
  install_keybinding

  step "Installation complete!"
  echo ""
  echo "  Shortcut: $DEFAULT_SHORTCUT"
  echo ""
  echo "  See README.md and SECURITY.md for full documentation."
}

install_keybinding() {
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

-- Scope: circle anything, search anything
-- Installed by the Scope plugin. Remove this block to uninstall the shortcut.
$SCOPE_BINDING_LINE
EOF

  reload_hyprland
  info "Keybinding added: $DEFAULT_SHORTCUT → Scope"
}

do_uninstall() {
  step "Uninstalling Scope plugin..."

  if command -v omarchy >/dev/null 2>&1 \
      && omarchy plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" \
        'any(.[]; .id == $id and .enabled == true)' >/dev/null; then
    omarchy plugin disable "$PLUGIN_ID" >/dev/null
    info "Plugin disabled in running shell"
  fi

  if [[ -d $PLUGIN_DST ]]; then
    rm -rf "$PLUGIN_DST"
    info "Removed plugin directory: $PLUGIN_DST"
  else
    warn "Plugin directory not found: $PLUGIN_DST"
  fi

  # Remove only the exact Scope-owned lines. Do not reformat or otherwise
  # rewrite the user's bindings file.
  if [[ -f $BINDINGS_DST ]] && grep -qF "goblin.scope" "$BINDINGS_DST" 2>/dev/null; then
    local bindings_tmp
    bindings_tmp=$(mktemp "${BINDINGS_DST}.scope.XXXXXX")
    awk \
      -v current_comment="$SCOPE_BINDING_COMMENT" \
      -v legacy_comment="-- Scope: circle anything on screen and ask your AI agent" \
      -v note="$SCOPE_BINDING_NOTE" \
      -v binding="$SCOPE_BINDING_LINE" \
      '$0 != current_comment && $0 != legacy_comment && $0 != note && $0 != binding' \
      "$BINDINGS_DST" > "$bindings_tmp"
    chmod --reference="$BINDINGS_DST" "$bindings_tmp"
    mv "$bindings_tmp" "$BINDINGS_DST"
    reload_hyprland
    info "Removed keybinding from $BINDINGS_DST"
  fi

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null
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
