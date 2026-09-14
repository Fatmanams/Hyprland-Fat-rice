#!/usr/bin/env bash
# Launch Ox with its pywal-generated config.

set -euo pipefail
exec ox --config "$HOME/.config/ox/.oxrc" "$@"
