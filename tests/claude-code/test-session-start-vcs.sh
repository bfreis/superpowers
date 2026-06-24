#!/usr/bin/env bash
# Tests for VCS detection in the session-start hook.
# Resolution order: explicit config > auto-detect (.jj/.git) > git default.
# Each test runs the hook from a controlled working directory so auto-detection
# is deterministic (the superpowers repo itself is a jj repo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$(cd "$SCRIPT_DIR/../../hooks" && pwd)/session-start"
FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# run_hook <workdir> — run the hook from workdir with HOME=workdir, echo output
run_hook() {
    ( cd "$1" && HOME="$1" bash "$HOOK" 2>&1 ) || true
}

echo "=== Session-start VCS detection tests ==="

# --- Test 1: Default is git when no config and no repo markers ---
echo "Test 1: Default VCS is git (no config, clean dir)"
T=$(mktemp -d)
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: git'; then pass "default is git"; else
    fail "default is git — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 2: Config jj wins over everything ---
echo "Test 2: Config vcs=jj is honored"
T=$(mktemp -d); mkdir -p "$T/.config/superpowers"
echo '{"vcs": "jj"}' > "$T/.config/superpowers/config.json"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: jj'; then pass "reads jj from config"; else
    fail "reads jj from config — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 3: Config git is honored ---
echo "Test 3: Config vcs=git is honored"
T=$(mktemp -d); mkdir -p "$T/.config/superpowers"
echo '{"vcs": "git"}' > "$T/.config/superpowers/config.json"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: git'; then pass "reads git from config"; else
    fail "reads git from config — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 4: Invalid config value warns and falls through to auto-detect (git here) ---
echo "Test 4: Invalid config value warns, falls back to git"
T=$(mktemp -d); mkdir -p "$T/.config/superpowers"
echo '{"vcs": "svn"}' > "$T/.config/superpowers/config.json"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: git'; then pass "invalid value falls back to git"; else
    fail "invalid value falls back to git — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
if echo "$output" | grep -q 'Unsupported VCS'; then pass "invalid value emits visible warning"; else
    fail "invalid value emits visible warning — no warning found"; fi
rm -rf "$T"

# --- Test 5: Config present but no vcs key falls through to auto-detect (git here) ---
echo "Test 5: Config without vcs key falls back to git"
T=$(mktemp -d); mkdir -p "$T/.config/superpowers"
echo '{"other": "value"}' > "$T/.config/superpowers/config.json"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: git'; then pass "missing key falls back to git"; else
    fail "missing key falls back to git — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 6: Auto-detect jj from a .jj directory (no config) ---
echo "Test 6: Auto-detect jj when .jj exists"
T=$(mktemp -d); mkdir "$T/.jj"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: jj'; then pass "auto-detects jj"; else
    fail "auto-detects jj — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 7: Auto-detect git from a .git directory (no config) ---
echo "Test 7: Auto-detect git when .git exists"
T=$(mktemp -d); mkdir "$T/.git"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: git'; then pass "auto-detects git"; else
    fail "auto-detects git — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

# --- Test 8: Colocated repo (.jj and .git) auto-detects jj ---
echo "Test 8: Colocated repo prefers jj"
T=$(mktemp -d); mkdir "$T/.jj" "$T/.git"
output=$(run_hook "$T")
if echo "$output" | grep -q 'VCS: jj'; then pass "colocated prefers jj"; else
    fail "colocated prefers jj — got: $(echo "$output" | grep 'VCS:' || echo 'no VCS line')"; fi
rm -rf "$T"

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
