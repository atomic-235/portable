#!/usr/bin/env bash
# update.sh — zero-effort update for portable environment
# Run from anywhere: ~/portable/update.sh
set -euo pipefail

PORTABLE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Pulling latest portable ==="
git -C "$PORTABLE_DIR" pull --rebase

echo "=== Updating shared submodule ==="
git -C "$PORTABLE_DIR" submodule update --init --recursive

echo "=== Regenerating activate.sh ==="
cat > "$PORTABLE_DIR/activate.sh" << 'BPEOF'
if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
  . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if ! pgrep -x nix-daemon &>/dev/null; then
    sudo /nix/var/nix/profiles/default/bin/nix-daemon &>/dev/null &
    sleep 1
  fi
fi
BPEOF

echo "=== Applying home-manager config ==="
nix run "$PORTABLE_DIR"#hm -- switch --flake "$PORTABLE_DIR"#user --impure -b backup

echo ""
echo "=== Update complete ==="
echo "Restart your shell: exec bash -l"
