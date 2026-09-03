---
name: stage-my-changes
description: Stage only the edits Claude made this session, not the user's other uncommitted changes, even in the same files. Use when asked to stage before a commit.
---

# Stage my changes

From your own Edit/Write calls this session, list the files you changed. For each:

- Untracked file you created, or file whose every unstaged hunk is yours: `git add <file>`.
- File that also has hunks you did not write: `git add -p -- <file>` and accept only your hunks (`s` to split, `e` to hand-edit a mixed hunk). Non-interactively, write a patch of just your hunks and `git apply --cached` it.

Then show `git diff --cached --stat` and `git diff --stat` and confirm the staged set is yours only.

Never `git add -A`/`.`, `commit -a`, or `git stash`. If unsure a hunk is yours, leave it unstaged and say so.
