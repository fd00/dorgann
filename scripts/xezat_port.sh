#!/usr/bin/env bash
# Copies the build's cygport file, README, and src.patch back into the
# package directory in the yacp checkout, via `xezat port`. This is what
# actually lands the README's xezat-regenerated changelog (written by
# `xezat bump` into the build tree, $C) onto the tracked file that a later
# diff/PR step looks at -- xezat bump alone never writes there: xezat's own
# source shows `prep` only copies package-dir -> build-tree (so bump has a
# README to read/append to), and `bump` only writes back to that same
# build-tree copy. Nothing copies build-tree -> package-dir except this.
#
# `xezat port` copies into <portdir>/<PN> (PN = package name, taken from
# the cygport file's own PN variable, which yacp's convention makes equal
# to the package directory's basename). Passing the *parent* of the
# package directory as --portdir therefore lands the copy directly back in
# the same directory bump_version.sh already renamed the source .cygport
# (and any versioned sibling file, e.g. .src.patch) away from -- so this
# overwrites the tracked files in place rather than creating a copy
# elsewhere.
#
# `xezat port`'s --portdir option is only consulted as a fallback: it
# unconditionally tries to read its config file first (~/.xezat/config.yml
# by default, via Xezat::Command::Port#get_port_directory ->
# Xezat#config), and YAML.load_file raises Errno::ENOENT if that file
# doesn't exist -- which it never does on a fresh Actions runner. An empty
# (but valid) config file avoids that crash while leaving portdir unset
# there, so our --portdir below is what actually gets used.
#
# Usage (paths relative to the package directory, e.g. yacp/googletest):
#   xezat_port.sh --dir yacp/googletest --file googletest-1.18.0-1bl1.cygport

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

parent="$(dirname "$(cd "$dir" && pwd)")"

config_file="$HOME/.xezat/config.yml"
if [[ ! -f "$config_file" ]]; then
  mkdir -p "$(dirname "$config_file")"
  printf 'xezat: {}\n' > "$config_file"
fi

cd "$dir"
[[ -f "$cygport_file" ]] || { echo "No such file: $dir/$cygport_file" >&2; exit 1; }

xezat port "$cygport_file" --portdir "$parent"
