#!/usr/bin/env bash
# Closes the open build-failed Issue (doc/spec.md 4.5) for a package, if
# one exists, once a later build of that package succeeds (doc/spec.md
# 4.4: "If there's an open failure Issue for the same package, it is
# closed."). Meant to run unconditionally near the end of
# build-package.yml's job: a step with no `if:` of its own only runs if
# every earlier step in the job succeeded (GitHub Actions' implicit
# `if: success()`), so this never fires on the failure path --
# report_build_failure.sh handles that path instead, via its own explicit
# `if: failure()` step.
#
# Usage:
#   close_failure_issue.sh --repo fd00/dorgann --package foo \
#     --run-url https://github.com/fd00/dorgann/actions/runs/123456789

set -euo pipefail

repo=""
package=""
run_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    --run-url) run_url="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$repo" ]] || { echo "--repo is required" >&2; exit 1; }
[[ -n "$package" ]] || { echo "--package is required" >&2; exit 1; }
[[ -n "$run_url" ]] || { echo "--run-url is required" >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

existing="$("$script_dir/find_failure_issue.sh" --repo "$repo" --package "$package")"

if [[ -z "$existing" ]]; then
  echo "No open build-failed Issue for $package -- nothing to close" >&2
  exit 0
fi

echo "Closing build-failed Issue #$existing for $package" >&2
gh issue comment "$existing" --repo "$repo" --body "Resolved by a successful build: $run_url"
gh issue close "$existing" --repo "$repo"
