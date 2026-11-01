#!/usr/bin/env bash
# bb harness: one shared memory and one set of skills for every agent in bb, plus a one-time
# import of the context that Claude Code, Codex and CROZ Code collected before bb.
#
#   bash scripts/bb-harness.sh             # do everything, ask once before changing anything
#   bash scripts/bb-harness.sh --dry-run   # only show what would happen
#
# Options: --yes  --no-import  --no-skills  --link-skills  --keep-croz-memory  --max-projects N
#          --provider claude-code|codex|pi   (agent for the import threads; default Claude Code, else Codex)
# Works with macOS bash 3.2 and Linux / WSL bash. Safe to run again.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/env.sh"
DATA_DIR="${BB_DATA_DIR:-$HOME/.bb}"
PI_WRAPPER="${PI_WRAPPER_PATH:-$HOME/.local/bin/pi}"
LEGACY="$DATA_DIR/legacy-context"
PROVIDER=""
MAX_PROJECTS=12
DRY_RUN=0
ASSUME_YES=0
DO_IMPORT=1
KEEP_CROZ_MEMORY=0
DO_SKILLS=1
LINK_SKILLS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --no-import) DO_IMPORT=0 ;;
    --keep-croz-memory) KEEP_CROZ_MEMORY=1 ;;
    --no-skills) DO_SKILLS=0 ;;
    --link-skills) LINK_SKILLS=1 ;;
    --max-projects) shift; MAX_PROJECTS="$1" ;;
    --provider) shift; PROVIDER="$1" ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Nepoznata opcija: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '  [proba] %s\n' "$*"; else "$@"; fi; }
has()  { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ 0. provjere
say "Provjera"
has bb || die "Nema naredbe bb.
  Mac: bash scripts/install-bb-mac.sh
  Windows (Ubuntu): bash scripts/install-bb-wsl.sh"
bb status >/dev/null 2>&1 || die "bb ne odgovara.
  Mac: otvori aplikaciju bb (open -a bb).
  Windows (Ubuntu): bash scripts/install-bb-wsl.sh"
ok "bb radi"
has python3 || die "Nema python3. Mac: xcode-select --install. Ubuntu: sudo apt install -y python3"
for tool in node npm claude codex croz-code; do
  if has "$tool"; then ok "$tool"; else warn "$tool nije instaliran (vidi vodič)"; fi
done
case "$(uname -s)" in
  Darwin) PLATFORM="Mac" ;;
  *) if grep -qi microsoft /proc/version 2>/dev/null; then PLATFORM="Windows (WSL)"; else PLATFORM="Linux"; fi ;;
esac
ok "Sustav: $PLATFORM"
if [ -z "$PROVIDER" ]; then
  if has claude && claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; then PROVIDER="claude-code"; else PROVIDER="codex"; fi
fi

printf '\nSkripta će:\n'
printf '  1. napraviti most Pi → CROZ Code (%s) i upisati ga u bb\n' "$PI_WRAPPER"
printf '  2. uključiti bb Memory plugin (zajednička memorija za sve agente)\n'
printf '  3. isključiti zasebne memorije Claude Codea i Codexa%s u bb-u\n' "$([ "$KEEP_CROZ_MEMORY" = 1 ] || echo ' i CROZ Codea')"
printf '  4. upisati zajednička pravila u %s/AGENTS.md\n' "$DATA_DIR"
[ "$DO_SKILLS" = 1 ] && printf '  5. kopirati skillove svih agenata u %s/skills (bb ih daje svim agentima)\n' "$DATA_DIR"
if [ "$DO_IMPORT" = 1 ]; then
  printf '  6. skupiti stari kontekst u %s\n' "$LEGACY"
  printf '  7. dodati stare projekte u bb i pokrenuti threadove "Uvoz konteksta" (%s)\n' "$PROVIDER"
fi
if [ "$ASSUME_YES" != 1 ] && [ "$DRY_RUN" != 1 ]; then
  printf '\nNastaviti? [D/n] '
  read -r answer </dev/tty || answer=""
  case "$answer" in n|N|ne|Ne|NE) echo "Prekinuto."; exit 0 ;; esac
fi

