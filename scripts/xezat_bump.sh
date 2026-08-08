#!/usr/bin/env bash
# Regenerates a package's README (with an updated changelog) via
# `xezat bump`. Must run after a successful cygport build and before any
# `cygport ... clean`/finish (which build-package.yml never calls),
# since xezat reads the file-list (.lst) data cygport's install step
# leaves behind under $T.
#
# Usage:
#   xezat_bump.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport

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

xezat bump "$cygport_file"
