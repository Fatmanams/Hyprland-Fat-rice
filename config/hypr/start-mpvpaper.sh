#!/usr/bin/env bash
# Start one animated wallpaper process per connected Hyprland monitor.
# Keeping discovery here avoids hardcoding eDP/DP output names.

set -uo pipefail

video="$HOME/.config/hypr/wallpaper.mp4"
[[ -f "$video" ]] || exit 0

while IFS= read -r monitor; do
    [[ -n "$monitor" ]] || continue
    mpvpaper -o "--loop --no-audio --panscan=1" "$monitor" "$video" &
done < <(hyprctl monitors -j | jq -r '.[].name')