# ------------------------------------------------------------------ 1. most Pi -> CROZ Code
say "1/7 Most Pi → CROZ Code"
if [ "$DRY_RUN" = 1 ]; then
  printf '  [proba] bash %s/bb-pi-most.sh\n' "$HERE"
else
  PI_WRAPPER_PATH="$PI_WRAPPER" bash "$HERE/bb-pi-most.sh" | sed 's/^/  /' || warn "most nije napravljen (je li CROZ Code instaliran?)"
fi
if [ "$DRY_RUN" != 1 ] && [ ! -x "$PI_WRAPPER" ]; then
  warn "BB_PI_BRIDGE_COMMAND preskočen dok most ne postoji (instaliraj CROZ Code, pa pokreni ponovno)"
elif printf '%s\n' "$PI_WRAPPER" | ([ "$DRY_RUN" = 1 ] && cat >/dev/null || bb machine env set BB_PI_BRIDGE_COMMAND \
     --note "bb Pi pokreće CROZ Code (bb-harness)" >/dev/null 2>&1); then
  ok "BB_PI_BRIDGE_COMMAND = $PI_WRAPPER"
else
  warn "Upiši ručno: bb → Settings → Environment variables → Add variable"
  warn "  ime BB_PI_BRIDGE_COMMAND, vrijednost $PI_WRAPPER, pa Save variables"
fi

# ------------------------------------------------------------------ 2. Memory plugin
say "2/7 Zajednička memorija (bb Memory plugin)"
if bb plugin list 2>/dev/null | grep -q '^memory@'; then
  run bb plugin enable memory >/dev/null 2>&1 || true
else
  run bb plugin install memory --yes >/dev/null 2>&1 || run bb plugin enable memory >/dev/null 2>&1 \
    || die "Memory plugin se nije uključio. U bb-u: Settings → Plugin marketplaces → Memory → Install."
fi
ok "Memory plugin uključen"

# ------------------------------------------------------------------ 3. zasebne memorije isključene
say "3/7 Jedna memorija umjesto tri"
run bb plugin config provider-claude-code set memoryEnabled false >/dev/null && ok "Claude Code memory: isključeno"
run bb plugin config provider-codex set memoryEnabled false >/dev/null && ok "Codex memory: isključeno"
if [ "$KEEP_CROZ_MEMORY" != 1 ]; then
  if printf '0\n' | ([ "$DRY_RUN" = 1 ] && cat >/dev/null || bb machine env set CROZ_MEMORY \
       --note "CROZ Code u bb-u koristi bb Memory (bb-harness)" >/dev/null 2>&1); then
    ok "CROZ Code memorija u bb-u: isključeno (CROZ_MEMORY=0)"
  else
    warn "CROZ_MEMORY nije postavljen; dodaj ga ručno u Settings → Environment variables (vrijednost 0)"
  fi
fi

# ------------------------------------------------------------------ 4. zajednička pravila
say "4/7 Zajednička pravila za sve agente"
AGENTS="$DATA_DIR/AGENTS.md"
BLOCK_FILE="$(mktemp)"
cat > "$BLOCK_FILE" <<EOF
<!-- bb-harness:start -->
# Zajednička pravila za sve agente u bb-u

