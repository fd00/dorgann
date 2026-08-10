#!/usr/bin/env bash
# Finds the open `build-failed` Issue (doc/spec.md 4.5) for a given
# package, if one exists. Shared by report_build_failure.sh (reuse instead
# of piling up a duplicate Issue on every repeat failure) and
# close_failure_issue.sh (close it once a later build succeeds).
#
# Issues are matched by the package field inside their `dorgann-meta` HTML
# comment -- a literal JSON substring match, not a regex or a title search
# -- since doc/spec.md 4.5 treats that comment as the source of truth for
# machine parsing (the title also carries the version, so it changes on
# every failure, and a Markdown table can be mis-parsed if formatting
# breaks). JSON is decoded with jq --arg rather than interpolated into a
# jq program string, so a package name can't break out of the filter.
#
# Usage: find_failure_issue.sh --repo fd00/dorgann --package foo
# Output: the issue number on stdout if found; nothing (exit 0) if not.

set -euo pipefail

repo=""
package=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$repo" ]] || { echo "--repo is required" >&2; exit 1; }
[[ -n "$package" ]] || { echo "--package is required" >&2; exit 1; }

needle="\"package\":\"$package\""

gh issue list --repo "$repo" --label build-failed --state open --limit 100 --json number,body |
  jq -r --arg needle "$needle" '.[] | select(.body | contains($needle)) | .number' |
  head -n1
