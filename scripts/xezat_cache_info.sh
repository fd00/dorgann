#!/usr/bin/env bash
# Computes what's needed to cache xezat's gem install (including
# rugged/charlock_holmes's compiled native extensions, not just their
# source) across workflow runs, and to make the gems' executables (xezat
# itself included) runnable from later steps:
#
#   - gem_home: the Windows-style path to Ruby's gem directory, for
#     actions/cache's `path:` input (which needs a real filesystem path,
#     not a Cygwin one).
#   - gem_bindir: where `gem install` puts executables. This is NOT
#     Gem.user_dir + "/bin" -- confirmed by comparing against the actual
#     "gem install" warning ("You don't have /home/runneradmin/bin in
#     your PATH") in a real run: user-install executables go to a fixed
#     $HOME/bin, not nested under the versioned gem_home path. `gem
#     environment`'s "EXECUTABLE DIRECTORY" line is RubyGems' own
#     authoritative answer, so that's parsed instead of re-deriving the
#     path from Gem.* APIs. Each workflow step is its own bash invocation
#     (started fresh via `bash -- script.sh`, not a login/interactive
#     shell), so nothing sources a profile that would normally add this
#     to PATH -- without it, e.g. `xezat prep` fails with "xezat: command
#     not found" even though `gem install xezat` just succeeded.
#     Appending it to GITHUB_PATH here makes it available to every later
#     step in the job, not just the current one.
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
# Output: prints "gem_home=...", "gem_bindir=..." and "version_hash=..."
# to stdout; if GITHUB_OUTPUT is set, appends the same there; if
# GITHUB_PATH is set, appends gem_bindir there too.

set -euo pipefail

gem_home="$(cygpath -w "$(ruby -e 'print Gem.user_dir')")"
gem_env="$(gem environment)"
echo "::group::gem environment"
echo "$gem_env"
echo "::endgroup::"
gem_bindir="$(cygpath -w "$(sed -n 's/^ *- EXECUTABLE DIRECTORY: *//p' <<<"$gem_env")")"
version_hash="$(cygcheck -c | sha256sum | cut -d' ' -f1)"

echo "gem_home=$gem_home"
echo "gem_bindir=$gem_bindir"
echo "version_hash=$version_hash"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "gem_home=$gem_home"
    echo "gem_bindir=$gem_bindir"
    echo "version_hash=$version_hash"
  } >> "$GITHUB_OUTPUT"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$gem_bindir" >> "$GITHUB_PATH"
fi
