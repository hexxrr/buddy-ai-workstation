#!/bin/sh
# check-repo.sh — test gate for this workspace (AGENTS.md §8, layers 1–4).
#
#   scripts/check-repo.sh [--keep]
#
# Runs, in order:
#   1. shell syntax      bash -n / sh -n on every script
#   2. Python syntax     py_compile on every .py file
#   3. unit tests        python3 -m unittest discover -s tests
#   4. health check      healthcheck.py, text and --json
#   5. backup smoke      snapshot a throwaway tree and verify the archive
#   6. template smoke    scaffold a project, test it, clean up
#   7. secret scan       look for credential-shaped strings in tracked files
#
# Exit status 0 only when every step passes. --keep leaves the smoke-test
# artifacts in build/ for inspection.
set -eu

KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

TMP="$ROOT/build/check-repo.$$"
mkdir -p "$TMP"
cleanup() {
    if [ "$KEEP" -eq 1 ]; then
        echo "kept artifacts in $TMP"
    else
        rm -rf "$TMP"
    fi
}
trap cleanup EXIT INT TERM

PASSES=0
FAILS=0
pass() { PASSES=$((PASSES + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf 'FAIL  %s\n' "$1" >&2; }
step() { printf '\n== %s ==\n' "$1"; }

step "1/7 shell syntax"
SHELLS_OK=1
for f in scripts/*.sh templates/project/run-tests.sh; do
    [ -f "$f" ] || continue
    if head -n1 "$f" | grep -q 'bash'; then
        bash -n "$f" || SHELLS_OK=0
    else
        sh -n "$f" || SHELLS_OK=0
    fi
done
[ "$SHELLS_OK" -eq 1 ] && pass "all shell scripts parse" || fail "shell syntax errors"

step "2/7 Python syntax"
PY_OK=1
find . -name '*.py' -not -path './.venv/*' -not -path './build/*' \
    -not -path './node_modules/*' -not -path './templates/*' -print | while IFS= read -r py; do
    python3 -m py_compile "$py" || exit 1
done || PY_OK=0
[ "$PY_OK" -eq 1 ] && pass "all Python files compile" || fail "Python syntax errors"

step "3/7 unit tests"
if [ -d tests ]; then
    if PYTHONPATH="$ROOT" python3 -m unittest discover -s tests -v \
        >"$TMP/tests.log" 2>&1; then
        tail -n 6 "$TMP/tests.log"
        pass "unit tests"
    else
        cat "$TMP/tests.log" >&2
        fail "unit tests"
    fi
else
    fail "tests/ directory missing"
fi

step "4/7 health check"
if python3 healthcheck.py >"$TMP/health.txt" 2>&1; then
    tail -n 1 "$TMP/health.txt"
    pass "healthcheck.py exits 0"
else
    cat "$TMP/health.txt" >&2
    fail "healthcheck.py"
fi
if python3 healthcheck.py --json | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["ok"] else 1)'; then
    pass "healthcheck.py --json is valid and ok"
else
    fail "healthcheck.py --json"
fi

step "5/7 backup smoke test"
SMOKE="$TMP/backup-src"
mkdir -p "$SMOKE/nested"
echo "important" >"$SMOKE/nested/data.txt"
if BACKUP_DIR="$TMP/backups" sh scripts/backup.sh "$SMOKE" >"$TMP/backup.log" 2>&1; then
    ARCHIVE=$(find "$TMP/backups" -name '*.tar.gz' | head -n1)
    if [ -n "$ARCHIVE" ] && tar -tzf "$ARCHIVE" | grep -q 'nested/data.txt'; then
        pass "backup archive created and lists data"
    else
        fail "backup archive incomplete"
    fi
else
    cat "$TMP/backup.log" >&2
    fail "backup.sh"
fi

step "6/7 template smoke test"
SCAFFOLD_PARENT="$TMP/scaffold"
if sh scripts/new-project.sh demo-tool "$SCAFFOLD_PARENT" >"$TMP/scaffold.log" 2>&1; then
    DEMO="$SCAFFOLD_PARENT/demo-tool"
    if [ -z "$(grep -RIn '{{' "$DEMO" 2>/dev/null)" ]; then
        pass "scaffold has no leftover placeholders"
    else
        fail "scaffold placeholders remain"
    fi
    if (cd "$DEMO" && sh run-tests.sh >/dev/null 2>&1); then
        pass "scaffolded project tests pass"
    else
        fail "scaffolded project tests"
    fi
    if (cd "$DEMO" && PYTHONPATH=src python3 -m demo_tool --json | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["status"]=="ok" else 1)'); then
        pass "scaffolded CLI runs"
    else
        fail "scaffolded CLI"
    fi
    if git -C "$DEMO" log --oneline >/dev/null 2>&1; then
        pass "scaffold has an initial commit"
    else
        fail "scaffold git history"
    fi
else
    cat "$TMP/scaffold.log" >&2
    fail "new-project.sh"
fi

step "7/7 secret scan"
# Token-shaped strings only; documentation may mention bare prefixes.
# Includes untracked files (not yet ignored) so a leak is caught before commit.
if git ls-files -z -co --exclude-standard | xargs -0 grep -nEI \
    '(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{32,}|xox[baprs]-[A-Za-z0-9-]{10,})' \
    -- >"$TMP/secrets.txt" 2>/dev/null; then
    cat "$TMP/secrets.txt" >&2
    fail "possible secret in working tree"
else
    pass "no credential-shaped strings in working tree"
fi

printf '\n----------------------------------------------\n'
printf '%d passed, %d failed\n' "$PASSES" "$FAILS"
[ "$FAILS" -eq 0 ]
