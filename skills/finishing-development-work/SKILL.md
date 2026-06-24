---
name: finishing-development-work
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing Development Work

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-development-work skill to complete this work."

**VCS commands:** Concrete commands depend on your user's VCS (injected as `VCS: git` or `VCS: jj` in session context). The git path is shown inline; for jj equivalents see `../using-superpowers/references/vcs-operations.md` and the **jj:** callouts below.

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options.**

**git:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

**jj:** Run `jj workspace list`. If it shows only `default`, you are in a normal checkout (no workspace to clean up). If you are in a workspace created with `jj workspace add` under `.worktrees/` or `worktrees/`, cleanup is provenance-based (Step 6). jj has no detached-HEAD state, so always use the standard 4 options.

### Step 3: Determine Base

**git:**

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

**jj:** `jj log -r 'trunk()' --no-graph --no-pager -T 'change_id.short() ++ "\n"' | head -1` resolves the trunk (main/master) revision.

Or ask: "This work split from main - is that correct?"

### Step 4: Present Options

**Normal repo and named-branch/bookmark workspace — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base> locally
2. Push and create a Pull Request
3. Keep the work as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD (git only) — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 5: Execute Choice

#### Option 1: Merge Locally

**git:**

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>

# Only after merge succeeds: cleanup worktree (Step 6), then delete branch
git branch -d <feature-branch>
```

**jj:** Move the base bookmark forward to the feature head (jj prefers linear integration):

```bash
jj bookmark set <base> -r <feature-head>   # fast-forward the base bookmark
# For an explicit merge commit instead: jj new <base-rev> <feature-rev>
```

Then verify tests on the result. The feature change now lives on the base bookmark; no separate branch deletion is needed.

Then: Cleanup workspace (Step 6).

#### Option 2: Push and Create PR

**git:**

```bash
git push -u origin <feature-branch>
```

**jj:** Ensure a bookmark exists, then push it:

```bash
jj bookmark create <name> -r @   # only if no bookmark exists yet
jj git push -b <name>
```

**Do NOT clean up the workspace** — the user needs it alive to iterate on PR feedback.

Then create the PR (identical for both VCS — PRs push to git remotes):

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

#### Option 3: Keep As-Is

Report: "Keeping work in current state. Workspace preserved at <path>."

**Don't cleanup workspace.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- All work in this workspace
- Revision(s): <revision-list>
- Workspace at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed, from the main repo root:

**git:**

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
# Cleanup worktree (Step 6), then force-delete branch:
git branch -D <feature-branch>
```

**jj:** `jj abandon <feature-revs>` discards the work. Then cleanup the workspace (Step 6).

### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the workspace.

**git:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If the worktree path is under `.worktrees/` or `worktrees/`:** Superpowers created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**jj:** Determine the workspace path (`jj workspace root`) and name (from `jj workspace list`). Only clean up if it is under `.worktrees/` or `worktrees/` (provenance). `cd` out to the main repo root first, then forget and remove:

```bash
WS_PATH=$(jj workspace root)
cd <main-repo-root>            # never forget the workspace you are standing in
jj workspace forget <name>
rm -rf "$WS_PATH"
```

**Otherwise (either VCS):** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Workspace | Cleanup Ref |
|--------|-------|------|----------------|-------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up the workspace for Option 2**
- **Problem:** Remove the workspace the user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting a branch before removing the worktree (git)**
- **Problem:** `git branch -d` fails because the worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running cleanup from inside the workspace**
- **Problem:** `git worktree remove` / `jj workspace forget` + `rm -rf` from inside the workspace being removed fails or deletes your CWD
- **Fix:** Always `cd` to the main repo root before removing

**Cleaning up harness-owned workspaces**
- **Problem:** Removing a workspace the harness created causes phantom state
- **Fix:** Only clean up workspaces under `.worktrees/` or `worktrees/`

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on the result
- Delete work without confirmation
- Force-push without explicit request
- Remove a workspace before confirming merge success
- Clean up workspaces you didn't create (provenance check)
- Run cleanup from inside the workspace

**Always:**
- Verify tests before offering options
- Detect environment before presenting the menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Clean up the workspace for Options 1 & 4 only
- `cd` to the main repo root before workspace removal
- Run `git worktree prune` after removal (git)

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Pairs with:**
- **using-workspaces** - Cleans up the workspace created by that skill
