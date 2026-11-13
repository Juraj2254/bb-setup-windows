---
date: 2026-11-13T06:22:00Z
agent: codex
base_ref: a87a05f2c0f00183057aa4b330ebfe73f2640ff7
request: Complete automatic GitHub project connection for bb and all configured agents on Windows/WSL
---

# Request

Complete the interrupted request to provide a simple GitHub connection for the shared Healthcare configuration, bb, Claude Code, Codex and Pi through CROZ Code. Prepare the result in the Windows installer repository without manual agent configuration.

# Changes

- `scripts/bb-projekt.sh` — finish the existing uncommitted skill-directory fix while protecting tracked paths and local edits; validate arguments, require Write access, remember custom clone paths and fail clearly when fetch fails.
- `tests/test_bb_projekt.py` — regression coverage with actual local Git repositories and command doubles for GitHub/bb.
- `AGENTS.md`, `README.md`, `VODIC.md` — document the supported skill layout, browser authentication, project permissions and Healthcare bootstrap argument; correct installer repository visibility.
- `.gitignore` — exclude Python test caches.
- `skills/repo-sync/`, `skills/lock.json` — vendor the workflow used for this change with source revision.
- `agent-memory/` — record durable setup facts and this session.

# Decisions

- Preserve canonical tracked `.bb/skills/`; copy a plain `skills/` directory only when bb has no skill directory. Recover an old untracked symlink without overwriting local skill edits.
- Browser authentication and key entry stay with the user. No new manual agent configuration is required.
- Preserve the pre-existing untracked script backup; it is not part of this change.

# Skills used

- `repo-sync` — copied from `Juraj2254/healthcare-hackaton-idea`, `.bb/skills/repo-sync`, revision `e91f1939034570fd4b700da225b1d6cd59747fe0`.

# Validation

- `python3 -m unittest discover -s tests -v` — 12 tests passed, covering streamed execution, repeat runs, fast-forward updates, dirty work, custom paths, authentication/access failures, wrong repositories and skill symlink recovery/protection.
- `bash -n` — bootstrap and every shell script passed.
- Actual GitHub clone of the private Healthcare repository — clean worktree, instructions, project memory and both project skills present.
- Actual `bb-projekt.sh --no-login OWNER/REPO --dir EXISTING_CHECKOUT`, then `--status` — connected to the existing bb project successfully without creating a duplicate.
- `bb skill list --project PROJECT_ID --json` — both Healthcare skills discovered with no provider restriction.
- Fresh installation of all agent binaries and browser sign-ins on another computer — not run; requires that user's machine and accounts.

# Remaining work

- None in the onboarding change. Each new user must accept their project invitation and complete their own sign-ins.
