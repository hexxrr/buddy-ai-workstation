#!/bin/sh
# new-project.sh — scaffold a new project from templates/project.
#
#   scripts/new-project.sh <name> [parent-dir]
#
# <name> must be lowercase, hyphen-separated (a-z, 0-9, -). The project is
# created at <parent-dir>/<name> (default: the workspace root, one level above
# this repo). The script refuses to touch an existing directory, then:
#   - copies the template and fills in placeholders
#   - initialises git on branch main with an initial commit
#   - runs the new project's test suite
#
# It never creates a GitHub remote and never pushes: that needs the user's
# approval (see AGENTS.md §13).
set -eu

usage() {
    echo "usage: $0 <name> [parent-dir]" >&2
    exit 2
}

case "${1:-}" in
    -h|--help)
        sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
esac

[ $# -ge 1 ] && [ $# -le 2 ] || usage

NAME=$1
case "$NAME" in
    [a-z]* ) ;;
    * ) echo "new-project: name must start with a lowercase letter" >&2; exit 2 ;;
esac
printf '%s' "$NAME" | grep -Eq '^[a-z][a-z0-9-]{1,40}$' || {
    echo "new-project: name must match ^[a-z][a-z0-9-]{1,40}\$ (got: $NAME)" >&2
    exit 2
}

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")
TEMPLATE="$REPO_ROOT/templates/project"
[ -d "$TEMPLATE" ] || { echo "new-project: template missing at $TEMPLATE" >&2; exit 1; }

PARENT=${2:-$(dirname "$REPO_ROOT")}
mkdir -p "$PARENT"
PARENT=$(cd "$PARENT" && pwd)
TARGET="$PARENT/$NAME"

if [ -e "$TARGET" ]; then
    echo "new-project: refusing to overwrite existing path: $TARGET" >&2
    exit 1
fi

PACKAGE=$(printf '%s' "$NAME" | tr '-' '_')
TITLE=$NAME
DATE=$(date +%Y-%m-%d)

# Copy everything, including dotfiles.
mkdir -p "$TARGET"
cp -R "$TEMPLATE/." "$TARGET/"
find "$TARGET" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

# Rename placeholder directories (sed only rewrites file contents).
if [ -d "$TARGET/src/{{PACKAGE}}" ]; then
    mv "$TARGET/src/{{PACKAGE}}" "$TARGET/src/$PACKAGE"
fi

# Fill placeholders in every text file.
find "$TARGET" -type f \( -name '*.md' -o -name '*.py' -o -name '*.sh' -o -name '.gitignore' \) |
while IFS= read -r file; do
    sed -i \
        -e "s|{{PROJECT_NAME}}|$NAME|g" \
        -e "s|{{PACKAGE}}|$PACKAGE|g" \
        -e "s|{{TITLE}}|$TITLE|g" \
        -e "s|{{DATE}}|$DATE|g" \
        "$file"
done

if grep -RIn '{{' "$TARGET" 2>/dev/null | head -n 1 | grep -q .; then
    echo "new-project: unsubstituted placeholders remain:" >&2
    grep -RIn '{{' "$TARGET" >&2 || true
    exit 1
fi

chmod +x "$TARGET/run-tests.sh"

# Fresh history, no upstream. Use the user's git identity when configured.
GIT_NAME=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" \
    -c user.name="${GIT_NAME:-agent}" \
    -c user.email="${GIT_EMAIL:-agent@localhost}" \
    commit -q -m "Initial commit: $NAME from buddy-ai-workstation template"

echo "created $TARGET"
echo
(cd "$TARGET" && ./run-tests.sh)

cat <<EOF

Next steps:
  cd "$TARGET"
  \$EDITOR PLAN.md        # plan the work before coding
  ./run-tests.sh          # test gate
  scripts/backup.sh .     # before anything destructive (from the workspace repo)

Publishing is a separate, approved step:
  gh repo create $NAME --public --source=. --remote=origin --push
EOF
