#!/usr/bin/env bash
# Computes the two things needed to cache xezat's gem install (including
# rugged/charlock_holmes's compiled native extensions, not just their
# source) across workflow runs:
#
#   - gem_home: the Windows-style path to Ruby's gem directory, for
#     actions/cache's `path:` input (which needs a real filesystem path,
#     not a Cygwin one).
#   - version_hash: a fingerprint of every installed Cygwin package's
#     version. Native extensions are compiled against specific library
#     ABIs (Ruby itself, ICU, ...), and cygwin-install-action always
#     installs whatever's current on the mirror rather than pinned
#     versions, so a cached binary from a previous run could silently be
#     ABI-incompatible with a newer install. Folding this into the cache
#     key means any such change naturally invalidates the cache instead
#     of restoring a broken extension.
#
# Usage: xezat_cache_info.sh (no arguments; run after all Cygwin packages
# needed for xezat are installed)
#
# Output: prints "gem_home=..." and "version_hash=..." to stdout, and if
# GITHUB_OUTPUT is set, appends the same there.

set -euo pipefail

gem_home="$(cygpath -w "$(ruby -e 'print Gem.user_dir')")"
version_hash="$(cygcheck -c | sha256sum | cut -d' ' -f1)"

echo "gem_home=$gem_home"
echo "version_hash=$version_hash"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "gem_home=$gem_home"
    echo "version_hash=$version_hash"
  } >> "$GITHUB_OUTPUT"
fi
