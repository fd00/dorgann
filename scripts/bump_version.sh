#!/usr/bin/env bash
# Renames a package's `.cygport` file (and any sibling files sharing the same
# versioned basename, e.g. `<PN>-<PV>-<PR>.src.patch`) to a new version, using
# util-linux's `rename` for the filename change and `sed` for a best-effort
# substitution of the old bare version string inside each file's content (for
# cases where SRC_URI etc. hardcode the version instead of referencing ${PV}).
# Both tools are installed via the Cygwin `util-linux` and `sed` packages.
#
# This does NOT replace `xezat bump` (which only regenerates README/changelog
# after a build) -- xezat has no command that performs this rename itself.
#
# Usage:
#   bump_version.sh --dir yacp/googletest --version 1.18.0
#
# Input: CLI args only (no GitHub Actions context dependency, so this can be
# run and debugged locally, given a Cygwin-flavored `rename`/`sed` on PATH).
# Output: prints the new .cygport basename, and if GITHUB_OUTPUT is set,
# appends `cygport_file=<basename>` and `version=<new_version>` there --
# the latter mirrors detect_cygport_file.sh's own `version` output, so
# build-package.yml can read whichever of the two actually ran without
# caring which one it was (branch-rebuild mode, doc/spec.md 4.6).

set -euo pipefail

dir=""
new_version=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --version) new_version="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$dir" ]] || { echo "--dir is required" >&2; exit 1; }
[[ -n "$new_version" ]] || { echo "--version is required" >&2; exit 1; }
[[ -d "$dir" ]] || { echo "No such directory: $dir" >&2; exit 1; }

# yacp convention: the package directory name equals PN. Resolve this before
# cd'ing so it works for relative --dir arguments too.
pn="$(basename "$(cd "$dir" && pwd)")"

cd "$dir"

shopt -s nullglob
cygport_files=(*.cygport)
shopt -u nullglob
if [[ ${#cygport_files[@]} -ne 1 ]]; then
  echo "Expected exactly one .cygport file in $dir, found ${#cygport_files[@]}: ${cygport_files[*]}" >&2
  exit 1
fi

old_basename="${cygport_files[0]%.cygport}"

prefix="${pn}-"
if [[ "$old_basename" != "$prefix"* ]]; then
  echo "cygport filename $old_basename does not start with package name $pn" >&2
  exit 1
fi

# "<PN>-<PV>-<PR>.cygport" -> strip "<PN>-" prefix, then drop the trailing "-<PR>" segment.
rest="${old_basename#"$prefix"}"
old_version="${rest%-*}"
if [[ -z "$old_version" || "$old_version" == "$rest" ]]; then
  echo "Could not parse a version out of cygport filename $old_basename" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "Package $pn is already at version $new_version" >&2
  exit 1
fi

# Release is reset to "1bl1" on a version bump. The "bl" marker distinguishes
# this build from the official Cygwin package of the same name/version.
# Packages that need a different release suffix are expected to be adjusted
# by hand afterwards.
new_basename="${pn}-${new_version}-1bl1"

# Every sibling file sharing the old versioned basename (the .cygport file
# itself, plus companions like "<PN>-<PV>-<PR>.src.patch") gets the same
# literal old-version substitution applied to its content, then all of them
# get renamed in one batch. Files that don't follow this versioned naming
# (e.g. README) are left untouched.
shopt -s nullglob
sibling_files=("$old_basename".*)
shopt -u nullglob

for f in "${sibling_files[@]}"; do
  sed -i "s/${old_version}/${new_version}/g" "$f"
done

rename -- "$old_basename" "$new_basename" "${sibling_files[@]}"

new_cygport_file="${new_basename}.cygport"
echo "Bumped $pn: $old_version -> $new_version (${#sibling_files[@]} file(s))"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "cygport_file=$new_cygport_file"
    echo "version=$new_version"
  } >> "$GITHUB_OUTPUT"
fi
