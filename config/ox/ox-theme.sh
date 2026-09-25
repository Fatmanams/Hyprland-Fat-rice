#!/usr/bin/env bash
# Render Ox's Lua configuration from the active pywal16 colors.sh palette.

set -euo pipefail

# Same guard as ghostty-theme.sh: this renders into $HOME, running it as
# root would paint root's config — useless on a single-user rice.
if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user, not root."
    exit 1
fi

WAL="$HOME/.cache/wal/colors.sh"
TEMPLATE="$HOME/.config/ox/.oxrc.template"
OUT="$HOME/.config/ox/.oxrc"

if [[ ! -f "$WAL" || ! -f "$TEMPLATE" ]]; then
    exit 0
fi

# shellcheck disable=SC1090
source "$WAL"
rgb() {
    local hex=${1#\#}
    printf '%d, %d, %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

mkdir -p "$(dirname "$OUT")"
sed \
    -e "s/@EDITOR_BG@/$(rgb "$background")/g" \
    -e "s/@EDITOR_FG@/$(rgb "$foreground")/g" \
    -e "s/@COMMENT@/$(rgb "$color8")/g" \
    -e "s/@PANEL_BG@/$(rgb "$color0")/g" \
    -e "s/@ACCENT@/$(rgb "$color6")/g" \
    -e "s/@BLUE@/$(rgb "$color4")/g" \
    -e "s/@YELLOW@/$(rgb "$color3")/g" \
    -e "s/@RED@/$(rgb "$color1")/g" \
    -e "s/@GREEN@/$(rgb "$color2")/g" \
    -e "s/@CYAN@/$(rgb "$color6")/g" \
    -e "s/@MAGENTA@/$(rgb "$color5")/g" \
    -e "s/@SELECTION@/$(rgb "$color8")/g" \
    "$TEMPLATE" > "$OUT"
