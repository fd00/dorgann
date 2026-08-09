#!/usr/bin/env bash
# Lays cygport's dist output out into the Cygwin-repository release-area
# convention calm's mksetupini expects: <rel_area>/x86_64/release/<pkg>/
# (doc/spec.md 3.2). cygport's own dist/ layout differs -- see cygport's
# pkg_pkg.cygpart: dist/<PN>/[<subpkg-name>/]<file>.{hint,tar.xz}, where a
# subpkg-name directory only exists for extra binary packages a single
# cygport file produces (e.g. <PN>-debuginfo). calm's own upload-
# processing (which reshapes maintainer uploads into the release area on
# the real Cygwin infrastructure) is what normally does this reshaping,
# but we're not using that here, so it has to happen in this script.
#
# The rule that finds each package's target directory name: every
# directory *directly* containing a .hint file is one Cygwin package,
# named after that directory's own basename -- this holds for both the
# plain case (dist/<PN>/<PN>-<PVR>-<ARCH>.hint, basename == PN) and the
# subpackage case (dist/<PN>/<PN>-debuginfo/*.hint, basename ==
# "<PN>-debuginfo").
#
# Keeps only one generation per package (doc/spec.md 3.3): each target
# directory's prior contents are wiped before the new files are copied
# in, rather than accumulating multiple versions side by side.
#
# Output: prints the published package names (space-separated) to
# stdout, and if GITHUB_OUTPUT is set, appends `published_packages=<list>`
# there.
#
# Usage:
#   layout_release_area.sh --artifact-dir artifact --gh-pages-dir gh-pages

set -euo pipefail

artifact_dir=""
gh_pages_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir) artifact_dir="$2"; shift 2 ;;
    --gh-pages-dir) gh_pages_dir="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$artifact_dir" ]] || { echo "--artifact-dir is required" >&2; exit 1; }
[[ -n "$gh_pages_dir" ]] || { echo "--gh-pages-dir is required" >&2; exit 1; }

release_dir="$gh_pages_dir/x86_64/release"
mkdir -p "$release_dir"

published=()
while IFS= read -r -d '' pkg_dir; do
  pkg_name="$(basename "$pkg_dir")"
  target="$release_dir/$pkg_name"

  echo "Publishing $pkg_name from $pkg_dir" >&2
  rm -rf "$target"
  mkdir -p "$target"
  cp "$pkg_dir"/*.hint "$pkg_dir"/*.tar.* "$target/"
  published+=("$pkg_name")
done < <(find "$artifact_dir" -name '*.hint' -exec dirname {} \; | sort -u | tr '\n' '\0')

if [[ ${#published[@]} -eq 0 ]]; then
  echo "No .hint files found under $artifact_dir" >&2
  exit 1
fi

published_packages="${published[*]}"
echo "$published_packages"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "published_packages=$published_packages" >> "$GITHUB_OUTPUT"
fi
