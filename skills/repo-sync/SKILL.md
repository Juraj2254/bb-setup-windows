---
name: repo-sync
description: Synchronize project code, vendored agent skills, and repository-backed memory across collaborators and agents. Use for every change in a repository that requires agents to fetch the latest commit before editing, preserve used skills, record project context, and commit and push each completed atomic change.
---

# Repo sync

Keep code, project memory, and used skills in the same commit. Other agents receive the full task context when they clone or update the repository.

An **atomic change** is one completed request or an independently useful part of a request. It leaves the repository in a working state. Commit each atomic change instead of committing every intermediate file save.

## Start an atomic change

Complete this procedure before editing files:

1. Run `git status --short --branch` and `git branch --show-current`.
2. Inspect the worktree. Preserve existing work and follow `references/recovery.md` when the repository is dirty or diverged.
3. Run `git fetch origin`.
4. Fast-forward the current branch with `git merge --ff-only origin/BRANCH` when the remote branch exists and local history permits it.
5. Read `agent-memory/MEMORY.md` and every record under `agent-memory/sessions/`.
6. Read recent commits with `git log --oneline -20`. Inspect older commits when a task needs their exact changes.
7. Record the current commit hash as the task's base reference. Use `unborn` when the repository has no commits.

The agent now has the latest remote state and the project context. Begin implementation only after these steps pass.

## Preserve used skills

A skill is used when its `SKILL.md` or bundled resources guide project work. Include every used skill in the change that relied on it.

Read `references/skill-vendoring.md` before copying a skill. Store each skill under `skills/SKILL_NAME/` and record its source in `skills/lock.json`.

Project copies are the canonical skills for later agents. Do not depend on a global installation on one computer.

## Record project memory

Create one session record for each atomic change. Use a unique path:

`agent-memory/sessions/YYYY-MM-DD/AGENT-TIMESTAMP-TASK.md`

Copy `references/session-template.md` and complete every section. Include the request, changed files, decisions, used skills, validation, and unresolved work.

Update `agent-memory/MEMORY.md` only with durable project facts and decisions. Keep task-specific detail in the session record. Git history preserves the exact diff for every committed change.

Record project context, not conversation transcripts. Never record credentials, private data, unrelated global memory, or ephemeral file contents.

## Publish an atomic change

1. Run the relevant validation. Fix failures before committing.
2. Review `git status --short` and `git diff`.
3. Stage explicit paths with `git add -- PATHS`.
4. Run `git diff --cached --check` and inspect `git diff --cached`.
5. Include code, used skills, and memory updates in the same commit.
6. Commit with a focused message using `git commit -m "TYPE: SUMMARY"`.
7. Run `git fetch origin` again.
8. Integrate new remote commits with `git merge --no-edit origin/BRANCH` when needed.
9. Resolve conflicts without discarding either collaborator's intentional work. Follow `references/recovery.md` for merge handling.
10. Run validation again after a merge.
11. Push with `git push -u origin HEAD`.
12. Confirm a clean worktree with `git status --short --branch`.

Report the pushed commit hash, validation results, and remaining blockers. If authentication or policy prevents a commit or push, preserve the completed work and report the exact blocked step.

Never force a push to make synchronization succeed.

## Read failure procedures

Read `references/recovery.md` before acting on a dirty worktree, diverged branches, merge conflicts, a rejected push, an empty remote, or an unavailable skill source.
