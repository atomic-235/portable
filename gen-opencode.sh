#!/usr/bin/env bash
# Regenerate opencode.json from the dotfiles config, minus Venice.
#
# Run this from a machine that has both repos; the output is committed to
# portable so VMs get it through git and never need dotfiles. The dotfiles
# config is the source of truth, and portable has no Venice proxy, so
# `myprovider` (Venice) and everything that depends on it is stripped:
#   * the provider block and its enabled_providers entry
#   * the venice-mcp server (`mcp.ai`, which runs under with-nono)
#   * ai_venice_* tool permissions
# The default model falls back to the Databricks one portable actually uses.
# LSP stanzas come from shared/opencode/opencode-lsp.json, same as the dotfiles
# build does through the shared module's personalConfigFile merge.
#
# Usage: ./gen-opencode.sh [dotfiles-opencode.json] [shared-opencode-lsp.json]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-$HOME/projects/personal/dotfiles/opencode/.config/opencode/opencode.json}"
LSP="${2:-$HERE/submodules/shared/opencode/opencode-lsp.json}"
OUT="$HERE/opencode.json"

for f in "$SRC" "$LSP"; do
  [[ -f "$f" ]] || {
    echo "error: not found: $f" >&2
    exit 1
  }
done

jq --slurpfile lsp "$LSP" '
  .provider |= del(.myprovider)
  | .enabled_providers -= ["myprovider", "venice"]
  | del(.mcp.ai)
  | .permission |= with_entries(select(.key | startswith("ai_venice_") | not))
  | .model = "ega-databricks-uae/databricks-claude-sonnet-4-6"
  | .lsp = $lsp[0].lsp
' "$SRC" >"$OUT"

echo "wrote $OUT"
