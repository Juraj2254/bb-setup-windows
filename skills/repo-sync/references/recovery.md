# Synchronization recovery

Use these procedures when the normal synchronization procedure cannot continue. Preserve intentional work in every procedure.

## Dirty worktree

Inspect `git diff` and `git status --short`. Treat existing modifications as incomplete work from an earlier task.

Finish and publish that work before starting a new request when its owner and intended outcome are clear. Otherwise, stop and ask the owner how to proceed. Do not hide work with automatic stash operations.

When the remote branch advanced and local files are modified, do not merge into the dirty worktree. Complete the local change first or ask the owner.

## Diverged branches

Finish the current atomic change and create its local commit. Run `git fetch origin`, then run `git merge --no-edit origin/BRANCH`.

Resolve conflicts by preserving both sides' intentional changes. Run all relevant validation after the merge. Push only after the merged state passes validation.

Use a temporary worktree or a separate clone when a task needs remote code before the local change can finish. Do not discard local commits to simplify history.

## Rejected push

Run `git fetch origin` after a non-fast-forward rejection. Merge the remote branch, resolve conflicts, validate the result, and push again.

Stop after repeated rejection or an unclear conflict. Report the current local and remote commit hashes. Never use `--force` or `--force-with-lease` for this workflow.

For an authentication or permission error, keep the local commit. Report the failed command and required access change. Do not claim synchronization completed.

## Empty repository

Continue when `git fetch origin` succeeds but the remote branch does not exist. Use `unborn` as the base reference. Create the first commit and run `git push -u origin HEAD`.

Stop when the remote contains commits that are unrelated to the local history. Ask the owner before joining those histories.
