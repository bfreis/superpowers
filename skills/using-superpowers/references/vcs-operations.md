# VCS Operations Reference

Skills describe VCS operations abstractly. Use the column matching your VCS (injected as `VCS: git` or `VCS: jj` in session context) for concrete commands.

## Key Conceptual Differences

Before using the command table, understand how the two VCS models differ:

- **No staging area in jj.** The working copy is automatically tracked. `jj describe` sets the commit message for the current change; `jj new` starts a new change on top. Together they replace git's add/commit workflow.
- **Bookmarks, not branches.** jj "bookmarks" map to git branches on push, but they're optional — jj works with anonymous revisions by default. You only need a bookmark when pushing to a remote or naming a ref.
- **Change IDs, not SHAs.** jj identifies revisions by change ID (a stable identifier that survives rewrites). Review commands use revision expressions (`@` for the current change, `@-` for its parent, `trunk()` for the main branch, change IDs) rather than SHA ranges.
- **Ranges differ.** git uses `A..B` two-dot ranges. jj's `jj diff -r <rev>` shows the changes a *single* revision introduces — it is NOT a range. To see the cumulative diff between two revisions, use `jj diff --from <A> --to <B>` (or `jj diff -r 'A..B'`).
- **Workspaces don't auto-create named refs.** Unlike git worktrees (which require a branch), jj workspaces create a new working copy at a revision. Create a bookmark explicitly if you want a named ref.

## Operation Mapping

| Operation | git | jj |
|-----------|-----|-----|
| **Workspace isolation** | | |
| Detect project root | `git rev-parse --show-toplevel` | `jj root` |
| Create isolated workspace | `git worktree add "$path" -b "$BRANCH"` | `jj workspace add "$path"` |
| Remove workspace | `git worktree remove "$path"` | `jj workspace forget "$workspace_name" && rm -rf "$path"` |
| List workspaces | `git worktree list` | `jj workspace list` |
| Check if in linked workspace | `GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)` / `GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)` / compare: `GIT_DIR != GIT_COMMON` | `jj workspace list` lists every workspace by name (the original is `default`). You are in a linked workspace if you started from one you created with `jj workspace add` — track that path. Removing it is what cleanup does. |
| **Branching & bookmarks** | | |
| Create named ref | `git checkout -b "$name"` | `jj bookmark create "$name" -r @` |
| Current ref name | `git branch --show-current` | `jj bookmark list -r @` (bookmarks pointing at the current change) |
| Determine base | `git merge-base HEAD main` | `jj log -r 'trunk()' --no-graph --no-pager -T 'change_id.short() ++ "\n"' \| head -1` |
| **History & review** | | |
| Show diff for range | `git diff "$BASE..$HEAD"` | `jj diff --from "$BASE" --to "$HEAD"` (NOT `-r "$rev"` — that is a single revision) |
| Diff stats for range | `git diff --stat "$BASE..$HEAD"` | `jj diff --stat --from "$BASE" --to "$HEAD"` |
| Show single revision's diff | `git show "$rev"` | `jj diff -r "$rev"` |
| Log recent history | `git log --oneline` | `jj log --no-pager` |
| Current revision identifier | `git rev-parse HEAD` | `jj log -r @ --no-graph --no-pager -T 'change_id.short() ++ "\n"' \| head -1` |
| **Committing** | | |
| Stage and commit | `git add <files> && git commit -m "msg"` | `jj describe -m "msg" && jj new` |
| **Integration** | | |
| Merge to base | `git checkout "$base" && git merge "$feature"` | Fast-forward the base bookmark: `jj bookmark set "$base" -r "$feature_head"`. For an explicit merge commit instead: `jj new "$base_rev" "$feature_rev"`. |
| Push to remote | `git push -u origin "$branch"` | `jj git push -b "$bookmark"` |
| **Safety** | | |
| Check if directory is ignored | `git check-ignore -q "$dir"` | jj honors `.gitignore`. Colocated repo: `git check-ignore -q "$dir"`. Standalone jj repo (no `.git`): confirm the entry is in `.gitignore` (`grep -qxF "$dir/" .gitignore`); if absent, add it. |
| Discard work | `git branch -D "$name"` | `jj abandon "$rev"` |
