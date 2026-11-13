# Project memory

- This repository installs bb, Claude Code, Codex and Pi through CROZ Code on Windows with Ubuntu/WSL.
- `bootstrap.sh [codex|jarvis] OWNER/REPO` remembers GitHub projects for the installing agent; `scripts/bb-projekt.sh` also works as a standalone script streamed to Bash.
- GitHub, ChatGPT and Claude sign-ins and Jarvis key entry belong to the user. Scripts automate agent configuration and GitHub credential integration.
- GitHub project onboarding requires Write permission, preserves unfinished work, and remembers a custom `--dir` across retries.
- bb discovers project skills from a real `.bb/skills/` directory. Healthcare tracks that directory with `skills` pointing to it. Never delete a tracked skill symlink during onboarding.
- `python3 -m unittest discover -s tests -v` tests project onboarding using real local Git clones and isolated GitHub/bb command doubles; it does not use account credentials or change the user's global git configuration.
- Used project skills and pinned provenance live in `skills/` and `skills/lock.json`. Task records live under `agent-memory/sessions/`.
