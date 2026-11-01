# bb na Windowsu (Ubuntu / WSL)

Instalaciju bb-a odradi AI agent (Codex ili Jarvis). Ti pokreneš Ubuntu, jednu naredbu, prijaviš se gdje te
pita i klikneš što ti kaže.

Na kraju imaš **bb** u pregledniku (prečac **bb** na radnoj površini) s tri agenta i jednom zajedničkom
memorijom:

| Agent u bb-u | Što pokreće | Na čemu radi |
|---|---|---|
| Claude Code | Claude Code | tvoja Claude pretplata |
| Codex | Codex | tvoja ChatGPT pretplata |
| Pi | CROZ Code | Jarvis, CROZ AI gateway |

- **Zajednička memorija (bb Memory).** Svi agenti čitaju i pišu istu memoriju, globalnu i po projektu.
- **Svi skillovi na jednom mjestu.** Skillovi iz Claude Codea, Codexa i CROZ Codea, i u Ubuntuu i na Windowsu
  (`C:\Users\<ime>\.claude`, `.codex`, `.agents`), kopiraju se u bb i rade u svim agentima. Skill
  **croz-tools** (CROZ Confluence, GitLab, kolege, službeni dokumenti) tada radi i u Claude Codeu i Codexu.
- **Stari kontekst.** Ono što su agenti dosad naučili o tebi i tvojim projektima, i na Windowsu, uvozi se u
  memoriju.

## Prije početka

- Claude pretplata (Pro ili Max) i ChatGPT pretplata (Plus ili Pro).
- Jarvis API ključ: https://jarvis.croz.net/onboarder
- CROZ VPN je uključen.

## 1. Ubuntu (jednom)

1. Klikni **Start**, upiši `powershell` i izaberi **Run as Administrator**.
2. Upiši i pritisni Enter:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

3. Ponovno pokreni računalo. Ubuntu se otvori sam: izaberi korisničko ime i lozinku (lozinka se ne vidi dok
   tipkaš).

Ako već imaš Ubuntu u WSL-u, preskoči ovaj korak.

## 2. Pokretanje

1. Na ovoj stranici klikni **Code → Download ZIP**. Zip ostaje u Preuzimanjima (Downloads).
2. Otvori **Ubuntu** (Start → Ubuntu).
3. Zalijepi ovu naredbu (**Ctrl + V** ili desni klik) i pritisni Enter:

   ```sh
   python3 -m zipfile -e /mnt/c/Users/*/Downloads/bb-setup-windows-main.zip ~/ && bash ~/bb-setup-windows-main/bootstrap.sh
   ```

   Ubuntu traži tvoju lozinku za osnovne alate.
4. Codex se instalira i otvori preglednik: prijavi se svojim ChatGPT računom. Ako se preglednik ne otvori,
   drži **Ctrl** i klikni link.
5. Ako Codex pita vjeruješ li ovoj mapi, potvrdi (Enter). Codex preuzima. Razgovaraj s njim na hrvatskom. Kad te zamoli da se negdje prijaviš ili nešto klikneš,
   učini to i napiši mu `gotovo`.

Želiš li da instalaciju vodi **Jarvis** (CROZ Code) umjesto Codexa, na kraju naredbe dodaj `jarvis`:
`bash ~/bb-setup-windows-main/bootstrap.sh jarvis`

## Što agent napravi

1. Provjeri stanje: `scripts/check.sh`.
2. Node.js: `scripts/install-node.sh`.
3. Claude Code, Codex i CROZ Code: `scripts/install-agents.sh`.
4. Zamoli te da se prijaviš u Claude Code i CROZ Code (Jarvis ključ upisuješ samo ti, u svoj Ubuntu).
5. Most Pi → CROZ Code: `scripts/bb-pi-most.sh`.
6. bb, pokretanje i prečac na radnoj površini: `scripts/install-bb-wsl.sh`.
7. Zajednička memorija, skillovi i uvoz starog konteksta: `scripts/bb-harness.sh`.

Upute za agenta su u [AGENTS.md](AGENTS.md). Bez agenta: [docs/RUCNO.md](docs/RUCNO.md).
Video ručnog postupka: [docs/bb-windows-wsl-480p.mp4](docs/bb-windows-wsl-480p.mp4).

## Svaki dan

Dvoklik na **bb** na radnoj površini. Otvori se preglednik s bb-om. Za agenta Pi (CROZ Code) uključi VPN.

## Ako nešto zapne

- Gdje je instalacija: `bash ~/bb-setup-windows-main/scripts/check.sh`
- Pokreni `bootstrap.sh` ponovno: agent nastavlja od prvog koraka koji nije gotov.
- Ako zip naredba javi grešku jer na računalu ima više Windows korisnika, zamijeni `*` svojim imenom iz
  `ls /mnt/c/Users/`.
- Memorije vidiš i uređuješ u bb-u: **Settings → Installed plugins → Memory**.
