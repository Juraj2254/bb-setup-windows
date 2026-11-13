# bb na Windowsu (Ubuntu / WSL): kompletan vodič korak po korak

Ovaj vodič te vodi kroz cijelu instalaciju, od Windowsa bez Ubuntua do bb-a s tri agenta, zajedničkom
memorijom, svim skillovima (i onima s Windowsa) i uvezenim starim kontekstom. Idi redom i kvačicom označi
svaki korak kad prođe njegova provjera.

**Kako čitati vodič**

- **PowerShell** ili **Ubuntu**: kopiraj cijeli sivi blok (na GitHubu gumb za kopiranje u gornjem desnom kutu
  bloka), zalijepi ga u taj prozor (**Ctrl + V** ili desni klik) i pritisni Enter.
- **Klik**: radiš mišem.
- **Provjera**: naredba i što mora pisati. Ne idi dalje dok provjera ne prođe.
- Sve naredbe smiješ pokrenuti ponovno. Ako je nešto već napravljeno, preskoče ga.
- CROZ VPN (u Windowsu) drži uključen od koraka 7 do kraja.

**Sadržaj**

- [A. Prije početka](#a-prije-početka)
- [B. Brzi put: sve odradi agent](#b-brzi-put-sve-odradi-agent)
- [C. Ručni put, korak po korak](#c-ručni-put-korak-po-korak)
- [D. Završna provjera](#d-završna-provjera)
- [E. Testovi u bb-u](#e-testovi-u-bb-u)
- [F. Svaki dan](#f-svaki-dan)
- [G. Kasnije: novi skillovi i projekti](#g-kasnije-novi-skillovi-i-projekti)
- [H. Ako nešto ne radi](#h-ako-nešto-ne-radi)
- [I. Što je gdje](#i-što-je-gdje)

---

## A. Prije početka

### A1. Računi i ključevi

- [ ] **Claude pretplata** (Pro ili Max). Provjera: na https://claude.ai si prijavljen i vidiš svoj plan.
- [ ] **ChatGPT pretplata** (Plus ili Pro). Provjera: na https://chatgpt.com si prijavljen.
- [ ] **Jarvis API ključ**: https://jarvis.croz.net/onboarder (stranica radi samo na CROZ mreži ili VPN-u).
      Ključ drži pri ruci, trebat će u koraku 7.
- [ ] **CROZ VPN** radi (spoji se jednom za probu).

### A2. Windows

- [ ] Windows 11 ili Windows 10 (verzija 22H2). **Klik**: Start → upiši `winver` → Enter.
- [ ] Imaš administratorska prava (PowerShell **Run as Administrator** mora raditi).
- [ ] Virtualizacija je uključena. **Klik**: **Ctrl + Shift + Esc** → **Performance** → **CPU** → dolje desno
      **Virtualization: Enabled**. Ako piše Disabled, vidi [H](#h-ako-nešto-ne-radi).

### A3. Pristup projektu

Repozitorij instalacije `bb-setup-windows` je javan. Za zajednički privatni Healthcare projekt prvo daj
pristup toj osobi:

- [ ] **Klik**: https://github.com/Juraj2254/healthcare-hackaton-idea → **Settings** → **Collaborators** →
      **Add people** → upiši GitHub korisničko ime → dodijeli **Write**. Osoba prihvati pozivnicu iz e-maila.

Druga mogućnost: ti preuzmeš ZIP (korak 3) i pošalješ ga (Teams, e-mail); osoba ga spremi u **Preuzimanja**.

---

## B. Brzi put: sve odradi agent

Ako želiš da instalaciju vodi agent, napravi samo ovo, a zatim idi na [D. Završna provjera](#d-završna-provjera).

1. [ ] Napravi korake [C1](#c1-ubuntu-wsl) i [C3](#c3-preuzmi-repozitorij) (samo preuzimanje ZIP-a, bez raspakiravanja).
2. [ ] **Ubuntu** (agent je Codex):

   ```sh
   python3 -m zipfile -e /mnt/c/Users/*/Downloads/bb-setup-windows-main.zip ~/ && bash ~/bb-setup-windows-main/bootstrap.sh
   ```

   Ako želiš da vodi Jarvis (CROZ Code, VPN mora biti uključen), umjesto gornje pokreni ovu:

   ```sh
   python3 -m zipfile -e /mnt/c/Users/*/Downloads/bb-setup-windows-main.zip ~/ && bash ~/bb-setup-windows-main/bootstrap.sh jarvis
   ```

3. [ ] Upiši Ubuntu lozinku kad je zatraži (osnovni alati).
4. [ ] U pregledniku se prijavi u ChatGPT (ili upiši Jarvis ključ). Ako se preglednik ne otvori, drži **Ctrl** i
       klikni link. Ako Codex pita vjeruješ li mapi, pritisni Enter.
5. [ ] Razgovaraj s agentom na hrvatskom. Kad traži prijavu ili klik, učini to i napiši `gotovo`.
6. [ ] Na kraju agent mora reći da `check.sh` ima sve ✔. Ipak prođi [D](#d-završna-provjera) i [E](#e-testovi-u-bb-u).

Za instalaciju s projektom Healthcare u naredbi iz koraka 2 na kraj dodaj
`Juraj2254/healthcare-hackaton-idea`. Agent će sam klonirati projekt, spojiti git i dodati projekt u bb.
U pregledniku potvrdi GitHub prijavu svojim računom; za zajednički rad Juraj ti treba dati **Write** pristup
projektu, a ti prihvati pozivnicu. Konfiguraciju agenata ne uređuješ ručno.

---

## C. Ručni put, korak po korak

### C1. Ubuntu (WSL)

Ako Ubuntu već imaš (Start → Ubuntu se otvara i traži naredbu), preskoči na C2.

- [ ] **Klik**: **Start** → upiši `powershell` → desni klik na **Windows PowerShell** → **Run as Administrator** → **Yes**.
- [ ] **PowerShell**:

  ```powershell
  wsl --install -d Ubuntu-24.04
  ```

- [ ] **Klik**: kad završi, ponovno pokreni računalo.
- [ ] Nakon restarta Ubuntu se otvori sam (ili Start → **Ubuntu 24.04 LTS**). Upiši korisničko ime (mala slova,
      bez razmaka), pa lozinku dvaput. Lozinka se ne vidi dok tipkaš. Zapamti je.
- [ ] **Provjera** (PowerShell, ne mora kao administrator):

  ```powershell
  wsl -l -v
  ```

  Red `Ubuntu-24.04` mora imati `VERSION 2`.

Od sada sve naredbe upisuješ u prozor **Ubuntu**, osim ako piše drugačije.

### C2. Osnovni alati

- [ ] **Ubuntu** (traži tvoju Ubuntu lozinku):

  ```sh
  sudo apt-get update && sudo apt-get install -y git curl python3 ca-certificates
  ```

- [ ] **Provjera**:

  ```sh
  git --version && python3 --version
  ```

### C3. Preuzmi repozitorij

- [ ] **Klik**: u Windows pregledniku otvori https://github.com/Juraj2254/bb-setup-windows → zeleni gumb
      **Code** → **Download ZIP**. Zip ostane u **Preuzimanjima** (Downloads); ne raspakiravaj ga.
- [ ] **Ubuntu**:

  ```sh
  python3 -m zipfile -e /mnt/c/Users/*/Downloads/bb-setup-windows-main.zip ~/
  ls ~/bb-setup-windows-main
  ```

  Moraju se vidjeti `AGENTS.md`, `bootstrap.sh`, `scripts`, `prompts`, `docs`.
  Ako javi grešku (više Windows korisnika), pogledaj ime s `ls /mnt/c/Users/` i zamijeni `*` tim imenom.

### C4. Node.js

- [ ] **Ubuntu**:

  ```sh
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
  ```

- [ ] **Klik**: zatvori prozor Ubuntu i otvori ga ponovno (Start → Ubuntu).
- [ ] **Ubuntu**:

  ```sh
  nvm install 24
  ```

- [ ] **Provjera**:

  ```sh
  node --version && npm --version
  ```

  Mora pisati `v24.…` i broj verzije npm-a.

### C5. Claude Code

- [ ] **Ubuntu**:

  ```sh
  curl -fsSL https://claude.ai/install.sh | bash
  grep -q 'bb-setup: local bin' ~/.bashrc || printf '\n# bb-setup: local bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> ~/.bashrc
  source ~/.bashrc
  claude --version
  ```

  Zadnji red mora ispisati verziju, npr. `2.1.… (Claude Code)`.
- [ ] **Prijava**:

  ```sh
  claude
  ```

  1. Na prvim pitanjima (tema, napomene) pritisni Enter.
  2. Izaberi **1. Claude account with subscription** i pritisni Enter.
  3. **Klik**: ako se preglednik ne otvori, drži **Ctrl** i klikni link u Ubuntuu. Prijavi se i klikni **Authorize**.
  4. Ako Claude traži kod: kopiraj ga iz preglednika, zalijepi u Ubuntu (desni klik) i pritisni Enter.
  5. `Login successful`: pritisni Enter. Ako pita vjeruješ li mapi, izaberi **Yes**.
  6. Upiši `/exit` i pritisni Enter.
- [ ] **Provjera**:

  ```sh
  claude auth status
  ```

  Mora pisati `"loggedIn": true`.

### C6. Codex

- [ ] **Ubuntu**:

  ```sh
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  source ~/.bashrc
  codex --version
  ```

- [ ] **Prijava**:

  ```sh
  codex login
  ```

  **Klik**: ako se preglednik ne otvori, drži **Ctrl** i klikni link. Prijavi se svojim ChatGPT računom.
  Ako prijava ne prođe, pokušaj s kodom: `codex login --device-auth` (otvori link i upiši prikazani kod).
- [ ] **Provjera**:

  ```sh
  codex login status
  ```

  Mora pisati `Logged in using ChatGPT`.

### C7. CROZ Code (VPN uključen u Windowsu)

- [ ] **Provjera VPN-a**:

  ```sh
  curl -sS -o /dev/null -w '%{http_code}\n' https://nexus.croz.net/repository/npm/
  ```

  Mora pisati `200`. Ako ne piše, uključi CROZ VPN i ponovi.
- [ ] **Ubuntu**:

  ```sh
  npm install -g @croz/croz-code --registry https://nexus.croz.net/repository/npm/
  croz-code --version
  ```

- [ ] **Jarvis ključ**:

  ```sh
  croz-code setup
  ```

  Kod `Jarvis API key:` zalijepi ključ (desni klik) i pritisni Enter. Mora pisati `✔ Saved. You are ready.`
- [ ] **Provjera**:

  ```sh
  croz-code doctor
  ```

  Linije `Jarvis` i `CROZ tools gateway` moraju imati ✔.

### C8. Most Pi → CROZ Code

bb-ov agent **Pi** tako pokreće CROZ Code.

- [ ] **Ubuntu**:

  ```sh
  cd ~/bb-setup-windows-main
  bash scripts/bb-pi-most.sh
  ```

  Mora pisati `✔ Most je spreman: /home/<ime>/.local/bin/pi (Pi 1.1.0)` (broj može biti drugačiji).

### C9. bb

- [ ] **Ubuntu**:

  ```sh
  cd ~/bb-setup-windows-main
  bash scripts/install-bb-wsl.sh
  ```

  Skripta instalira bb, pokrene ga u pozadini, napravi prečac **bb** na radnoj površini i otvori
  http://localhost:38886 u pregledniku. Na kraju mora pisati `✔ bb radi na http://localhost:38886` i
  `✔ Prečac na radnoj površini: …`.
- [ ] **Klik** u pregledniku (uvod):
  1. **Connect a coding agent**: Codex, Claude Code i Pi moraju pisati **Ready**. Klikni **Continue**.
     Ako neki ne piše Ready: u Ubuntuu `pkill -f "bb-app start"`, pa ponovno `bash scripts/install-bb-wsl.sh`.
  2. **Add your projects**: klikni **Import** (ili **Skip**; skripta u C10 doda stare projekte i s Windowsa).
  3. **Plugins** i **Devices**: **Continue** ili **Skip**.
- [ ] **Provjera**:

  ```sh
  bb status && bb provider list
  ```

  Na popisu moraju biti `codex`, `claude-code` i `pi`.

### C10. Zajednička memorija, skillovi i stari kontekst

- [ ] **Ubuntu**, prvo samo plan (ništa ne mijenja):

  ```sh
  cd ~/bb-setup-windows-main
  bash scripts/bb-harness.sh --dry-run
  ```

  Pročitaj popis: koji projekti (i s Windowsa, kao `/mnt/c/...`) i koliko skillova će ući.
- [ ] **Ubuntu**, pravo pokretanje:

  ```sh
  bash scripts/bb-harness.sh
  ```

  Na `Nastaviti? [D/n]` pritisni Enter. Skripta prolazi 7 koraka:

  1. most Pi → CROZ Code upisan u bb (`BB_PI_BRIDGE_COMMAND`);
  2. bb Memory plugin uključen;
  3. zasebne memorije Claude Codea, Codexa i CROZ Codea isključene;
  4. zajednička pravila u `~/.bb/AGENTS.md`;
  5. svi skillovi (Ubuntu i `C:\Users\<ime>\.claude`, `.codex`, `.agents`) u `~/.bb/skills` i Jarvis ključ u bb-u
     (za skill croz-tools);
  6. stari kontekst iz Ubuntua i s Windowsa u `~/.bb/legacy-context`;
  7. stari projekti dodani u bb i pokrenuti threadovi **Uvoz konteksta**.

  Na kraju mora pisati `==> Gotovo`.

### C11. Pričekaj uvoz

- [ ] **Klik**: u bb-u lijevo vidiš threadove **Uvoz konteksta · …** (jedan po projektu i jedan **globalno**).
      Svaki traje minutu ili dvije.
- [ ] Kad svi završe: **Settings → Installed plugins → Memory**. Mora biti popis memorija (Scope `global` i
      imena projekata).

---

## D. Završna provjera

- [ ] **Ubuntu**:

  ```sh
  bash ~/bb-setup-windows-main/scripts/check.sh
  ```

  Svaka linija mora imati ✔, a na kraju mora pisati `Sve je spremno.` Uz svaki ✘ piše što napraviti.

- [ ] **Ubuntu**, varijable u bb-u:

  ```sh
  bb machine env list
  ```

  Moraju postojati `BB_PI_BRIDGE_COMMAND`, `CROZ_MEMORY` i `JARVIS_API_KEY` (vrijednosti su skrivene).

- [ ] **Ubuntu**, memorija i skillovi:

  ```sh
  bb memory catalog | head -20
  bb skill list --json | python3 -c 'import json,sys; print(sum(1 for s in json.load(sys.stdin)["skills"] if s["scope"]=="bb-user"), "skillova za sve agente")'
  ```

- [ ] **Klik** u bb-u:
  - **Settings → Providers**: Codex, Claude Code i Pi su na popisu.
  - **Settings → Providers → Claude Code**: **Claude Code memory** je isključen.
  - **Settings → Providers → Codex**: **Codex memory** je isključen.
  - **Settings → Installed plugins → Memory**: plugin je uključen i ima memorije.
  - **Settings → Environment variables**: tri varijable iz provjere iznad.
- [ ] **Klik**: na Windows radnoj površini postoji **bb.vbs**.

---

## E. Testovi u bb-u

Za svaki test: **New thread** → klikni izbornik modela ispod polja za poruku → izaberi karticu agenta.

- [ ] **Pi (CROZ Code, VPN uključen)**: `Što znaš o meni i mojim projektima?`
      Mora odgovoriti iz zajedničke memorije (tvoj posao, tvoji projekti).
- [ ] **Zajednička memorija**:
  1. U threadu s **Codexom**: `Zapamti globalno: izvještaje želim kao tablicu.`
  2. U novom threadu s **Claude Codeom**: `Kako želim izvještaje?` Mora reći: kao tablicu.
- [ ] **Skill croz-tools u Claude Codeu** (VPN uključen): `Koristi skill croz-tools i pronađi na CROZ Confluenceu stranicu o VPN-u.`
- [ ] **Skillovi**: u polju za poruku upiši `/`. Moraju se pojaviti tvoji skillovi.

---

## F. Svaki dan

- [ ] Dvoklik na **bb** (bb.vbs) na radnoj površini. Pokrene bb u Ubuntuu i otvori preglednik.
- [ ] Za agenta **Pi** (CROZ Code) i skill croz-tools uključi CROZ VPN.

Bez prečaca: otvori Ubuntu, upiši `bb-start` (prozor ostavi otvoren) i u pregledniku otvori
http://localhost:38886.

Nova verzija bb-a: **Settings → Updates** → **Update**.

---

## G. Kasnije: novi skillovi i projekti

- **Dodao si nove skillove** u Claude Code, Codex ili CROZ Code (u Ubuntuu ili na Windowsu): kopiraj ih u bb
  bez novog uvoza konteksta.

  ```sh
  bash ~/bb-setup-windows-main/scripts/bb-harness.sh --no-import
  ```

- **Novi skill samo za bb**: spremi mapu skilla (s datotekom `SKILL.md`) u `~/.bb/skills/<ime-skilla>/`.
- **Novi projekt**: dodaj mapu u bb (**Settings → Projects**) ili iz Ubuntua:

  ```sh
  bb project create --name "ime-projekta" --root ~/putanja/do/mape
  ```

  Windows mapu dodaješ kao `/mnt/c/Users/<ime>/...`. Agenti sami pišu u memoriju dok rade na njoj.
- **Projekt s GitHuba** (npr. zajednički projekt s kolegom): jedna naredba ga klonira u `~/projekti/`, doda u bb
  i spoji git s tvojim GitHub računom. Prvi put se prijaviš u GitHub u pregledniku.

  ```sh
  bash ~/bb-setup-windows-main/scripts/bb-projekt.sh Juraj2254/healthcare-hackaton-idea
  ```

  Agenti rade po pravilima iz repozitorija (`AGENTS.md`, `CLAUDE.md`, `skills/`) i sami povlače i pushaju
  promjene. Za privatni repozitorij vlasnik te prvo doda pod **Settings → Collaborators**.
- **Ponovni uvoz starog konteksta** (npr. nakon puno rada izvan bb-a): pokreni `bb-harness.sh` bez opcija.
  Agenti neće upisati duplikate.

---

## H. Ako nešto ne radi

| Problem | Rješenje |
|---|---|
| `wsl --install`: greška 0x80370102 ili "virtualization" | U BIOS-u uključi virtualizaciju (Intel VT-x / AMD SVM). Zatim u PowerShellu (admin): `wsl --install -d Ubuntu-24.04`. |
| `wsl -l -v` pokazuje `VERSION 1` | PowerShell (admin): `wsl --set-version Ubuntu-24.04 2` |
| `command not found` odmah nakon instalacije | Zatvori prozor Ubuntu i otvori ga ponovno. |
| `nvm: command not found` | Ponovi C4 i otvori novi Ubuntu prozor. |
| Zip naredba javi grešku | `ls /mnt/c/Users/` i zamijeni `*` u naredbi svojim imenom. Provjeri da je zip u Preuzimanjima. |
| Preglednik se ne otvara za prijavu | Drži **Ctrl** i klikni link u Ubuntuu. Za Codex: `codex login --device-auth`. |
| `curl … nexus.croz.net` ne daje `200` | Uključi CROZ VPN u Windowsu. |
| `croz-code doctor`: Jarvis ✘ | VPN; zatim ponovno `croz-code setup` i zalijepi ključ. |
| U uvodu bb-a agent nije **Ready** | `pkill -f "bb-app start"`, pa `bash scripts/install-bb-wsl.sh`. Provjeri da C5 do C8 prolaze. |
| http://localhost:38886 se ne otvara | Dvoklik na **bb** na radnoj površini, ili u Ubuntuu `bb-start`. |
| Nema prečaca **bb** na radnoj površini | `bash ~/bb-setup-windows-main/scripts/windows-shortcut.sh` |
| Skripta kaže `bb ne odgovara` | `bash ~/bb-setup-windows-main/scripts/install-bb-wsl.sh` (pokrene bb). |
| Thread **Uvoz konteksta** traži odobrenje | Klikni **Allow**. |
| Pi ne radi u bb-u | VPN; zatim `~/.local/bin/pi --version` mora ispisati broj; ponovi C8 i C10. |
| `bb-projekt.sh` izađe s 4 | U novom Ubuntu tabu: `gh auth login --web --git-protocol https`, Enter na svim pitanjima, prijava u pregledniku. |
| `bb-projekt.sh` izađe s 5 | Vlasnik repozitorija te doda pod **Settings → Collaborators**; prihvati pozivnicu iz e-maila. |
| Bilo što drugo | `bash ~/bb-setup-windows-main/scripts/check.sh` i napravi ono što piše uz prvi ✘. |

---

## I. Što je gdje

`~` je tvoja Ubuntu mapa `/home/<ime>`. Iz Windows Explorera je vidiš na `\\wsl.localhost\Ubuntu-24.04\home\<ime>`.

| Što | Gdje |
|---|---|
| bb (program) | `~/.nvm/versions/node/v24.…/lib/node_modules/bb-app` |
| bb podaci, memorija, postavke | `~/.bb/` |
| Zajednička pravila za sve agente | `~/.bb/AGENTS.md` |
| Skillovi koje bb daje svim agentima | `~/.bb/skills/` (popis izvora: `~/.bb/skills/.bb-skills-import.json`) |
| Stari kontekst (sažeci) | `~/.bb/legacy-context/` |
| Pokretanje bb-a | `~/.local/bin/bb-start`, prečac `bb.vbs` na Windows radnoj površini |
| Most Pi → CROZ Code | `~/.local/bin/pi` |
| Claude Code, Codex | `~/.local/bin/claude`, `~/.local/bin/codex` |
| CROZ Code postavke i ključ | `~/.croz-code/agent/` |
| Skripte instalacije | `~/bb-setup-windows-main/scripts/` |
| Projekti s GitHuba | `~/projekti/<repo>` (popis: `~/.bb/bb-setup/projekti.tsv`) |
| Stari Claude i Codex na Windowsu (samo se čitaju) | `C:\Users\<ime>\.claude`, `C:\Users\<ime>\.codex` |
