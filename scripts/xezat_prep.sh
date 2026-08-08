#!/usr/bin/env bash
# Fetches and prepares a cygport file's sources via `xezat prep`
# (`cygport <file> fetch` + `cygport <file> prep`), which additionally
# copies the package directory's README into the build tree ($C). That
# copy is what a later `xezat bump` reads and appends a changelog entry
# to -- without it, xezat bump would operate on whatever stale/absent
# README happens to already be there instead of the current one.
#
# Usage (paths relative to the package directory, e.g. yacp/googletest):
#   xezat_prep.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport

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

xezat prep "$cygport_file"
