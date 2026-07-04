#!/usr/bin/env bash
set -euo pipefail

# Container-based test for portable flake
# Tests: fresh nix install + home-manager switch with shared modules
# Simulates: SSH into fresh VM, clone portable, apply config

BASE_IMAGE="docker.io/nixos/nix:latest"

echo "=== Running container test (simulates fresh VM) ==="

podman run --rm -i \
    --network host \
    -v "$(pwd):/portable:Z" \
    "$BASE_IMAGE" bash -c '
set -euo pipefail

# Unset proxy vars that leak from host
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY 2>/dev/null || true

# Enable flakes
mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Simulate: user clones portable to ~/portable with shared submodule
export HOME=/root
export USER=root
mkdir -p $HOME
cd $HOME

echo "=== Clone portable with shared submodule ==="
git clone --recursive https://github.com/atomic-235/portable portable
ls -la portable/submodules/shared/nvim/init.lua

echo "=== Nix version ==="
nix --version

echo "=== Home-manager switch ==="
cd $HOME/portable
nix run github:nix-community/home-manager -- switch --flake .#user 2>&1

echo "=== Verify symlinks ==="
echo "nvim:"
ls -la $HOME/.config/nvim 2>&1
echo "btop:"
ls -la $HOME/.config/btop/btop.conf 2>&1
echo "starship:"
ls -la $HOME/.config/starship.toml 2>&1
echo "lazygit:"
ls -la $HOME/.config/lazygit/config.yml 2>&1
echo "direnv:"
ls -la $HOME/.config/direnv/lib/hm-nix-direnv.sh 2>&1

echo "=== Verify nvim symlink is writable ==="
test -w $HOME/.config/nvim/lazy-lock.json && echo "lazy-lock.json writable: YES" || echo "lazy-lock.json writable: NO"

echo "=== Verify lazygit config has content ==="
head -5 $HOME/.config/lazygit/config.yml

echo "=== ALL TESTS PASSED ==="
'
