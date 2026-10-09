#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

HOME="$TEST_ROOT/home" USER=tester SHELL=/bin/bash \
    "$REPO_ROOT/install.sh" --profile wsl --dry-run >"$TEST_ROOT/install.log"

for path in .zshrc .gitconfig .tmux.conf .copilot; do
    if [ -e "$TEST_ROOT/home/$path" ]; then
        echo "dry-run unexpectedly created $path" >&2
        exit 1
    fi
done

grep -q -- "--dry-run" < <("$REPO_ROOT/install.sh" --help)
grep -q "DRY-RUN" "$TEST_ROOT/install.log"

DOTFILES_DRY_RUN=1 "$REPO_ROOT/Linux/vm-prep/run.sh" \
    --timezone Pacific/Auckland \
    --swap-size 4G \
    --allow-http \
    --allow-https >"$TEST_ROOT/vm.log"

grep -q "DRY-RUN" "$TEST_ROOT/vm.log"

export LOG_TAG=test
# shellcheck source=../lib/common.sh
source "$REPO_ROOT/Linux/lib/common.sh"

source_repo="$TEST_ROOT/source"
broken_clone="$TEST_ROOT/broken"
git init -q "$source_repo"
git -C "$source_repo" config user.name test
git -C "$source_repo" config user.email test@example.com
printf 'ready\n' >"$source_repo/file"
git -C "$source_repo" add file
git -C "$source_repo" commit -qm initial
commit="$(git -C "$source_repo" rev-parse HEAD)"

git init -q "$broken_clone"
git -C "$broken_clone" remote add origin "file://$source_repo"
DOTFILES_DRY_RUN=0 DOTFILES_UPDATE=0 \
    clone_at_commit "file://$source_repo" "$broken_clone" "$commit"
test "$(git -C "$broken_clone" rev-parse HEAD)" = "$commit"
test -f "$broken_clone/file"

echo "installer dry-run tests passed"
