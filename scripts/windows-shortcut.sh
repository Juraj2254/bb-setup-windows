#!/usr/bin/env bash
# Put "bb.vbs" on the Windows desktop. Double-click starts bb in Ubuntu (hidden) and opens the browser.
set -euo pipefail
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
[ -x "$PS" ] || { echo "! PowerShell nije dostupan iz Ubuntua; preskačem prečac."; exit 1; }
DISTRO="${WSL_DISTRO_NAME:-Ubuntu-24.04}"
WIN_DESKTOP="$(cd /mnt/c && "$PS" -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')"
[ -n "$WIN_DESKTOP" ] || { echo "! Ne nalazim Windows radnu površinu."; exit 1; }
DESKTOP="$(wslpath -u "$WIN_DESKTOP")"
TARGET="$DESKTOP/bb.vbs"

python3 - "$TARGET" "$DISTRO" <<'PY'
import sys
target, distro = sys.argv[1], sys.argv[2]
vbs = r'''Option Explicit
' bb-setup: start bb in Ubuntu (WSL) and open it in the browser
Const BB_URL = "http://localhost:38886"
Const MAX_WAIT_SECONDS = 60
Dim shell, attempt
Set shell = CreateObject("WScript.Shell")

If Not IsBbReady() Then
  shell.Run "wsl.exe -d DISTRO -- bash -lc ""$HOME/.local/bin/bb-start""", 0, False
  For attempt = 1 To MAX_WAIT_SECONDS
    WScript.Sleep 1000
    If IsBbReady() Then Exit For
  Next
End If

If IsBbReady() Then
  shell.Run "rundll32.exe url.dll,FileProtocolHandler " & BB_URL, 0, False
Else
  shell.Popup "bb se nije pokrenuo. Otvori Ubuntu i upiši: bb-app start", 10, "bb", 16
End If
WScript.Quit 0

Function IsBbReady()
  IsBbReady = (shell.Run("curl.exe --silent --fail --max-time 2 --output NUL " & BB_URL, 0, True) = 0)
End Function
'''.replace("DISTRO", distro)
with open(target, "w", encoding="utf-16", newline="\r\n") as fh:  # WSH reads UTF-16 with BOM
    fh.write(vbs)
PY
echo "✔ Prečac na radnoj površini: $WIN_DESKTOP\\bb.vbs"
