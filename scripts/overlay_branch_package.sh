#!/usr/bin/env bash
# Branch-rebuild mode (doc/spec.md 4.6): overlays a package directory's
# content from an existing yacp branch onto the current (default-branch)
# checkout, so a human's manual fix pushed to that branch (however it got
# there -- including a squash + force-push) shows up as a plain
# uncommitted diff against master, the same shape build-package.yml's
# fresh-bump path already produces.
#
# Deliberately does NOT check out the branch itself as this job's working
# base (that was tried first, via actions/checkout's `ref:` input, and it
# broke peter-evans/create-pull-request's own base-branch reconciliation:
# with nothing "new" committed during a run that only re-validates an
# already-fixed branch, it collapsed the whole branch down to be
# byte-identical to base and deleted/closed it outright -- confirmed by a
# real run against libucl). Overlaying just one directory's content on
# top of an ordinary master checkout sidesteps that entirely, since it's
# exactly the shape (an uncommitted diff against a freshly-checked-out
# default branch) create-pull-request already knows how to diff and
# commit correctly.
#
# `git checkout <treeish> -- <path>` only adds/updates files present in
# <treeish> at that path -- it never deletes files that exist in the
# working tree but aren't there (a well-known git gotcha), which matters
# here since a version bump deletes the old-version .cygport/.src.patch;
# the directory is removed first so old and new files don't end up side
# by side.
#
# Usage:
#   overlay_branch_package.sh --dir yacp --package libucl --branch dorgann/libucl-0.9.4

set -euo pipefail

dir=""
package=""
branch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$dir" ]] || { echo "--dir is required" >&2; exit 1; }
[[ -n "$package" ]] || { echo "--package is required" >&2; exit 1; }
[[ -n "$branch" ]] || { echo "--branch is required" >&2; exit 1; }

# actions/checkout's default fetch refspec only covers the ref it was
# told to check out (the default branch here), so a plain `git fetch
# origin <branch>` wouldn't create a usable origin/<branch> tracking ref
# -- spelling out the destination explicitly makes it do so regardless.
git -C "$dir" fetch --depth=1 origin "$branch:refs/remotes/origin/$branch"

git -C "$dir" rm -rq --ignore-unmatch -- "$package"
git -C "$dir" checkout "origin/$branch" -- "$package"

# cygport sources .cygport files as a bash script, so CRLF line endings
# are fatal to it ("line 3: $'\r': command not found", confirmed by a
# real run) -- and unlike a fresh checkout of dorgann-generated content,
# this directory's content was just brought in from whatever a human
# committed by hand, quite possibly from a Windows git/editor setup that
# reintroduces CRLF into the blob itself. build-package.yml's own
# "Disable line-ending conversion on checkout" doesn't help here: it only
# stops checkout from adding *more* conversion on top of a blob, it can't
# strip bytes the blob already contains. Normalize defensively rather
# than trust every future manual fix to get this right.
# grep exits 1 (not an error, just "no matches") whenever nothing in the
# directory actually has CRLF -- under `set -e -o pipefail`, piping that
# straight into xargs would make the *normal* case (nothing to strip)
# abort the whole script. Collecting matches into an array first, with an
# explicit `|| true`, sidesteps that -- sed only runs at all if there's
# something to fix.
mapfile -d '' -t crlf_files < <(grep -rlZ $'\r$' "$dir/$package" || true)
if [[ ${#crlf_files[@]} -gt 0 ]]; then
  sed -i 's/\r$//' "${crlf_files[@]}"
fi
