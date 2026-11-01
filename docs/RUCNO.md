# Ručna instalacija na Windowsu (bez agenta)

Isti koraci koje inače odradi agent, u prozoru **Ubuntu**. Svaku naredbu zalijepi (**Ctrl + V** ili desni
klik) i pritisni Enter. Skripte se smiju pokretati više puta: preskoče ono što je već gotovo.

Ubuntu (WSL) mora biti instaliran (README, korak 1).

## 1. Mapa i osnovni alati

```sh
python3 -m zipfile -e /mnt/c/Users/*/Downloads/bb-setup-windows-main.zip ~/
cd ~/bb-setup-windows-main
sudo apt-get update && sudo apt-get install -y git curl python3
```

## 2. Node.js i agenti (VPN uključen)

```sh
bash scripts/install-node.sh
bash scripts/install-agents.sh
```

Zatvori prozor Ubuntu, otvori ga ponovno i vrati se u mapu:

```sh
cd ~/bb-setup-windows-main
```

## 3. Prijave

```sh
claude
```

Na prvim pitanjima pritisni Enter, izaberi **Claude account with subscription**, u pregledniku klikni
**Authorize** (ako Claude traži kod, kopiraj ga iz preglednika i zalijepi u Ubuntu), pa upiši `/exit`.

```sh
codex login
croz-code setup
```

Za `croz-code setup` zalijepi Jarvis API ključ (https://jarvis.croz.net/onboarder).

## 4. Most, bb i harness

```sh
bash scripts/bb-pi-most.sh
bash scripts/install-bb-wsl.sh
```

U pregledniku (http://localhost:38886) klikni **Continue** dok Codex, Claude Code i Pi pišu **Ready**, a ostalo
**Skip**. Zatim:

```sh
bash scripts/bb-harness.sh
```

Na pitanje `Nastaviti? [D/n]` pritisni Enter.

## 5. Provjera

```sh
bash scripts/check.sh
```

Sve linije trebaju imati ✔. U bb-u: **Settings → Installed plugins → Memory** (memorije), a u novom threadu
izaberi **Pi** i pitaj `Što znaš o meni i mojim projektima?`.

## Svaki dan

Dvoklik na **bb** na Windows radnoj površini. Bez prečaca: otvori Ubuntu i upiši `bb-start`, pa u
pregledniku otvori http://localhost:38886.

## Što koja skripta radi

| Skripta | Što radi |
|---|---|
| `check.sh` | samo čita i ispiše stanje svakog koraka |
| `install-node.sh` | nvm i Node.js 24, bez sudo |
| `install-agents.sh` | Claude Code, Codex, CROZ Code (s CROZ Nexusa) |
| `bb-pi-most.sh` | `~/.local/bin/pi`: bb-ov agent Pi pokreće CROZ Code |
| `install-bb-wsl.sh` | bb, `bb-start`, pokretanje u pozadini, prečac **bb** na radnoj površini |
| `windows-shortcut.sh` | samo prečac **bb.vbs** na Windows radnoj površini |
| `bb-harness.sh` | Memory plugin, zajednička pravila, skillovi u `~/.bb/skills`, Jarvis ključ za croz-tools, uvoz starog konteksta (i s Windowsa) |
| `bb-skills.py` | kopira skillove iz Ubuntua i Windows profila u bb (originale ne dira) |
| `bb-kontekst.py` | skuplja stari kontekst iz Ubuntua i s Windowsa (samo čita, tajne zamaskira) |

Opcije harnessa: `--dry-run` (samo pokaže plan), `--no-import`, `--no-skills`, `--link-skills` (poveže bb
skillove natrag u `~/.claude/skills` i `~/.agents/skills`), `--keep-croz-memory`, `--max-projects N`,
`--provider claude-code|codex|pi`.
