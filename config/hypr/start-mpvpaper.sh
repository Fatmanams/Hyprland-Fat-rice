#!/usr/bin/env bash
# Start one animated wallpaper process per connected Hyprland monitor.
# Keeping discovery here avoids hardcoding eDP/DP output names.

set -uo pipefail

video="$HOME/.config/hypr/wallpaper.mp4"
[[ -f "$video" ]] || exit 0

monitors=""
for _ in {1..10}; do
    monitors=$(hyprctl monitors -j 2>/dev/null || true)
    jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$monitors" && break
    sleep 1
done

if ! jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$monitors"; then
    echo "Unable to discover Hyprland monitors for animated wallpaper." >&2
    exit 1
fi

while IFS= read -r monitor; do
    [[ -n "$monitor" ]] || continue
    mpvpaper -o "--loop --no-audio --panscan=1" "$monitor" "$video" &
done < <(jq -r '.[].name' <<<"$monitors")
