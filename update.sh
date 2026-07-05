#!/usr/bin/env bash
# update.sh — zero-effort update for portable environment (NO ROOT REQUIRED)
# Run from anywhere: ~/portable/update.sh
set -euo pipefail

PORTABLE_DIR="$(cd "$(dirname "$0")" && pwd)"
NIX_USER_CHROOT_DIR="${NIX_USER_CHROOT_DIR:-$HOME/.nix}"

echo "=== Pulling latest portable ==="
git -C "$PORTABLE_DIR" pull --rebase

echo "=== Updating shared submodule ==="
git -C "$PORTABLE_DIR" submodule update --remote --merge

echo "=== Updating flake lock ==="
nix-user-chroot "$NIX_USER_CHROOT_DIR" bash -lc "
  cd \"$PORTABLE_DIR\"
  nix --extra-experimental-features 'nix-command flakes' flake lock --update-input shared
"

echo "=== Applying home-manager config ==="
nix-user-chroot "$NIX_USER_CHROOT_DIR" bash -lc "
  cd \"$PORTABLE_DIR\"
  nix run .#hm -- switch --flake .#user --impure -b backup
"

echo ""
echo "=== Update complete ==="
echo "Restart your shell or run: exec bash -l"
