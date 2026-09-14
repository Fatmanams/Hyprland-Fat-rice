#!/usr/bin/env bash
# Launch Neomacs with the rice's existing pywal-driven Emacs configuration.

set -euo pipefail
exec neomacs "$@"
