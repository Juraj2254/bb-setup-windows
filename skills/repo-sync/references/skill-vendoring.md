# Skill vendoring

Vendor a skill when it guides project work. The project copy lets future agents use the same procedure without access to the original computer.

## Copy a skill

1. Resolve the skill's canonical source directory. Prefer the maintained source over a generated runtime copy.
2. Inspect `SKILL.md`, scripts, references, assets, and the license for unexpected behavior and credentials.
3. Copy the complete skill to `skills/SKILL_NAME/`.
4. Exclude caches, evaluation workspaces, local configuration, absolute machine paths, and credentials.
5. Keep the original name and directory structure.
6. Record the upstream repository, source path, and full commit hash in `skills/lock.json`.
7. Validate the frontmatter and referenced resource paths.

Use the project's copy when it already exists and matches the required version. Record a local modification when the copied skill differs from its upstream source. Do not overwrite project changes during an update.

## Handle unavailable sources

Find an official source when a built-in skill has no readable local directory. Pin the copy to a full upstream commit hash.

Stop and report the missing provenance when no official or readable source exists. Do not claim that a skill was vendored from an unverified copy.

## Record used skills

List each used skill in the session record, including project-local skills. A project-local skill needs no second copy. Its use still belongs in the session record so future agents can reconstruct the workflow.
