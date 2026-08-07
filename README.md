# dorgann

Automation that watches upstream releases for the package recipes in [fd00/yacp](https://github.com/fd00/yacp), and drives the whole loop of updating the `cygport` file, building the package, and opening a PR against yacp.

The `main` branch (this branch) holds the list of monitored packages, the update/build/PR scripts, and the GitHub Actions workflows that run them. A separate `gh-pages` branch serves as a Cygwin-compatible binary repository (`setup.ini` format) for publishing devel packages that yacp doesn't otherwise distribute.

See [doc/spec.md](doc/spec.md) for the full design.
