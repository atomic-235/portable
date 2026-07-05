#!/usr/bin/env bash
# update.sh — zero-effort update for portable environment
# Run from anywhere: ~/portable/update.sh
set -euo pipefail

PORTABLE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Pulling latest portable ==="
git -C "$PORTABLE_DIR" pull --rebase

echo "=== Updating shared submodule ==="
git -C "$PORTABLE_DIR" submodule update --remote --merge

echo "=== Updating flake lock ==="
nix --extra-experimental-features 'nix-command flakes' \
  flake lock --update-input shared "$PORTABLE_DIR"

echo "=== Applying home-manager config ==="
nix run "$PORTABLE_DIR"#hm -- switch --flake "$PORTABLE_DIR"#user --impure -b backup

echo "=== Regenerating activate.sh ==="
cat > "$PORTABLE_DIR/activate.sh" << 'BPEOF'
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
  . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if ! pgrep -x nix-daemon &>/dev/null; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon &>/dev/null &
    sleep 1
  fi
fi
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
BPEOF

echo "=== Updating opencode ==="
# nixpkgs opencode segfaults on WSL2 — use prebuilt binary
# Don't fail the whole script if install fails (network issues, etc)
curl -fsSL https://opencode.ai/install | bash || echo "opencode install skipped (already installed or network error)"

echo ""
echo "=== Update complete ==="
echo "Restart your shell: exec bash -l"
