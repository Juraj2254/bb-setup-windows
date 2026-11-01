#!/usr/bin/env bash
# Install the three agents: Claude Code, Codex and CROZ Code. Logins are separate (see AGENTS.md).
#   bash scripts/install-agents.sh            # all three
#   bash scripts/install-agents.sh claude     # only one: claude | codex | croz
# CROZ Code comes from the CROZ Nexus, so the CROZ VPN must be on for it. Safe to run again.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
WHICH="${1:-all}"
NEXUS="https://nexus.croz.net/repository/npm/"

case "$(uname -s)" in
  Darwin) RC="$HOME/.zshrc" ;;
  *) RC="$HOME/.bashrc" ;;
esac
touch "$RC"
grep -q 'bb-setup: local bin' "$RC" || printf '\n# bb-setup: local bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC"

want() { [ "$WHICH" = all ] || [ "$WHICH" = "$1" ]; }
status=0

if want claude; then
  if command -v claude >/dev/null 2>&1; then
    echo "✔ Claude Code je već instaliran ($(claude --version 2>/dev/null | head -1))"
  else
    echo "==> Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
    . "$HERE/env.sh"
    command -v claude >/dev/null 2>&1 && echo "✔ Claude Code instaliran" || { echo "✘ Claude Code nije instaliran"; status=1; }
  fi
fi

if want codex; then
  if command -v codex >/dev/null 2>&1; then
    echo "✔ Codex je već instaliran ($(codex --version 2>/dev/null | head -1))"
  else
    echo "==> Codex"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    . "$HERE/env.sh"
    command -v codex >/dev/null 2>&1 && echo "✔ Codex instaliran" || { echo "✘ Codex nije instaliran"; status=1; }
  fi
fi

if want croz; then
  if command -v croz-code >/dev/null 2>&1; then
    echo "✔ CROZ Code je već instaliran ($(croz-code --version 2>/dev/null | head -1))"
  elif ! command -v npm >/dev/null 2>&1; then
    echo "✘ Nema npm-a. Prvo: bash scripts/install-node.sh"; status=1
  elif ! curl -fsS -m 15 -o /dev/null "$NEXUS" 2>/dev/null; then
    echo "✘ CROZ Nexus nije dostupan. Uključi CROZ VPN i pokreni ponovno: bash scripts/install-agents.sh croz"
    status=3
  else
    echo "==> CROZ Code"
    npm install -g @croz/croz-code --registry "$NEXUS"
    . "$HERE/env.sh"
    command -v croz-code >/dev/null 2>&1 && echo "✔ CROZ Code instaliran" || { echo "✘ CROZ Code nije instaliran"; status=1; }
  fi
fi
exit $status
