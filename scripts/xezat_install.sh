#!/usr/bin/env bash
# Installs xezat from the HEAD of its GitHub repository (fd00/xezat)
# instead of its latest RubyGems.org release, so this workflow always
# builds against the newest xezat source, including changes not yet
# published as a gem. See scripts/xezat_cache_info.sh for how the gem
# install cache key stays in sync with this (it hashes in the same
# repository's HEAD commit).
#
# Clones into a RELATIVE path under the current directory rather than an
# absolute /tmp/... one -- confirmed by a real run's diagnostics
# (2026-08-15) that this step's `git` is native Git for Windows (`git
# version 2.55.0.windows.3`), not a Cygwin-native binary, even though the
# script itself runs under Cygwin bash. Git for Windows resolves a
# leading `/tmp/...` through its own MSYS2 path mapping, which points
# somewhere other than Cygwin's own /tmp (what `cd` and `mktemp -d` here
# resolve it to) -- so `git clone` and this script's own `cd` ended up
# operating on two different real directories: the clone silently
# "succeeded" into one location while `cd` landed in an empty one, and
# `gem build` then failed to find xezat.gemspec. A relative path sidesteps
# this entirely, since both tools resolve it against the same OS-level
# current directory regardless of which one's path-translation scheme
# they use.
#
# Usage: xezat_install.sh (no arguments)

set -euo pipefail

repo_dir="xezat-src-$$"
trap 'rm -rf "$repo_dir"' EXIT

git clone --depth 1 https://github.com/fd00/xezat.git "$repo_dir"

# Defensive check, kept from diagnosing the /tmp mismatch above -- cheap
# insurance against whatever the next surprise turns out to be.
gemspec="$repo_dir/xezat.gemspec"
if [[ ! -f "$gemspec" ]]; then
  echo "xezat_install.sh: '$gemspec' missing after clone -- dumping '$repo_dir' for diagnosis:" >&2
  ls -la "$repo_dir" >&2
  git --version >&2
  git -C "$repo_dir" status >&2 || echo "xezat_install.sh: git status failed too" >&2
  git -C "$repo_dir" log -1 --oneline >&2 || echo "xezat_install.sh: git log failed too" >&2
  exit 1
fi

(
  cd "$repo_dir"
  gem build xezat.gemspec
  gem install --no-document ./xezat-*.gem
)
