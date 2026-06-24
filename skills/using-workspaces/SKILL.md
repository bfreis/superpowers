---
name: using-workspaces
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or a git worktree / jj workspace fallback
---

# Using Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native worktree/workspace tools. Fall back to manual VCS workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to the VCS. Never fight the harness.

**Announce at start:** "I'm using the using-workspaces skill to set up an isolated workspace."

**VCS commands:** Concrete commands depend on your user's VCS (injected as `VCS: git` or `VCS: jj` in session context). The git path is shown inline; for jj equivalents see `../using-superpowers/references/vcs-operations.md` and the **jj:** callouts below. A git worktree and a jj workspace serve the same role here — an isolated working copy sharing one repository.

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

**git:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Before concluding "already in a worktree," verify you are not in a submodule:

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 2 (Project Setup). Do NOT create another worktree.

**jj:** jj harnesses rarely auto-isolate. Run `jj workspace list`: the original workspace is named `default`. If it lists only `default`, you are not in a linked workspace — continue below. If you started in a workspace you (or the harness) created with `jj workspace add`, you are already isolated — skip to Step 2. There is no detached-HEAD concept in jj; the current change is always `@`.

Report with branch/bookmark state:
- On a branch/bookmark: "Already in isolated workspace at `<path>` on `<name>`."
- Detached HEAD (git only): "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON` (or in a submodule), or jj shows only `default`:** You are in a normal repo checkout.

Has the user already indicated their worktree preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current branch from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a worktree/workspace? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, ref creation, and cleanup automatically. Using a raw VCS command when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native worktree tool available.

### 1b. VCS Workspace Fallback

**Only use this if Step 1a does not apply** — you have no native worktree tool available. Create a workspace manually using your VCS.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared worktree directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local worktree directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   If found, use it. If both exist, `.worktrees` wins.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating the workspace:**

**git:**

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**jj:** jj honors `.gitignore`. In a colocated repo the `git check-ignore` command above works. In a standalone jj repo (no `.git`), confirm the directory is listed in `.gitignore` (`grep -qxF '.worktrees/' .gitignore`).

**If NOT ignored:** Add to .gitignore, commit the change, then proceed.

**Why critical:** Prevents accidentally committing workspace contents to the repository.

#### Create the Workspace

**git:**

```bash
# Determine path based on chosen location
path="$LOCATION/$WORKSPACE_NAME"

git worktree add "$path" -b "$WORKSPACE_NAME"
cd "$path"
```

**jj:**

```bash
path="$LOCATION/$WORKSPACE_NAME"
jj workspace add "$path"
cd "$path"
```

**jj note:** `jj workspace add` does NOT create a named ref. If the user wants a named ref (needed for pushing/PRs later), create a bookmark with `jj bookmark create "$WORKSPACE_NAME" -r @` — or defer it to finish time.

**Sandbox fallback:** If workspace creation fails with a permission error (sandbox denial), tell the user the sandbox blocked it and you're working in the current directory instead. Then run setup and baseline tests in place.

## Step 2: Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## Step 3: Verify Clean Baseline

Run tests to ensure the workspace starts clean:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
Workspace ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree/workspace | Skip creation (Step 0) |
| In a submodule (git) | Treat as normal repo (Step 0 guard) |
| Native worktree tool available | Use it (Step 1a) |
| No native tool | VCS workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + commit |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

### Fighting the harness

- **Problem:** Creating a manual worktree/workspace when the platform already provides isolation
- **Fix:** Step 0 detects existing isolation. Step 1a defers to native tools.

### Skipping detection

- **Problem:** Creating a nested workspace inside an existing one
- **Fix:** Always run Step 0 before creating anything

### Skipping ignore verification

- **Problem:** Workspace contents get tracked, pollute status
- **Fix:** Always verify the directory is ignored before creating a project-local workspace

### Assuming directory location

- **Problem:** Creates inconsistency, violates project conventions
- **Fix:** Follow priority: explicit instructions > existing project-local directory > default

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

## Red Flags

**Never:**
- Create a workspace when Step 0 detects existing isolation
- Use a raw VCS command (`git worktree add` / `jj workspace add`) when you have a native worktree tool (e.g., `EnterWorktree`). This is the #1 mistake — if you have it, use it.
- Skip Step 1a by jumping straight to Step 1b's VCS commands
- Create a workspace without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking

**Always:**
- Run Step 0 detection first
- Prefer native tools over the VCS fallback
- Follow directory priority: explicit instructions > existing project-local directory > default
- Verify the directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline

## Integration

**Pairs with:**
- **finishing-development-work** - REQUIRED for cleanup after work complete
