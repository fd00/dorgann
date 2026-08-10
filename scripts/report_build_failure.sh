#!/usr/bin/env bash
# Files (or updates) a build-failed Issue (doc/spec.md 4.5) for a package.
# Meant to be wired up as the last step of build-package.yml's job with
# `if: failure()` -- steps only get this far if something earlier in the
# same job errored out (bump, cygport build, xezat, Create Pull Request,
# ...).
#
# Reuses find_failure_issue.sh so repeat failures of the same package
# (e.g. re-running after tweaking BUILD_REQUIRES) update the existing
# Issue in place -- new version -- instead of piling up a duplicate every
# time. A future daily-cron loop (doc/spec.md 4.2, not yet implemented)
# reads the version back out of this same dorgann-meta comment to decide
# whether upstream has since published something newer worth retrying.
#
# Deliberately does NOT embed a log excerpt (doc/spec.md 4.5's original
# design called for one; dropped after actually using this against a
# couple of real failures) -- a fixed line count is either too long for
# the common case or too short to contain the actual error for a build
# that fails many steps in, and the run itself keeps the complete log for
# the full retention period anyway, which is plenty of time to
# investigate. The Issue just links to the run instead.
#
# Usage:
#   report_build_failure.sh --repo fd00/dorgann --package foo --version 1.2.3 \
#     --run-url https://github.com/fd00/dorgann/actions/runs/123456789

set -euo pipefail

repo=""
package=""
version=""
run_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    --version) version="$2"; shift 2 ;;
    --run-url) run_url="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$repo" ]] || { echo "--repo is required" >&2; exit 1; }
[[ -n "$package" ]] || { echo "--package is required" >&2; exit 1; }
[[ -n "$version" ]] || { echo "--version is required" >&2; exit 1; }
[[ -n "$run_url" ]] || { echo "--run-url is required" >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

# Built with printf '%s', not an interpolated heredoc, purely out of
# habit/consistency with the rest of this repo's scripts -- there's no
# untrusted content in these particular values (package/version/run_url
# all come from this same workflow run), but it costs nothing here either.
{
  printf '<!-- dorgann-meta: {"package":"%s","version":"%s"} -->\n\n' "$package" "$version"
  printf '| Field   | Value |\n|---------|-------|\n'
  printf '| Package | %s |\n| Version | %s |\n\n' "$package" "$version"
  printf 'Run: %s\n' "$run_url"
} >"$body_file"

title="$package: build failed at $version"

# `gh` on windows-latest (this script's only caller, build-package.yml, is
# windows-only) is the runner's native Windows gh.exe, not a Cygwin build
# -- it can't resolve the POSIX-style path mktemp just gave us (confirmed
# by a real run: "open /tmp/tmp.XXXXXXXX: The system cannot find the path
# specified", the Windows API's own wording for a path it can't parse at
# all). cygpath -w is the same POSIX->Windows conversion
# scripts/xezat_cache_info.sh already relies on for the same reason. Kept
# conditional so this script still runs as-is on a non-Cygwin box (e.g.
# testing locally on macOS/Linux per doc/spec.md 5's reproducibility goal).
body_file_native="$body_file"
if command -v cygpath >/dev/null 2>&1; then
  body_file_native="$(cygpath -w "$body_file")"
fi

existing="$("$script_dir/find_failure_issue.sh" --repo "$repo" --package "$package")"

if [[ -n "$existing" ]]; then
  echo "Updating existing build-failed Issue #$existing for $package" >&2
  gh issue edit "$existing" --repo "$repo" --title "$title" --body-file "$body_file_native"
else
  echo "Filing a new build-failed Issue for $package" >&2
  gh issue create --repo "$repo" --title "$title" --body-file "$body_file_native" --label build-failed
fi
