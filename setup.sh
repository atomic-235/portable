#!/usr/bin/env bash
# setup.sh — first-time install on fresh VM (NO ROOT REQUIRED)
# Uses nix-user-chroot for rootless nix via user namespaces
# Run: curl -fsSL https://raw.githubusercontent.com/atomic-235/portable/main/setup.sh | bash
set -uo pipefail
# NOTE: no `set -e` — we handle errors explicitly to avoid silent exits

PORTABLE_DIR="${PORTABLE_DIR:-$HOME/portable}"
NIX_USER_CHROOT_DIR="${NIX_USER_CHROOT_DIR:-$HOME/.nix}"
BIN_DIR="$HOME/.local/bin"
NUC="$BIN_DIR/nix-user-chroot"

echo "=== Checking user namespace support ==="
if ! unshare --user --pid echo OK &>/dev/null; then
  echo "ERROR: User namespaces not available on this system." >&2
  echo "nix-user-chroot requires unprivileged user namespaces." >&2
  echo "On Ubuntu 23.10+, this may be blocked by AppArmor." >&2
  exit 1
fi

echo "=== Installing nix-user-chroot ==="
mkdir -p "$BIN_DIR"
if [ ! -x "$NUC" ]; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  NP_ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) NP_ARCH="aarch64-unknown-linux-musl" ;;
    *) echo "ERROR: Unsupported arch: $ARCH" >&2; exit 1 ;;
  esac
  # Hardcoded version — avoids GitHub API rate limits on shared IPs
  NP_VERSION="2.1.1"
  echo "Downloading nix-user-chroot ${NP_VERSION} for ${NP_ARCH}..."
  if ! curl -fL "https://github.com/nix-community/nix-user-chroot/releases/download/${NP_VERSION}/nix-user-chroot-bin-${NP_VERSION}-${NP_ARCH}" \
    -o "$NUC" 2>&1; then
    echo "ERROR: Failed to download nix-user-chroot ${NP_VERSION}" >&2
    echo "Check if github.com is reachable from this network." >&2
    exit 1
  fi
  chmod +x "$NUC"
  echo "Installed nix-user-chroot ${NP_VERSION}"
fi

echo "=== Installing nix (rootless via nix-user-chroot) ==="
if [ ! -d "$NIX_USER_CHROOT_DIR/store" ]; then
  mkdir -m 0755 "$NIX_USER_CHROOT_DIR"
  "$NUC" "$NIX_USER_CHROOT_DIR" bash -c '
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
  '
else
  echo "nix already installed in $NIX_USER_CHROOT_DIR"
fi

echo "=== Enabling flakes ==="
mkdir -p "$NIX_USER_CHROOT_DIR/etc/nix"
if ! grep -q 'experimental-features' "$NIX_USER_CHROOT_DIR/etc/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$NIX_USER_CHROOT_DIR/etc/nix/nix.conf"
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
# Only remove nvim dir (HM can't overwrite dirs with symlinks)
# HM -b backup handles all other file conflicts automatically
rm -rf "$HOME/.config/nvim" 2>/dev/null || true
# Clear stale nix profiles from previous attempts
rm -rf "$HOME/.local/state/nix/profiles" 2>/dev/null || true
"$NUC" "$NIX_USER_CHROOT_DIR" bash -lc "
  cd \"$PORTABLE_DIR\"
  nix run .#hm -- switch --flake .#user --impure -b backup
"

echo ""
echo "=== Setup complete ==="
echo "Restart your shell: exec bash -l"
echo "To update later: $PORTABLE_DIR/update.sh"
echo ""
echo "To add work/databricks config: cp $PORTABLE_DIR/local.nix.example $PORTABLE_DIR/local.nix"
echo "Edit local.nix with your model names, SECRETS_DIR, and wrapper functions."
echo "Then run: $PORTABLE_DIR/update.sh"
