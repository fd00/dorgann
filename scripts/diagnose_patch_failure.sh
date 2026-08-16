#!/usr/bin/env bash
# Surfaces exactly which hunk of a .src.patch conflicts, for cygport's
# own "patch ... will not apply" failure (lib/src_prep.cygpart's
# cygpatch(), confirmed against a real run -- fd00/dorgann#23, io_lib
# 1.16.0). cygpatch() tries patch levels 0 through 5, each via
# `patch -N -s --dry-run -p<level> -i <patchfile> &> /dev/null` --
# both -s and the /dev/null redirect discard the patch tool's own
# diagnostic entirely, so cygport's error message never says which
# file/hunk/line actually conflicts, at any level.
#
# Meant to run as an `if: failure()`-conditioned step right after xezat
# prep, while the failed run's unpacked source tree ($S) is still on
# disk -- a step failing doesn't tear down the rest of the job's
# filesystem, only skips later default-condition steps. Reruns
# `patch --dry-run` ourselves at every level cygpatch() would have
# tried, this time without -s/&>/dev/null, so the real mismatch reaches
# the log (and, via the GITHUB_OUTPUT temp file below, the build-failed
# Issue body).
#
# Usage:
#   diagnose_patch_failure.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport
#
# Output: prints the diagnostic to stdout; if GITHUB_OUTPUT is set, also
# writes it to a temp file and appends `diagnostic_file=<path>` there
# (for report_build_failure.sh to embed in the Issue body) -- only when
# there was something to diagnose, so a skipped/inapplicable run leaves
# it as the empty string a skipped step's outputs already are.

set -uo pipefail # NOT -e: patch's own nonzero exit on a failed dry-run attempt is expected here, not a bug in this script

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

basename_noext="${cygport_file%.cygport}"
patch_file="${basename_noext}.src.patch"

if [[ ! -f "$patch_file" ]]; then
  echo "diagnose_patch_failure.sh: no $patch_file next to $cygport_file -- nothing to diagnose (failure wasn't a patch-apply one, or this package has no src.patch)" >&2
  exit 0
fi

# `patch -d "$S"` below cd's to $S *before* resolving -i's own argument,
# so a relative patch_file (as found above, relative to the package
# directory) would otherwise get looked up under $S instead and always
# report "No such file or directory" -- confirmed by a real run
# (fd00/dorgann#23, io_lib 1.16.0). Absolute sidesteps that regardless of
# which directory -d switches into.
patch_file="$(pwd)/$patch_file"

# Same `cygport <file> vars <NAME>` mechanism cygport_depends.sh already
# uses to read cygport-computed variables without going through xezat.
src_decl="$(cygport "$cygport_file" vars S 2>/dev/null)"
if [[ -z "$src_decl" ]]; then
  echo "diagnose_patch_failure.sh: 'cygport $cygport_file vars S' returned nothing -- can't locate the unpacked source tree" >&2
  exit 0
fi
eval "$src_decl"

if [[ ! -d "${S:-}" ]]; then
  echo "diagnose_patch_failure.sh: source tree '${S:-(unset)}' doesn't exist -- prep must have failed before unpacking, nothing to diagnose" >&2
  exit 0
fi

diagnostic="$(
  echo "Retrying $patch_file against \$S ($S) at every level cygport's own cygpatch() tries (0-5), without the -s/&>/dev/null that normally hides this:"
  for level in 0 1 2 3 4 5; do
    echo
    echo "--- patch -p$level --dry-run ---"
    patch -N --dry-run -p"$level" -i "$patch_file" -d "$S" 2>&1
  done
)"

echo "$diagnostic"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  output="$(mktemp)"
  printf '%s\n' "$diagnostic" > "$output"
  echo "diagnostic_file=$output" >> "$GITHUB_OUTPUT"
fi
