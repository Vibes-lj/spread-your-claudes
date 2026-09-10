#!/usr/bin/env bash
# Remove the spread-your-claudes wrappers and budget engine.
# Leaves your config, secrets, and usage ledger in place unless you pass --purge.
#
#   ./uninstall.sh           # remove wrappers + lib
#   ./uninstall.sh --purge   # also remove ~/.config/claude-lanes and the ledger
#                            # (never touches ~/.config/secrets)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"
LANES_DIR="${CLAUDE_LANES_DIR:-$HOME/.local/share/claude-lanes}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-lanes"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

for f in "$HERE"/bin/*; do
  b="$(basename "$f")"
  if [ -e "$PREFIX/$b" ] || [ -L "$PREFIX/$b" ]; then
    rm -f "$PREFIX/$b"; echo "  removed $PREFIX/$b"
  fi
done

for f in lib.sh budget.py record.py; do
  rm -f "$LANES_DIR/$f" && echo "  removed $LANES_DIR/$f" || true
done

if [ "$PURGE" = 1 ]; then
  rm -rf "$LANES_DIR" "$CFG_DIR"
  echo "  purged $LANES_DIR and $CFG_DIR"
  echo "  (left ~/.config/secrets alone -- delete those yourself if you want)"
else
  echo "  kept $LANES_DIR (ledger + cooldowns) and $CFG_DIR (budgets.json)"
fi
