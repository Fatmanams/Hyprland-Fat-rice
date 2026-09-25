#!/usr/bin/env bash
# Launch croft when installed, with a policy-compliant install hint otherwise.
#
# The hinted command is version-pinned (0.1.942 is the newest release on
# crates.io as of 2026-09-25 — re-check before bumping). Bare
# `cargo install <name> --locked` always grabs whatever is newest, which
# defeats this repo's "review, then pin" discipline.
#
# This launcher runs through `ghostty -e`, and ghostty closes the window the
# instant we exit (confirm-close-surface=false, no hold setting) — so the
# not-installed branch pauses for a keypress, otherwise the hint flashes
# by unread. The pause is skipped when stdin isn't a terminal (lint, CI).

set -euo pipefail

if command -v croft >/dev/null 2>&1; then
    exec croft "$@"
fi

cat >&2 <<'EOF'
croft is not installed.

The upstream project is not in Arch's official repositories or the AUR.
Install it only after reviewing the locked upstream source:

  cargo install croft-software@0.1.942 --locked

Then run this launcher again.
EOF

# Hold the terminal open so the hint above can actually be read.
if [[ -t 0 ]]; then
    read -n 1 -s -r -p "Press any key to close..." || true
fi
exit 127
