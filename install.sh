#!/usr/bin/env bash
# spread-your-claudes installer.
#
# Symlinks the lane wrappers onto your PATH, drops the budget engine and a
# starter config into place, and creates (never overwrites) the secret
# templates. Re-runnable and non-destructive: existing config/secrets are left
# alone. Nothing here contacts a network or touches a provider account.
#
#   ./install.sh            # install
#   PREFIX=~/bin ./install.sh   # symlink into a different bin dir
#   ./install.sh --copy    # copy the scripts instead of symlinking
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local/bin}"
LANES_DIR="${CLAUDE_LANES_DIR:-$HOME/.local/share/claude-lanes}"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-lanes"
SECRETS_DIR="$HOME/.config/secrets"
MODE="symlink"
[ "${1:-}" = "--copy" ] && MODE="copy"

say() { printf '  %s\n' "$*"; }

echo "spread-your-claudes -> installing"
echo

# 1. wrappers onto PATH
mkdir -p "$PREFIX"
for f in "$HERE"/bin/*; do
  b="$(basename "$f")"
  chmod +x "$f"
  if [ "$MODE" = copy ]; then
    cp "$f" "$PREFIX/$b"; say "copied  $PREFIX/$b"
  else
    ln -sfn "$f" "$PREFIX/$b"; say "linked  $PREFIX/$b -> $f"
  fi
done

# 2. budget engine + ledger dir
mkdir -p "$LANES_DIR/cooldowns"
for f in lib.sh budget.py record.py; do
  cp "$HERE/lib/$f" "$LANES_DIR/$f"; say "copied  $LANES_DIR/$f"
done
touch "$LANES_DIR/usage.jsonl"

# 3. starter budget config (never clobber an existing one)
mkdir -p "$CFG_DIR"
if [ -e "$CFG_DIR/budgets.json" ]; then
  say "kept    $CFG_DIR/budgets.json (already exists)"
else
  cp "$HERE/config/budgets.example.json" "$CFG_DIR/budgets.json"
  say "copied  $CFG_DIR/budgets.json (edit the caps to match your plans)"
fi

# 4. secret templates (never clobber; created empty for you to fill)
mkdir -p "$SECRETS_DIR"; chmod 700 "$SECRETS_DIR" 2>/dev/null || true
for ex in "$HERE"/secrets/*.env.example; do
  dst="$SECRETS_DIR/$(basename "${ex%.example}")"
  if [ -e "$dst" ]; then
    say "kept    $dst (already exists)"
  else
    cp "$ex" "$dst"; chmod 600 "$dst"
    say "created $dst (fill it in)"
  fi
done

echo
echo "next:"
case ":$PATH:" in
  *":$PREFIX:"*) : ;;
  *) echo "  - add $PREFIX to your PATH" ;;
esac
cat <<'EOF'
  - authenticate the lanes you want (see README "Set up each lane"):
      gemini      -> put an AI Studio key in ~/.config/secrets/gemini.env
      cursor      -> run: cursor-agent login
      codex       -> install + sign in to the Codex CLI
      geminiweb   -> optional/unofficial: see docs/COOKIES.md
  - smoke test:   gemini-think "reply with one word: PONG"
  - check budget: lane-budget
  - wire your agent: paste claude/CLAUDE.md.snippet into ~/.claude/CLAUDE.md
    and copy claude/skills/* into ~/.claude/skills/
EOF