- Odgovaraj na hrvatskom, jasno i bez nepotrebnog žargona. Korisnik možda nije programer.
- Zajednička memorija je bb Memory plugin. Claude Code, Codex i CROZ Code dijele je preko naredbe \`bb memory\`.
  - Katalog memorija je u tvojim uputama. Kad je nešto od toga važno, pročitaj ga: \`bb memory search "<tema>" --scope all\`.
  - Kad naučiš nešto trajno korisno, spremi to: činjenice o projektu s \`--scope project\`, osobne želje s \`--scope global\`.
  - Ne spremaj tajne, lozinke ni API ključeve.
- Skillovi svih agenata su u \`$DATA_DIR/skills\` i bb ih daje svakom agentu. Novi skill spremi tamo.
- Stari kontekst od prije bb-a sažet je u \`$LEGACY\` (global.md i projects/). Pogledaj ga kad trebaš povijest.
- Skill croz-tools (CROZ Confluence, GitLab, kolege, službeni dokumenti, web) radi u svim agentima preko Jarvisa.
- CROZ Code (agent Pi) radi na Jarvisu i treba CROZ mrežu ili VPN.
<!-- bb-harness:end -->
EOF
BLOCK="$(cat "$BLOCK_FILE")"
rm -f "$BLOCK_FILE"
if [ "$DRY_RUN" = 1 ]; then
  printf '  [proba] upiši blok u %s\n' "$AGENTS"
else
  mkdir -p "$DATA_DIR"
  if [ -f "$AGENTS" ] && grep -q 'bb-harness:start' "$AGENTS"; then
    python3 - "$AGENTS" "$BLOCK" <<'PY'
import re, sys
path, block = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
text = re.sub(r"<!-- bb-harness:start -->.*?<!-- bb-harness:end -->", lambda m: block, text, flags=re.S)
open(path, "w", encoding="utf-8").write(text)
PY
  else
    { [ -s "$AGENTS" ] && printf '\n'; printf '%s\n' "$BLOCK"; } >> "$AGENTS"
  fi
fi
ok "$AGENTS"

# ------------------------------------------------------------------ 5. skillovi
if [ "$DO_SKILLS" = 1 ]; then
  say "5/7 Skillovi svih agenata u bb-u"
  SK_ARGS="--dest $DATA_DIR/skills"
  [ "$DRY_RUN" = 1 ] && SK_ARGS="$SK_ARGS --dry-run"
  [ "$LINK_SKILLS" = 1 ] && SK_ARGS="$SK_ARGS --link"
  python3 "$HERE/bb-skills.py" $SK_ARGS
  if [ "$DRY_RUN" != 1 ]; then
    n="$(bb skill list --json 2>/dev/null | python3 -c 'import json,sys; print(sum(1 for s in json.load(sys.stdin)["skills"] if s.get("scope") in ("bb-user","user")))' 2>/dev/null || echo "?")"
    ok "bb vidi $n skillova za sve agente"
  fi
  # croz-tools (Confluence, GitLab, kolege, dokumenti) needs JARVIS_API_KEY in every agent's environment
  if python3 -c 'import json,os,sys; d=json.load(open(os.path.expanduser("~/.croz-code/agent/auth.json"))); sys.exit(0 if d.get("jarvis",{}).get("key") else 1)' 2>/dev/null; then
    if bb machine env list --json 2>/dev/null | grep -q '"JARVIS_API_KEY"'; then
      ok "JARVIS_API_KEY je već u bb-u"
    elif [ "$DRY_RUN" = 1 ]; then
      printf '  [proba] JARVIS_API_KEY iz croz-code setup → bb (za croz-tools skill)\n'
    elif python3 -c 'import json,os; print(json.load(open(os.path.expanduser("~/.croz-code/agent/auth.json")))["jarvis"]["key"])' \
         | bb machine env set JARVIS_API_KEY --note "Jarvis ključ za croz-tools skill (bb-harness)" >/dev/null 2>&1; then
      ok "JARVIS_API_KEY upisan u bb (croz-tools skill radi u svim agentima)"
    else
      warn "JARVIS_API_KEY nije upisan; dodaj ga ručno u Settings → Environment variables"
    fi
  else
    warn "CROZ Code još nema Jarvis ključ (croz-code setup); croz-tools skill radit će tek nakon toga"
  fi
fi

if [ "$DO_IMPORT" != 1 ]; then
  say "Gotovo (bez uvoza starog konteksta)"
  exit 0
fi

# ------------------------------------------------------------------ 5. stari kontekst
say "6/7 Skupljam stari kontekst (Claude Code, Codex, CROZ Code)"
python3 "$HERE/bb-kontekst.py" --out "$LEGACY" --max-projects "$MAX_PROJECTS"
ok "spremljeno u $LEGACY"

# ------------------------------------------------------------------ 6. projekti i threadovi za uvoz
say "7/7 Projekti u bb-u i uvoz u memoriju"
# the machine bb runs on (the CLI fallback can pick the wrong one when several bb data dirs exist)
MACHINE="$(bb machine list --json 2>/dev/null | python3 -c '
import json, os, sys
try:
    ms = json.load(sys.stdin)
except ValueError:
    sys.exit()
ms = ms if isinstance(ms, list) else ms.get("machines", [])
hid = ""
p = os.path.join(sys.argv[1], "host-id")
if os.path.exists(p):
    hid = open(p).read().strip()
ids = [m["id"] for m in ms if m.get("status") == "connected"]
print(hid if hid in ids else (ids[0] if len(ids) == 1 else ""))
' "$DATA_DIR" || true)"
MACHINE_ARGS=""
[ -n "$MACHINE" ] && MACHINE_ARGS="--machine $MACHINE"
PLAN="$LEGACY/plan.tsv"
bb project list --json > "$LEGACY/bb-projects.json"
python3 - "$LEGACY/index.json" "$LEGACY/bb-projects.json" > "$PLAN" <<'PY'
import json, sys
index = json.load(open(sys.argv[1], encoding="utf-8"))
data = json.load(open(sys.argv[2], encoding="utf-8"))
projects = data if isinstance(data, list) else data.get("projects", [])
def key(p):
    p = p.rstrip("/")
    return p.lower() if p.startswith("/mnt/") else p
known = {}
for pr in projects:
    for src in pr.get("sources", []):
        if src.get("path"):
            known[key(src["path"])] = pr["id"]
for p in index["projects"]:
    print("\t".join([known.get(key(p["path"]), "-"), p["name"], p["path"], p["file"]]))
PY

PROMPTS="$LEGACY/prompts"
mkdir -p "$PROMPTS"
render() {  # render <template> <out> NAME PATH FILE
  python3 - "$1" "$2" "$3" "$4" "$5" "$LEGACY/index.json" <<'PY'
import sys
tpl, out, name, path, file, index = sys.argv[1:7]
text = open(tpl, encoding="utf-8").read()
for k, v in (("{{NAME}}", name), ("{{PATH}}", path), ("{{FILE}}", file), ("{{INDEX}}", index)):
    text = text.replace(k, v)
open(out, "w", encoding="utf-8").write(text)
PY
}

spawn() {  # spawn <project-id> <title> <prompt-file>
  if [ "$DRY_RUN" = 1 ]; then
    printf '  [proba] bb thread spawn --project %s --provider %s --title "%s"\n' "$1" "$PROVIDER" "$2"
    return 0
  fi
  bb thread spawn --project "$1" --provider "$PROVIDER" --permission-mode full $MACHINE_ARGS \
    --title "$2" --prompt-file "$3" --json </dev/null >/dev/null && ok "pokrenut thread: $2" \
    || warn "thread nije pokrenut: $2 (pokreni ga ručno s promptom iz $3)"
}

FIRST_ID=""
n=0
while IFS="$(printf '\t')" read -r pid name path file <&3; do
  [ -n "$path" ] || continue
  if [ "$pid" = "-" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      printf '  [proba] bb project create --name "%s" --root "%s"\n' "$name" "$path"
      pid="proj_proba$n"
    else
      pid="$(bb project create --name "$name" --root "$path" $MACHINE_ARGS --json </dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')" \
        || { warn "projekt nije dodan: $path"; continue; }
      ok "dodan projekt: $name ($path)"
    fi
  else
    ok "projekt već postoji: $name"
  fi
  [ -n "$FIRST_ID" ] || FIRST_ID="$pid"
  slug="$(basename "$file" .md)"
  render "$ROOT/prompts/uvoz-projekt.md" "$PROMPTS/$slug.md" "$name" "$path" "$file"
  spawn "$pid" "Uvoz konteksta · $name" "$PROMPTS/$slug.md"
  n=$((n + 1))
done 3< "$PLAN"

render "$ROOT/prompts/uvoz-globalno.md" "$PROMPTS/_globalno.md" "" "" "$LEGACY/global.md"
if [ -z "$FIRST_ID" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    FIRST_ID="proj_proba"
  else
    FIRST_ID="$(bb project create --name "Moj rad" --root "$HOME" $MACHINE_ARGS --json </dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
    ok "dodan projekt: Moj rad ($HOME)"
  fi
fi
spawn "$FIRST_ID" "Uvoz konteksta · globalno" "$PROMPTS/_globalno.md"

say "Gotovo"
printf '  U bb-u se vrte threadovi "Uvoz konteksta". Kad završe, memorije su u\n'
printf '  Settings → Installed plugins → Memory.\n'
printf '  Skripta i stari kontekst su u: %s\n' "$LEGACY"
