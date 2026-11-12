#!/usr/bin/env bash
# Spoji GitHub projekt s bb-om i svim agentima: GitHub prijava, klon, git identitet, bb projekt, skillovi.
#
#   bash scripts/bb-projekt.sh VLASNIK/REPO [--dir MAPA]   # spoji (ponovno pokretanje samo osvježi)
#   bash scripts/bb-projekt.sh --no-login VLASNIK/REPO     # za agente: ne otvara prijavu, nego izađe s 4
#   bash scripts/bb-projekt.sh --add VLASNIK/REPO          # samo zapamti (check.sh ga onda prati)
#   bash scripts/bb-projekt.sh --status                    # stanje zapamćenih projekata
#
# Bez repozitorija za instalaciju:
#   curl -fsSL https://raw.githubusercontent.com/Juraj2254/bb-setup-windows/main/scripts/bb-projekt.sh | bash -s -- VLASNIK/REPO
#
# Exit 4: GitHub prijava treba korisnika (gh auth login). Exit 5: nema pristupa repozitoriju.
set -euo pipefail

# --- alati (samostalno, da radi i kroz curl | bash)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh" >/dev/null 2>&1; nvm use --silent default >/dev/null 2>&1 || true; fi
for d in "$HOME/.local/bin" "$HOME/.bb/bin"; do
  case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$d:$PATH" ;; esac
done
export PATH
DATA_DIR="${BB_DATA_DIR:-$HOME/.bb}"
LIST="$DATA_DIR/bb-setup/projekti.tsv"
BASE="${BB_PROJEKTI_DIR:-$HOME/projekti}"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { code="$1"; shift; printf '\n\033[31m✘ %s\033[0m\n' "$*" >&2; exit "$code"; }
has()  { command -v "$1" >/dev/null 2>&1; }

slug() {  # owner/repo from owner/repo, https://github.com/owner/repo(.git) or git@github.com:owner/repo.git
  local s="${1%/}"
  s="${s%.git}"; s="${s#https://github.com/}"; s="${s#http://github.com/}"; s="${s#git@github.com:}"; s="${s#github.com/}"
  case "$s" in */*) [ "${s#*/*/}" = "$s" ] && { printf '%s\n' "$s"; return 0; } ;; esac
  return 1
}

remember() {  # remember <owner/repo> <dir>
  mkdir -p "$(dirname "$LIST")"
  touch "$LIST"
  if ! awk -F'\t' -v r="$1" '$1 == r { f = 1 } END { exit !f }' "$LIST"; then
    printf '%s\t%s\n' "$1" "$2" >> "$LIST"
  fi
}

bb_project_for() {  # print the bb project id whose source path is <dir>
  bb project list --json 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1].rstrip("/")
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit()
for p in (d if isinstance(d, list) else d.get("projects", [])):
    for s in p.get("sources", []):
        if (s.get("path") or "").rstrip("/") == want:
            print(p["id"]); sys.exit()
' "$1" || true
}

gh_ok() { has gh && gh auth status --hostname github.com >/dev/null 2>&1; }

# --- argumenti
MODE=connect; REPO=""; DIR=""; LOGIN_OK=1
while [ $# -gt 0 ]; do
  case "$1" in
    --status) MODE=status ;;
    --add) MODE=add ;;
    --dir) shift; DIR="${1:-}" ;;
    --no-login) LOGIN_OK=0 ;;
    -h|--help) sed -n '2,12p' "$0" 2>/dev/null || true; exit 0 ;;
    *) REPO="$(slug "$1")" || die 2 "Nije GitHub repozitorij: $1 (primjer: Juraj2254/healthcare-hackaton-idea)" ;;
  esac
  shift
done

if [ "$MODE" = status ]; then
  [ -s "$LIST" ] || { echo "Nema zapamćenih GitHub projekata."; exit 0; }
  missing=0
  if gh_ok; then ok "GitHub: prijavljen kao $(gh api user --jq .login 2>/dev/null)"; else warn "GitHub nije prijavljen"; missing=1; fi
  while IFS="$(printf '\t')" read -r r d; do
    [ -n "$r" ] || continue
    if [ -d "$d/.git" ] && [ -n "$(bb_project_for "$d")" ]; then ok "$r → $d (bb projekt)"
    else warn "$r nije spojen → bash scripts/bb-projekt.sh $r"; missing=1; fi
  done < "$LIST"
  exit $missing
