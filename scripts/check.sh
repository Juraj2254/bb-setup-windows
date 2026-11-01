#!/usr/bin/env bash
# Where is the installation? One line per step: ✔ done, ✘ missing (with the next action).
# Only reads; never changes anything. Exit code 0 when every step is done, 1 otherwise.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
DATA_DIR="${BB_DATA_DIR:-$HOME/.bb}"
missing=0

to() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }   # timeout that also exists on macOS
ok()  { printf '✔ %s\n' "$*"; }
no()  { printf '✘ %s\n' "$*"; missing=$((missing + 1)); }
has() { command -v "$1" >/dev/null 2>&1; }

MAC=0; WSL=0
[ "$(uname -s)" = Darwin ] && MAC=1
grep -qi microsoft /proc/version 2>/dev/null && WSL=1

echo "== Sustav"
if [ $MAC = 1 ]; then
  ok "macOS $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"
  if xcode-select -p >/dev/null 2>&1; then ok "Command Line Tools (git, python3)"; else no "Command Line Tools → xcode-select --install i klikni Install"; fi
elif [ $WSL = 1 ]; then
  ok "Ubuntu u WSL-u ($WSL_DISTRO_NAME)"
  for t in git curl python3; do has $t && ok "$t" || no "$t → sudo apt-get install -y $t"; done
else
  ok "Linux"
fi

echo "== Node.js"
if has node && node --version | grep -Eq '^v(2[2-9]|[3-9][0-9])\.'; then ok "Node.js $(node --version)"; else no "Node.js 22+ → bash scripts/install-node.sh"; fi

echo "== Agenti"
if has claude; then
  if to 20 claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; then ok "Claude Code: prijavljen"
  else no "Claude Code nije prijavljen → korisnik u drugom prozoru: claude (Claude account with subscription), pa /exit"; fi
else no "Claude Code → bash scripts/install-agents.sh claude"; fi
if has codex; then
  if to 20 codex login status >/dev/null 2>&1; then ok "Codex: prijavljen"
  else no "Codex nije prijavljen → korisnik u drugom prozoru: codex login"; fi
else no "Codex → bash scripts/install-agents.sh codex"; fi
if has croz-code; then
  if python3 -c 'import json,os,sys; d=json.load(open(os.path.expanduser("~/.croz-code/agent/auth.json"))); sys.exit(0 if d.get("jarvis",{}).get("key") else 1)' 2>/dev/null; then
    ok "CROZ Code: Jarvis ključ spremljen"
  else no "CROZ Code nema Jarvis ključ → korisnik u drugom prozoru: croz-code setup"; fi
else no "CROZ Code → (uključi VPN) bash scripts/install-agents.sh croz"; fi
if [ -x "$HOME/.local/bin/pi" ] && v="$(to 30 "$HOME/.local/bin/pi" --version 2>/dev/null)" && [ -n "$v" ]; then
  ok "Most Pi → CROZ Code (Pi $v)"
else no "Most Pi → CROZ Code → bash scripts/bb-pi-most.sh"; fi

echo "== bb"
if [ $MAC = 1 ]; then
  if [ -d /Applications/bb.app ]; then ok "bb aplikacija u Applications"; else no "bb aplikacija → bash scripts/install-bb-mac.sh"; fi
else
  if has bb-app; then ok "bb-app $(npm ls -g bb-app 2>/dev/null | grep -o 'bb-app@[0-9.]*' | head -1)"; else no "bb → bash scripts/install-bb-wsl.sh"; fi
fi
BB_OK=0
if has bb && to 20 bb status >/dev/null 2>&1; then
  ok "bb radi i bb naredba je dostupna"; BB_OK=1
elif has bb; then
  if [ $MAC = 1 ]; then no "bb ne odgovara → otvori aplikaciju bb (open -a bb)"
  else no "bb ne radi → bash scripts/install-bb-wsl.sh (pokrene ga)"; fi
else
  if [ $MAC = 1 ]; then no "bb naredba → bash scripts/install-bb-mac.sh (instalira i bb CLI)"
  else no "bb naredba → bash scripts/install-bb-wsl.sh"; fi
fi

echo "== Harness"
if [ $BB_OK = 1 ]; then
  envnames="$(to 20 bb machine env list --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(" ".join(v.get("name","") for v in d.get("variables",[])))' 2>/dev/null)"
  case " $envnames " in *" BB_PI_BRIDGE_COMMAND "*) ok "BB_PI_BRIDGE_COMMAND u bb-u" ;; *) no "BB_PI_BRIDGE_COMMAND → bash scripts/bb-harness.sh" ;; esac
  if to 20 bb plugin list 2>/dev/null | grep -Eq '^memory@[^ ]+ +running'; then ok "bb Memory plugin radi"; else no "Memory plugin → bash scripts/bb-harness.sh"; fi
  if to 20 bb plugin config provider-claude-code 2>/dev/null | grep -q 'memoryEnabled = false'; then ok "zasebna Claude memorija isključena"; else no "zasebne memorije → bash scripts/bb-harness.sh"; fi
  n="$(to 30 bb skill list --json 2>/dev/null | python3 -c 'import json,sys; print(sum(1 for s in json.load(sys.stdin)["skills"] if s.get("scope") in ("bb-user","user")))' 2>/dev/null)"
  if [ -n "$n" ] && [ "$n" -gt 0 ]; then ok "skillovi u bb-u: $n"; else no "skillovi → bash scripts/bb-harness.sh"; fi
  case " $envnames " in *" JARVIS_API_KEY "*) ok "JARVIS_API_KEY u bb-u (croz-tools skill radi u svim agentima)" ;; *) no "JARVIS_API_KEY → bash scripts/bb-harness.sh (treba spremljen ključ iz croz-code setup)" ;; esac
else
  no "harness čeka da bb radi"
fi
if grep -q 'bb-harness:start' "$DATA_DIR/AGENTS.md" 2>/dev/null; then ok "zajednička pravila u ~/.bb/AGENTS.md"; else no "zajednička pravila → bash scripts/bb-harness.sh"; fi
if [ -f "$DATA_DIR/legacy-context/index.json" ]; then ok "stari kontekst skupljen (~/.bb/legacy-context)"; else no "stari kontekst → bash scripts/bb-harness.sh"; fi
if [ $BB_OK = 1 ]; then
  t="$(to 20 bb thread list 2>/dev/null | grep -c 'Uvoz konteksta')"
  if [ "${t:-0}" -gt 0 ]; then ok "threadovi Uvoz konteksta: $t (napredak vidiš u bb-u)"; else no "uvoz konteksta → bash scripts/bb-harness.sh"; fi
fi

echo
if [ $missing = 0 ]; then echo "Sve je spremno."; exit 0; fi
echo "Nedostaje: $missing"; exit 1
