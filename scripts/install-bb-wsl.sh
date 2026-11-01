#!/usr/bin/env bash
# Install bb in Ubuntu (WSL), start it in the background, open it in the Windows browser and put a
# "bb" shortcut on the Windows desktop for every day. Safe to run again.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
PORT="${BB_PORT:-38886}"            # test hooks: BB_PORT, BB_SETUP_NO_SHORTCUT=1, BB_SETUP_NO_BROWSER=1
URL="http://localhost:$PORT"
START_ARGS=""
[ "$PORT" != 38886 ] && START_ARGS="--server-port $PORT --host-daemon-port $((PORT + 1))"

command -v npm >/dev/null 2>&1 || { echo "✘ Nema npm-a. Prvo: bash scripts/install-node.sh" >&2; exit 1; }

if command -v bb-app >/dev/null 2>&1; then
  echo "✔ bb je već instaliran"
else
  echo "==> Instaliram bb"
  # npm 11+ skips dependency build scripts unless allowed; bb needs these three native modules
  npm install -g bb-app --allow-scripts=better-sqlite3,node-pty,@parcel/watcher
  . "$HERE/env.sh"
fi

# bb-start: loads nvm and PATH, then runs bb in the foreground (used by the desktop shortcut)
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/bb-start" <<'EOF'
#!/usr/bin/env bash
# bb-setup: start bb with the same tools as an interactive Ubuntu window
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"
exec bb-app start "$@"
EOF
chmod +x "$HOME/.local/bin/bb-start"
echo "✔ ~/.local/bin/bb-start"

up() { curl -fs -o /dev/null -m 3 "$URL"; }
if up; then
  echo "✔ bb već radi na $URL"
else
  echo "==> Pokrećem bb u pozadini"
  setsid -f "$HOME/.local/bin/bb-start" $START_ARGS >"$HOME/.bb-start.log" 2>&1 </dev/null
  printf '    čekam'
  for _ in $(seq 1 60); do up && break; printf '.'; sleep 2; done
  echo
  up && echo "✔ bb radi na $URL" || { echo "✘ bb nije krenuo. Zapis: ~/.bb-start.log"; exit 1; }
fi

if [ "${BB_SETUP_NO_SHORTCUT:-0}" != 1 ]; then
  bash "$HERE/windows-shortcut.sh" || echo "! Prečac na radnoj površini nije napravljen (nije nužno)."
fi

CMD=/mnt/c/Windows/System32/cmd.exe
if [ "${BB_SETUP_NO_BROWSER:-0}" = 1 ]; then
  echo "Otvori u pregledniku: $URL"
elif [ -x "$CMD" ]; then
  (cd /mnt/c && "$CMD" /c start "" "$URL" >/dev/null 2>&1) || true
  echo "✔ Otvoren preglednik: $URL"
else
  echo "Otvori u pregledniku: $URL"
fi
. "$HERE/env.sh"
bb status >/dev/null 2>&1 && echo "✔ bb naredba radi" || echo "! bb naredba još ne odgovara; pričekaj pa: bb status"
echo
echo "U pregledniku klikni kroz uvod (Continue ili Skip setup)."
