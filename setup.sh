#!/usr/bin/env bash
# setup.sh — first-time install on fresh VM
# Uses Determinate Systems nix-installer
# Run: curl -fsSL https://raw.githubusercontent.com/atomic-235/portable/main/setup.sh | bash
#
# Requires: sudo access (for /nix directory creation)
# NEVER deletes or modifies user's existing files
set -uo pipefail

PORTABLE_DIR="${PORTABLE_DIR:-$HOME/portable}"

# --- step 1: install nix ---

echo "=== Installing nix ==="
if ! command -v nix &>/dev/null; then
  # Detect systemd — use --init none only if no systemd
  NIX_INSTALL_ARGS="--no-confirm"
  if ! pidof systemd &>/dev/null; then
    NIX_INSTALL_ARGS="linux --init none --no-confirm"
  fi
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install $NIX_INSTALL_ARGS
  # Source nix env
  if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  fi
  # Start nix daemon if no systemd (systemd auto-starts it)
  if ! pidof systemd &>/dev/null; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon &
    sleep 2
  fi
else
  echo "nix already installed: $(nix --version)"
fi

# --- step 2: enable flakes ---

echo "=== Enabling flakes ==="
mkdir -p "$HOME/.config/nix"
if ! grep -q 'experimental-features' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

# --- step 3: clone portable ---

echo "=== Cloning portable ==="
if [[ -d "$PORTABLE_DIR/.git" ]]; then
  echo "$PORTABLE_DIR already exists, pulling latest..."
  git -C "$PORTABLE_DIR" pull --rebase
  git -C "$PORTABLE_DIR" submodule update --remote --merge
else
  git clone --recursive https://github.com/atomic-235/portable "$PORTABLE_DIR"
fi

# --- step 4: apply home-manager ---

echo "=== Applying home-manager config ==="
cd "$PORTABLE_DIR"
nix run .#hm -- switch --flake .#user --impure -b backup

# --- step 5: install opencode (prebuilt binary, not nix) ---

echo "=== Installing opencode ==="
# nixpkgs opencode segfaults on WSL2 — Bun-compiled binary incompatibility
# Install prebuilt binary from official installer instead
# https://github.com/anomalyco/opencode/issues/26846
if ! command -v opencode &>/dev/null; then
  curl -fsSL https://opencode.ai/install | bash
else
  echo "opencode already installed: $(opencode --version 2>&1 || echo 'unknown')"
fi

# --- step 6: create activation script ---

echo "=== Creating activation script ==="
cat > "$PORTABLE_DIR/activate.sh" << 'BPEOF'
# Portable nix environment activation
# Add this to your ~/.bashrc:
#   [ -f ~/portable/activate.sh ] && source ~/portable/activate.sh
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
  . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  # Start nix daemon if not running (no systemd)
  if ! pgrep -x nix-daemon &>/dev/null; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon &>/dev/null &
    sleep 1
  fi
fi
BPEOF

echo "=== Activating in ~/.bashrc ==="
if ! grep -q 'portable/activate.sh' "$HOME/.bashrc" 2>/dev/null; then
  echo '[ -f ~/portable/activate.sh ] && source ~/portable/activate.sh' >> "$HOME/.bashrc"
  echo "Added activation line to ~/.bashrc"
fi

echo ""
echo "=== Setup complete ==="
echo "Restart your shell: exec bash -l"
echo ""
echo "To update later: $PORTABLE_DIR/update.sh"
echo ""
echo "To add work/databricks config: cp $PORTABLE_DIR/local.nix.example $PORTABLE_DIR/local.nix"
echo "Edit local.nix with your model names, SECRETS_DIR, and wrapper functions."
echo "Then run: $PORTABLE_DIR/update.sh"
