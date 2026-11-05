#!/bin/sh
# Commit build/web/ (from tools/build-web.sh) as the next commit on the
# gh-pages branch, without checking that branch out. gh-pages holds only the
# built web player; the source stays on main.
#   tools/publish-web.sh "Web player: <what changed>"
set -e
cd "$(dirname "$0")/.."
msg=${1:?usage: tools/publish-web.sh "commit message"}
[ -f build/web/index.html ] || { echo "build/web is missing: run tools/build-web.sh" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
idx=$tmp/index
GIT_INDEX_FILE=$idx git --work-tree=build/web add -A -f
tree=$(GIT_INDEX_FILE=$idx git write-tree)
if parent=$(git rev-parse -q --verify refs/heads/gh-pages); then
  [ "$(git rev-parse "$parent^{tree}")" = "$tree" ] && { echo "gh-pages already up to date"; exit 0; }
  commit=$(git commit-tree "$tree" -p "$parent" -m "$msg")
else
  commit=$(git commit-tree "$tree" -m "$msg")
fi
git update-ref refs/heads/gh-pages "$commit" ${parent:+"$parent"}
echo "gh-pages -> $(git log --oneline -1 "$commit")"
