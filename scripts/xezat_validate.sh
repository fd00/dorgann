#!/usr/bin/env bash
# Sanity-checks the finished build via `xezat validate`: cygport file
# formatting (no BOM), CATEGORY/HOMEPAGE/LICENSE against xezat's known-
# good lists, BUILD_REQUIRES against the Cygwin packages actually
# installed (/etc/setup/installed.db), and any installed *.pc/*-config
# files under $D against gcc's own library layout. $D is only populated
# once `cygport ... install` has run, so this must come after cygport
# build's install/package steps -- but before `xezat bump`, so a bad
# build doesn't get a changelog entry written for it.
#
# Note: most findings here are logged (debug/warn/error) rather than
# turned into a nonzero exit -- Xezat::Command::Validate#execute never
# raises on its own. The one exception is the HOMEPAGE livecheck, which
# re-raises on an SSL error unless run with --ignore; that's a
# network/certificate condition unrelated to the package itself, so it's
# passed here to avoid failing the whole build on transient CI network
# issues.
#
# Usage (paths relative to the package directory, e.g. yacp/googletest):
#   xezat_validate.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport

set -euo pipefail

dir=""
cygport_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --file) cygport_file="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$dir" ]] || { echo "--dir is required" >&2; exit 1; }
[[ -n "$cygport_file" ]] || { echo "--file is required" >&2; exit 1; }

cd "$dir"
[[ -f "$cygport_file" ]] || { echo "No such file: $dir/$cygport_file" >&2; exit 1; }

xezat validate "$cygport_file" --ignore
