#!/usr/bin/env bash
# Prints the installed Cygwin gcc-core package's version (e.g.
# "14.2.0-1"), for the rebuild changelog message ("Rebuild with
# gcc-<version>", written via scripts/xezat_bump.sh's XEZAT_BUMP_MESSAGE
# when build-package.yml's `rebuild` input is set). This is the actual
# Cygwin package version, not `gcc --version`'s upstream-only string --
# it also changes across a Cygwin-side packaging fix with no upstream gcc
# version bump, which is exactly the kind of change a rebuild exists to
# pick up.
#
# gcc-core is always installed as part of the base toolchain (see
# build-package.yml's "Install Cygwin (base toolchain)" step), so this
# only needs to run sometime after that -- no separate package install of
# its own.
#
# Usage: gcc_version.sh (no arguments)
# Output: prints the version to stdout; if GITHUB_OUTPUT is set, appends
# `gcc_version=<version>` there too.

set -euo pipefail

version="$(cygcheck -c gcc-core | awk '$1 == "gcc-core" { print $2 }')"

if [[ -z "$version" ]]; then
  echo "gcc_version.sh: couldn't find gcc-core in 'cygcheck -c gcc-core' output" >&2
  exit 1
fi

echo "$version"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "gcc_version=$version" >> "$GITHUB_OUTPUT"
fi