fi

[ -n "$REPO" ] || die 2 "Upotreba: bash scripts/bb-projekt.sh VLASNIK/REPO [--dir MAPA]"
NAME="${REPO#*/}"
DIR="${DIR:-$BASE/$NAME}"
DIR="${DIR%/}"
case "$DIR" in /*) ;; *) DIR="$PWD/$DIR" ;; esac

if [ "$MODE" = add ]; then
  remember "$REPO" "$DIR"
  ok "zapamćeno: $REPO → $DIR"
  exit 0
fi

for t in git curl python3; do has "$t" || die 1 "Nema $t: sudo apt-get install -y git curl python3"; done

# --- 1. GitHub CLI (bez sudo, u ~/.local)
say "1/5 GitHub CLI"
if has gh; then
  ok "gh $(gh --version | head -1 | awk '{print $3}')"
else
  case "$(uname -m)" in x86_64|amd64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; *) die 1 "Nepodržan procesor: $(uname -m)" ;; esac
  VER="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')" \
    || die 1 "Ne mogu dohvatiti verziju gh s GitHuba (internet?)"
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/cli/cli/releases/download/v$VER/gh_${VER}_linux_${ARCH}.tar.gz" | tar -xz -C "$TMP"
  mkdir -p "$HOME/.local/share" "$HOME/.local/bin"
  rm -rf "$HOME/.local/share/gh-cli"
  mv "$TMP/gh_${VER}_linux_${ARCH}" "$HOME/.local/share/gh-cli"
  rm -rf "$TMP"
  ln -sfn "$HOME/.local/share/gh-cli/bin/gh" "$HOME/.local/bin/gh"
  touch "$HOME/.bashrc"
  grep -q 'bb-setup: local bin' "$HOME/.bashrc" || printf '\n# bb-setup: local bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
  hash -r
  has gh || die 1 "gh nije instaliran"
  ok "gh $VER instaliran u ~/.local/bin/gh"
fi

# --- 2. prijava
say "2/5 GitHub prijava"
if ! gh_ok; then
  if [ "$LOGIN_OK" = 1 ] && ( : </dev/tty ) 2>/dev/null && [ -t 1 ]; then
    echo "  Prijavi se u preglednik. Ako se ne otvori, drži Ctrl i klikni link, pa upiši kod koji piše ovdje."
    gh auth login --hostname github.com --git-protocol https --web </dev/tty || true
  fi
  gh_ok || die 4 "GitHub prijava: u novom Ubuntu tabu (Ctrl + Shift + T) pokreni
    gh auth login --web --git-protocol https
  Enter na svim pitanjima, prijavi se u pregledniku i upiši kod. Zatim ponovno ovu skriptu."
fi
LOGIN="$(gh api user --jq .login)"
gh auth setup-git --hostname github.com >/dev/null
ok "prijavljen kao $LOGIN; git koristi gh za github.com"
if [ -z "$(git config --global user.name || true)" ]; then
  git config --global user.name "$(gh api user --jq '.name // .login')"
  ok "git user.name = $(git config --global user.name)"
fi
if [ -z "$(git config --global user.email || true)" ]; then
  git config --global user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
  ok "git user.email = $(git config --global user.email)"
fi

# --- 3. pristup
say "3/5 Pristup $REPO"
PERM="$(gh repo view "$REPO" --json viewerPermission --jq .viewerPermission 2>/dev/null || true)"
[ -n "$PERM" ] || die 5 "$LOGIN nema pristup $REPO. Vlasnik te mora dodati kao suradnika:
    https://github.com/$REPO/settings/access → Add people → $LOGIN
  Prihvati pozivnicu (e-mail ili https://github.com/$REPO/invitations), pa ponovno ovu skriptu."
case "$PERM" in
  ADMIN|MAINTAIN|WRITE) ok "pravo: $PERM (agenti mogu pushati)" ;;
  *) warn "pravo: $PERM. Agenti mogu čitati, ali ne i pushati. Vlasnik ti treba dati Write." ;;
esac

# --- 4. klon
say "4/5 Klon u $DIR"
if [ -d "$DIR/.git" ]; then
  have="$(slug "$(git -C "$DIR" remote get-url origin 2>/dev/null)" || true)"
  [ "$have" = "$REPO" ] || die 1 "$DIR je drugi repozitorij ($have). Izaberi drugu mapu: --dir MAPA"
  git -C "$DIR" fetch --quiet origin || warn "fetch nije uspio"
  if [ -n "$(git -C "$DIR" status --porcelain)" ]; then
    warn "u mapi ima nespremljenih promjena; ne diram ih"
  elif git -C "$DIR" rev-parse --verify --quiet HEAD >/dev/null && git -C "$DIR" rev-parse --verify --quiet '@{u}' >/dev/null; then
    git -C "$DIR" merge --ff-only --quiet '@{u}' && ok "osvježeno na $(git -C "$DIR" rev-parse --short HEAD)" \
      || warn "lokalna i GitHub verzija su se razišle; agent to rješava prema AGENTS.md projekta"
  else
    ok "već klonirano"
  fi
elif [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
  die 1 "$DIR postoji i nije prazna. Izaberi drugu mapu: --dir MAPA"
else
  mkdir -p "$(dirname "$DIR")"
  gh repo clone "$REPO" "$DIR" -- --quiet
  ok "klonirano"
fi
# skillovi iz repozitorija za sve agente: bb čita <projekt>/.bb/skills
if [ -d "$DIR/skills" ] && [ ! -e "$DIR/.bb/skills" ] && ls "$DIR"/skills/*/SKILL.md >/dev/null 2>&1; then
  mkdir -p "$DIR/.bb"
  ln -s ../skills "$DIR/.bb/skills"
  grep -qx '/.bb/skills' "$DIR/.git/info/exclude" 2>/dev/null || printf '/.bb/skills\n' >> "$DIR/.git/info/exclude"
  ok "skills/ → .bb/skills (samo lokalno)"
