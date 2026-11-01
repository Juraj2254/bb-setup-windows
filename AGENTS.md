# Runbook: bb on Windows in Ubuntu / WSL (for the installing agent)

You are installing **bb** (an agent IDE, https://getbb.app) for a CROZ colleague inside **Ubuntu on WSL**,
together with three agents and one shared memory. You run inside Ubuntu. You are Codex or Jarvis
(CROZ Code). Follow this runbook from top to bottom.

Goal, when you are done:

| In bb | Runs | Works on |
|---|---|---|
| Claude Code | Claude Code | the user's Claude subscription |
| Codex | Codex | the user's ChatGPT subscription |
| Pi | CROZ Code | Jarvis, the CROZ AI gateway (needs CROZ VPN) |

Plus: bb Memory (one memory for all agents), every skill from this computer in bb (Ubuntu and the Windows
profile), the user's earlier Claude Code / Codex / CROZ Code context imported into that memory, and a **bb**
shortcut on the Windows desktop.

## How to work with the user

- Speak **Croatian**, short and plain. The user is usually not a programmer.
- Run the steps yourself. Ask the user only for what you cannot do: browser sign-ins, clicks, typing a key
  or a password into their own Ubuntu window.
- When the user must act, give **one** clear instruction: which window, what to type or click, what they
  will see when it worked. Then wait for them to say they are done ("gotovo"), and verify.
- Never ask the user to paste a password, token or API key into this chat. Keys go only into the program
  that asks for them, in the user's own Ubuntu window.
- Every script here is safe to run again. If a step fails twice, stop, show the last lines of the error,
  and explain in one sentence what the user can do.
- Do not use `sudo` (the bootstrap already installed git, curl and python3). Do not delete or overwrite the
  user's files outside what these scripts do. Never touch Windows files except the desktop shortcut.

## How to run commands

Every command must start by loading the tools the scripts install (your shell does not read `~/.bashrc`):

```sh
. scripts/env.sh && <command>
```

Run commands from the folder that contains this file.

A new Ubuntu tab for the user: in the Ubuntu window press **Ctrl + Shift + T**. Paste there with **Ctrl + V**
or a right click. If a browser does not open by itself, the user holds **Ctrl** and clicks the link.

## Step 0 – Where are we?

```sh
. scripts/env.sh && bash scripts/check.sh
```

Every line is ✔ (done) or ✘ (missing, with the next action). Tell the user in three sentences what you will do,
then continue with the first ✘ step below. Run `check.sh` again after each step.

## Step 1 – Node.js

```sh
. scripts/env.sh && bash scripts/install-node.sh
```

## Step 2 – Install the agents

```sh
. scripts/env.sh && bash scripts/install-agents.sh
```

Exit code 3 means the CROZ Nexus is not reachable. Ask the user to turn on the **CROZ VPN** in Windows, then
run `bash scripts/install-agents.sh croz` again.

## Step 3 – Sign-ins (the user does these)

Check with `check.sh`. For each agent that is not signed in, ask the user to open a **new Ubuntu tab**
(Ctrl + Shift + T) and run one command there. Do them one at a time.

1. **Claude Code**: `claude`. On the first questions press Enter. Choose **Claude account with subscription**,
   sign in in the browser and click **Authorize**. If Claude asks for a code, the user copies it from the
   browser and pastes it into the Ubuntu tab. Then `/exit`.
   Verify: `claude auth status` shows `"loggedIn": true`.
2. **Codex** (skip if you are Codex, you are already signed in): `codex login`, sign in with ChatGPT.
   Verify: `codex login status`.
3. **CROZ Code** (VPN on): `croz-code setup`, paste the Jarvis API key from https://jarvis.croz.net/onboarder,
   press Enter. It must print `✔ Saved. You are ready.` Verify with `check.sh`.

## Step 4 – Bridge Pi → CROZ Code

```sh
. scripts/env.sh && bash scripts/bb-pi-most.sh
```

## Step 5 – bb

```sh
. scripts/env.sh && bash scripts/install-bb-wsl.sh
```

It installs bb, starts it in the background, puts a **bb** shortcut on the Windows desktop and opens
http://localhost:38886 in the Windows browser. Tell the user: "U pregledniku klikni **Continue** dok Codex,
Claude Code i Pi pišu **Ready**, a na ostalim koracima **Skip**."

If an agent is not Ready: stop bb (`pkill -f "bb-app start"`), run `bash scripts/install-bb-wsl.sh` again
(bb reads the tools when it starts), and check again.

## Step 6 – Shared memory, skills and the earlier context

```sh
. scripts/env.sh && bash scripts/bb-harness.sh --yes
```

It puts the Pi bridge into bb, turns on the bb Memory plugin, turns off the agents' separate memories, writes
the shared rules to `~/.bb/AGENTS.md`, copies every skill from Ubuntu and from the Windows profile
(`C:\Users\<name>\.claude`, `.codex`, `.agents`) into `~/.bb/skills` (bb gives them to every agent), gives bb the
Jarvis key so the `croz-tools` skill works in every agent, collects the earlier context from Ubuntu and from
Windows into `~/.bb/legacy-context`, adds the earlier projects to bb (Windows folders as `/mnt/c/...`) and starts
one "Uvoz konteksta" thread per project plus a global one. Those threads write the memories; they take a
minute or two each.

## Step 7 – Done

1. Run `check.sh`. Every line should be ✔.
2. Tell the user how to see the result: in bb, **Settings → Installed plugins → Memory** lists the memories.
3. Tell the user how to try it: in bb click **New thread**, open the model menu under the message box, choose
   the **Pi** tab (Jarvis Reason), and ask `Što znaš o meni i mojim projektima?`.
4. Every day: double-click **bb** on the Windows desktop (or open Ubuntu and run `bb-start`). For Pi (CROZ
   Code), turn on the VPN.

End with a short summary in Croatian: what is installed, what the user still has to do (if anything).
