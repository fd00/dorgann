#!/usr/bin/env bash
# Installs xezat from the HEAD of its GitHub repository (fd00/xezat)
# instead of its latest RubyGems.org release, so this workflow always
# builds against the newest xezat source, including changes not yet
# published as a gem. See scripts/xezat_cache_info.sh for how the gem
# install cache key stays in sync with this (it hashes in the same
# repository's HEAD commit).
#
# Usage: xezat_install.sh (no arguments)

set -euo pipefail

repo_dir="$(mktemp -d)"
trap 'rm -rf "$repo_dir"' EXIT

git clone --depth 1 https://github.com/fd00/xezat.git "$repo_dir"

# A run on 2026-08-15 (windows-latest, Cygwin) hit `git clone` reporting
# success yet leaving xezat.gemspec missing afterward, unreproducible
# locally -- dump enough state here to actually diagnose that if it
# recurs, instead of just relaying gem build's generic "not found" error.
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
