#!/usr/bin/env bash
# setup.sh — first-time install on fresh VM
# Installs nix, clones portable, applies config
# Run: curl -fsSL https://raw.githubusercontent.com/atomic-235/portable/main/setup.sh | bash
set -euo pipefail

PORTABLE_DIR="${PORTABLE_DIR:-$HOME/portable}"

echo "=== Installing nix (single-user) ==="
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  # Source nix profile
  if [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
else
  echo "nix already installed: $(nix --version)"
fi

echo "=== Enabling flakes ==="
mkdir -p "$HOME/.config/nix"
if ! grep -q 'experimental-features' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

echo "=== Cloning portable ==="
if [[ -d "$PORTABLE_DIR/.git" ]]; then
  echo "$PORTABLE_DIR already exists, pulling latest..."
  git -C "$PORTABLE_DIR" pull --rebase
  git -C "$PORTABLE_DIR" submodule update --remote --merge
else
  git clone --recursive https://github.com/atomic-235/portable "$PORTABLE_DIR"
fi

echo "=== Applying home-manager config ==="
cd "$PORTABLE_DIR"
nix run github:nix-community/home-manager -- \
  switch --flake .#user --impure -b backup

echo ""
echo "=== Setup complete ==="
echo "Portable installed to: $PORTABLE_DIR"
echo "Restart your shell: exec bash -l"
echo ""
echo "To update later: $PORTABLE_DIR/update.sh"
echo ""
echo "To add work/databricks config: cp $PORTABLE_DIR/local.nix.example $PORTABLE_DIR/local.nix"
echo "Edit local.nix with your model names, SECRETS_DIR, and wrapper functions."
echo "Then run: $PORTABLE_DIR/update.sh"
