#!/usr/bin/env bash
# Runs the rest of the cygport build pipeline: compile, install, package.
# download/prep are done beforehand by `xezat prep` (see xezat_prep.sh),
# which also copies the package's README into the build tree -- running
# them again here would re-apply patches that are already applied and
# fail. `all` is not used either, for the same reason (it includes prep).
#
# Usage (paths relative to the package directory, e.g. yacp/googletest):
#   cygport_build.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport

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

for step in compile install package; do
  echo "::group::cygport $cygport_file $step"
  cygport "$cygport_file" "$step"
  echo "::endgroup::"
done
