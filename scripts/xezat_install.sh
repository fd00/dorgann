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
(
  cd "$repo_dir"
  gem build xezat.gemspec
  gem install --no-document ./xezat-*.gem
)