fi
remember "$REPO" "$DIR"

# --- 5. bb
say "5/5 bb projekt"
if ! has bb || ! bb status >/dev/null 2>&1; then
  warn "bb ne radi. Projekt je kloniran; pokreni bb (bb-start) i ponovno ovu skriptu."
  exit 1
fi
PID="$(bb_project_for "$DIR")"
if [ -n "$PID" ]; then
  ok "projekt već postoji u bb-u ($PID)"
else
  MACHINE="$(bb machine list --json 2>/dev/null | python3 -c '
import json, os, sys
try:
    ms = json.load(sys.stdin)
except ValueError:
    sys.exit()
ms = ms if isinstance(ms, list) else ms.get("machines", [])
p = os.path.join(sys.argv[1], "host-id")
hid = open(p).read().strip() if os.path.exists(p) else ""
ids = [m["id"] for m in ms if m.get("status") == "connected"]
print(hid if hid in ids else (ids[0] if len(ids) == 1 else ""))
' "$DATA_DIR" || true)"
  PID="$(bb project create --name "$NAME" --root "$DIR" ${MACHINE:+--machine "$MACHINE"} --json </dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')" || die 1 "bb projekt nije dodan"
  ok "dodan u bb: $NAME ($PID)"
fi

echo
for f in AGENTS.md CLAUDE.md .bb/AGENTS.md; do [ -f "$DIR/$f" ] && ok "agenti čitaju $f"; done
[ -d "$DIR/.bb/skills" ] && ok "skillovi projekta: $(ls -d "$DIR"/.bb/skills/*/ 2>/dev/null | wc -l)"
printf '\n  Gotovo. U bb-u otvori projekt \033[1m%s\033[0m i klikni New thread.\n' "$NAME"
printf '  Claude Code, Codex i Pi rade po pravilima iz repozitorija i sami pushaju na GitHub kao %s.\n' "$LOGIN"
