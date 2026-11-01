#!/usr/bin/env bash
# Node.js 24 through nvm, without sudo. Safe to run again.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVM_VERSION="v0.40.8"

case "$(uname -s)" in
  Darwin) RC="$HOME/.zshrc" ;;
  *) RC="$HOME/.bashrc" ;;
esac
touch "$RC"   # nvm's installer only writes its loader into an rc file that exists

if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  echo "==> nvm $NVM_VERSION"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | PROFILE="$RC" bash
fi
. "$HERE/env.sh"
command -v nvm >/dev/null 2>&1 || { echo "✘ nvm se nije učitao. Zatvori terminal, otvori ga ponovno i pokreni opet." >&2; exit 1; }

if ! node --version 2>/dev/null | grep -Eq '^v(2[2-9]|[3-9][0-9])\.'; then
  echo "==> Node.js 24"
  nvm install 24
  nvm alias default 24 >/dev/null
fi
. "$HERE/env.sh"
echo "✔ Node.js $(node --version), npm $(npm --version)"
