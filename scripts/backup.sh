#!/bin/sh
# backup.sh — verified snapshot before a destructive change.
#
#   scripts/backup.sh <path> [--keep N]
#
# Creates, under ~/.buddy/backups (override with BACKUP_DIR):
#   <name>-<timestamp>.tar.gz    the working tree, minus caches/venvs
#   <name>-<timestamp>.bundle    a full git bundle, for git repositories
#
# Both artifacts are verified before success is reported. Nothing is deleted
# except old snapshots beyond the retention limit (default 10).
set -eu

KEEP=10
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --keep)
            [ $# -ge 2 ] || { echo "backup: --keep needs a number" >&2; exit 2; }
            KEEP=$2
            shift 2
            ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "backup: unknown option $1" >&2
            exit 2
            ;;
        *)
            [ -z "$TARGET" ] || { echo "backup: one path at a time" >&2; exit 2; }
            TARGET=$1
            shift
            ;;
    esac
done

[ -n "$TARGET" ] || { echo "usage: $0 <path> [--keep N]" >&2; exit 2; }
[ -e "$TARGET" ] || { echo "backup: no such path: $TARGET" >&2; exit 1; }

case "$KEEP" in
    ''|*[!0-9]*) echo "backup: --keep must be a positive integer" >&2; exit 2 ;;
esac
[ "$KEEP" -ge 1 ] || { echo "backup: --keep must be at least 1" >&2; exit 2; }

TARGET=$(cd "$TARGET" 2>/dev/null && pwd) || {
    echo "backup: cannot enter $TARGET" >&2
    exit 1
}
NAME=$(basename "$TARGET")
NAME=$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9._-' '_')
STAMP=$(date +%Y%m%d-%H%M%S)
DEST=${BACKUP_DIR:-$HOME/.buddy/backups}
mkdir -p "$DEST"

ARCHIVE="$DEST/$NAME-$STAMP.tar.gz"
BUNDLE="$DEST/$NAME-$STAMP.bundle"

echo "backing up $TARGET"
tar -czf "$ARCHIVE" \
    --exclude='.venv' --exclude='venv' --exclude='node_modules' \
    --exclude='__pycache__' --exclude='.pytest_cache' --exclude='.mypy_cache' \
    --exclude='build' --exclude='dist' --exclude='.git' \
    -C "$(dirname "$TARGET")" "$(basename "$TARGET")"

# A backup that cannot be listed is not a backup.
tar -tzf "$ARCHIVE" >/dev/null 2>&1 || {
    echo "backup: archive verification failed: $ARCHIVE" >&2
    exit 1
}
FILES=$(tar -tzf "$ARCHIVE" | wc -l | tr -d ' ')
[ "$FILES" -gt 0 ] || { echo "backup: archive is empty" >&2; exit 1; }

echo "  archive: $ARCHIVE ($FILES entries, $(du -h "$ARCHIVE" | cut -f1))"

if [ -d "$TARGET/.git" ] && command -v git >/dev/null 2>&1; then
    git -C "$TARGET" bundle create "$BUNDLE" --all >/dev/null 2>&1 || {
        echo "backup: git bundle failed" >&2
        exit 1
    }
    git -C "$TARGET" bundle verify "$BUNDLE" >/dev/null 2>&1 || {
        echo "backup: git bundle verification failed: $BUNDLE" >&2
        exit 1
    }
    echo "  bundle:  $BUNDLE (verified)"
fi

# Retention: keep the newest $KEEP snapshots for this name.
COUNT=$(find "$DEST" -maxdepth 1 -name "$NAME-*.tar.gz" | wc -l | tr -d ' ')
if [ "$COUNT" -gt "$KEEP" ]; then
    find "$DEST" -maxdepth 1 -name "$NAME-*.tar.gz" | sort | head -n $((COUNT - KEEP)) |
        while IFS= read -r old; do
            rm -f "$old" "${old%.tar.gz}.bundle"
            echo "  pruned:  $(basename "$old")"
        done
fi

echo "restore:"
echo "  tar -xzf $ARCHIVE -C $(dirname "$TARGET")"
if [ -f "$BUNDLE" ]; then
    echo "  git clone $BUNDLE restored-$(basename "$NAME")"
fi
