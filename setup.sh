#!/usr/bin/env bash
# setup.sh — first-time install on fresh VM
# Uses Determinate Systems nix-installer (best nix installer, handles everything)
# Run: curl -fsSL https://raw.githubusercontent.com/atomic-235/portable/main/setup.sh | bash
set -uo pipefail

PORTABLE_DIR="${PORTABLE_DIR:-$HOME/portable}"

# --- step 1: install nix ---

echo "=== Installing nix ==="
if ! command -v nix &>/dev/null; then
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install
  # Source nix env
  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
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

# --- step 5: create activation script ---

echo "=== Creating activation script ==="
cat > "$PORTABLE_DIR/activate.sh" << 'BPEOF'
# Portable nix environment activation
# Add this to your ~/.bashrc:
#   [ -f ~/portable/activate.sh ] && source ~/portable/activate.sh
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
BPEOF

echo ""
echo "=== Setup complete ==="
echo ""
echo "Add this line to your ~/.bashrc to activate the environment:"
echo "  [ -f ~/portable/activate.sh ] && source ~/portable/activate.sh"
echo ""
echo "Then restart your shell: exec bash -l"
echo ""
echo "To update later: $PORTABLE_DIR/update.sh"
echo ""
echo "To add work/databricks config: cp $PORTABLE_DIR/local.nix.example $PORTABLE_DIR/local.nix"
echo "Edit local.nix with your model names, SECRETS_DIR, and wrapper functions."
echo "Then run: $PORTABLE_DIR/update.sh"
