#!/usr/bin/env bash
# Makes ~/.local/bin/pi, the bridge that lets bb's "Pi" agent run CROZ Code.
# bb checks the Pi version before it starts Pi. CROZ Code bundles Pi, so the bridge reports that
# version and hands every other call to croz-code. Safe to run again.
set -euo pipefail

PI_WRAPPER="${PI_WRAPPER_PATH:-$HOME/.local/bin/pi}"
MARK="# bb-harness: pi -> croz-code"

if [ -e "$PI_WRAPPER" ] && ! grep -q "$MARK" "$PI_WRAPPER" 2>/dev/null; then
  printf '! %s već postoji i nije iz ove skripte; ostavljam ga.\n' "$PI_WRAPPER"
  exit 0
fi
command -v croz-code >/dev/null 2>&1 || { printf '✘ Prvo instaliraj CROZ Code (croz-code).\n' >&2; exit 1; }

mkdir -p "$(dirname "$PI_WRAPPER")"
cat > "$PI_WRAPPER" <<'EOF'
#!/usr/bin/env bash
# bb-harness: pi -> croz-code
# bb's Pi provider checks the Pi version first; CROZ Code bundles Pi, so report that version
# and hand every other call to croz-code.
if [[ "$#" -eq 1 && ( "$1" == "--version" || "$1" == "-v" ) ]]; then
  exec node -p "require('$(npm root -g)/@croz/croz-code/node_modules/@earendil-works/pi-coding-agent/package.json').version"
fi
exec croz-code "$@"
EOF
chmod +x "$PI_WRAPPER"

v="$("$PI_WRAPPER" --version 2>/dev/null || true)"
if [ -n "$v" ]; then
  printf '✔ Most je spreman: %s (Pi %s)\n' "$PI_WRAPPER" "$v"
else
  printf '✘ %s --version ne radi. Provjeri: croz-code --version\n' "$PI_WRAPPER" >&2
  exit 1
fi
