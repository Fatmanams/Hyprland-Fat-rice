#!/usr/bin/env bash
# Launch croft when installed, with a policy-compliant install hint otherwise.

set -euo pipefail

if command -v croft >/dev/null 2>&1; then
    exec croft "$@"
fi

cat >&2 <<'EOF'
croft is not installed.

The upstream project is not in Arch's official repositories or the AUR.
Install it only after reviewing the locked upstream source:

  cargo install croft-software --locked

Then run this launcher again.
EOF
exit 127
