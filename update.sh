#!/usr/bin/env bash
# update.sh — zero-effort update for portable environment
# Run from anywhere: ~/portable/update.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Pulling latest portable ==="
# local.nix is gitignored — no conflicts ever
git pull --rebase

echo "=== Updating shared submodule ==="
git submodule update --remote --merge

echo "=== Updating flake lock ==="
nix --extra-experimental-features 'nix-command flakes' \
  flake lock --update-input shared

echo "=== Applying home-manager config ==="
nix run github:nix-community/home-manager -- \
  switch --flake .#user --impure -b backup

echo ""
echo "=== Update complete ==="
echo "Restart your shell or run: exec bash -l"
