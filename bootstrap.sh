#!/usr/bin/env bash
# Prvi korak u Ubuntuu (WSL): instalira agenta koji odradi ostatak instalacije prema AGENTS.md.
#
#   bash bootstrap.sh          # instalacijski agent je Codex (ChatGPT pretplata)
#   bash bootstrap.sh jarvis   # instalacijski agent je Jarvis (CROZ Code, treba VPN)
#   bash bootstrap.sh VLASNIK/REPO [...]   # uz to spoji GitHub projekte (može i s jarvis)
set -euo pipefail
cd "$(dirname "$0")"
. scripts/env.sh
AGENT=codex
REPOS=""
for a in "$@"; do
  case "$a" in
    codex|jarvis) AGENT="$a" ;;
    */*) REPOS="$REPOS $a" ;;
    *) echo "Upotreba: bash bootstrap.sh [codex|jarvis] [VLASNIK/REPO ...]" >&2; exit 2 ;;
  esac
done

grep -qi microsoft /proc/version 2>/dev/null || { echo "✘ Pokreni ovo u Ubuntu prozoru (WSL)." >&2; exit 2; }

missing=""
for t in git curl python3; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
if [ -n "$missing" ]; then
  echo "==> Osnovni alati:$missing (upiši svoju Ubuntu lozinku kad je zatraži)"
  sudo apt-get update && sudo apt-get install -y$missing ca-certificates
fi

for r in $REPOS; do bash scripts/bb-projekt.sh --add "$r"; done

touch "$HOME/.bashrc"
grep -q 'bb-setup: local bin' "$HOME/.bashrc" || printf '\n# bb-setup: local bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"

case "$AGENT" in
  codex)
    bash scripts/install-agents.sh codex
    . scripts/env.sh
    if ! codex login status >/dev/null 2>&1; then
      echo "==> Prijava u Codex. Ako se preglednik ne otvori, drži Ctrl i klikni link."
      codex login
    fi
    echo "==> Pokrećem Codex. On nastavlja instalaciju i vodi te kroz korake."
    exec codex -s danger-full-access -a on-request -C "$PWD" "$(cat prompts/start.md)"
    ;;
  jarvis)
    bash scripts/install-node.sh
    . scripts/env.sh
    bash scripts/install-agents.sh croz
    . scripts/env.sh
    if ! python3 -c 'import json,os,sys; d=json.load(open(os.path.expanduser("~/.croz-code/agent/auth.json"))); sys.exit(0 if d.get("jarvis",{}).get("key") else 1)' 2>/dev/null; then
      echo "==> CROZ Code treba tvoj Jarvis API ključ (https://jarvis.croz.net/onboarder)."
      croz-code setup
    fi
    echo "==> Pokrećem Jarvis (CROZ Code). On nastavlja instalaciju i vodi te kroz korake."
    exec croz-code "$(cat prompts/start.md)"
    ;;
esac
