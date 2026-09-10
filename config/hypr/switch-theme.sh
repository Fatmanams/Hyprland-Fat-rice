#!/usr/bin/env bash
# switch-theme.sh — switch the rice palette between shipped presets.
#
# The rice reads its colors from ~/.cache/wal/ files (AGENTS.md color
# palette contract). Normally pywal16 generates them from the wallpaper
# (`wal -i`); this script instead applies one of the static presets
# under themes/ (next to this file), overwriting the same files so
# waybar / swaync / rofi / eww / wlogout / nvim / emacs all pick them up.
#
# Each preset dir MUST carry every pywal output format the rice consumes
# (colors-waybar.css, colors-rofi.rasi, colors-wal.vim, colors.el,
# colors.sh, colors-zed.json, colors-hyprland.conf) — see AGENTS.md's
# palette contract. Adding a consumer that reads a new format means
# adding that file to every preset AND to the cp below with the same name,
# or theme switching leaves it on a stale palette.
#
# Usage:
#   switch-theme.sh <name>   apply a preset: mocha | gruvbox | tokyonight | osaka-jade
#   switch-theme.sh cycle    step to the next preset (SUPER+SHIFT+T bind)
#   switch-theme.sh current  print the active mode
#
# Running `wal -i <wallpaper>` switches back to wallpaper mode (it
# overwrites these files). VLC is NOT rethemed by this script. Ghostty
# is: it can't @import CSS, so ghostty-theme.sh (called below) converts
# colors.sh into Ghostty's own config format and reloads it.

set -euo pipefail

THEMES=(mocha gruvbox tokyonight osaka-jade)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
THEME_SRC="$SCRIPT_DIR/themes"
WAL_DIR="$HOME/.cache/wal"
MARKER="$WAL_DIR/current-theme"

apply() {
    local name=$1
    if [[ ! -d "$THEME_SRC/$name" ]]; then
        echo "Unknown theme '$name'. Available: ${THEMES[*]}" >&2
        exit 1
    fi
    mkdir -p "$WAL_DIR"
    cp -f "$THEME_SRC/$name/colors-waybar.css" \
          "$THEME_SRC/$name/colors-rofi.rasi" \
          "$THEME_SRC/$name/colors-wal.vim" \
          "$THEME_SRC/$name/colors.el" \
          "$THEME_SRC/$name/colors.sh" \
          "$THEME_SRC/$name/colors-zed.json" \
          "$THEME_SRC/$name/colors-hyprland.conf" \
          "$WAL_DIR/"
    echo "$name" > "$MARKER"

    # Ghostty too — it reads its own colors.conf, not wal's CSS/rasi
    # formats (see config/ghostty/ghostty-theme.sh). Never let a hook
    # hiccup abort the rest of the switch.
    "$HOME/.config/ghostty/ghostty-theme.sh" || true

    echo "Theme applied: $name (running 'wal -i' returns to wallpaper mode)"

    # Reload the components that read colors at startup.
    if command -v waybar >/dev/null 2>&1 && pgrep -x waybar >/dev/null 2>&1; then
        killall waybar 2>/dev/null || true
        (waybar >/dev/null 2>&1 &)
    fi
    if command -v eww >/dev/null 2>&1 && eww ping >/dev/null 2>&1 \
            && eww windows 2>/dev/null | grep -q bar_main; then
        eww close bar_main 2>/dev/null || true
        eww open bar_main 2>/dev/null || true
    fi
    if command -v swaync-client >/dev/null 2>&1 \
            && pgrep -x swaync >/dev/null 2>&1; then
        swaync-client --reload-config >/dev/null 2>&1 || true
        swaync-client --reload-style >/dev/null 2>&1 || true
    fi
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
    if command -v emacsclient >/dev/null 2>&1; then
        emacsclient --eval '(load-file (expand-file-name "~/.config/emacs/init.el"))' \
            >/dev/null 2>&1 || true
    fi
    # Rofi and wlogout are transient; they read the new palette next time
    # they launch. Neomutt and ikhal likewise start with the current files.
    # Nvim reapplies its palette when an existing session regains focus.
}

cycle() {
    local cur="${THEMES[${#THEMES[@]}-1]}"   # no marker -> wrap to first
    if [[ -f "$MARKER" ]]; then
        cur=$(cat "$MARKER")
    fi
    local i next=0
    for i in "${!THEMES[@]}"; do
        if [[ "${THEMES[$i]}" == "$cur" ]]; then
            next=$(( (i + 1) % ${#THEMES[@]} ))
            break
        fi
    done
    apply "${THEMES[$next]}"
}

case "${1:-}" in
    cycle)   cycle ;;
    current)
        if [[ -f "$MARKER" ]]; then
            echo "theme mode: $(cat "$MARKER")"
        else
            echo "wallpaper mode (pywal)"
        fi
        ;;
    "")
        echo "Usage: switch-theme.sh {$(IFS='|'; echo "${THEMES[*]}")|cycle|current}" >&2
        exit 1
        ;;
    *)       apply "$1" ;;
esac
