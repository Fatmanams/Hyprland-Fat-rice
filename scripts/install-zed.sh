#!/usr/bin/env bash
# install-zed.sh — install just Zed (the editor), no full rice deploy.
#
# Use this when you want the editor on a box WITHOUT running the whole
# install pipeline. Does exactly three things and nothing else:
#   1. pacman: zed (official extra repo — no AUR)
#   2. config: copies this repo's config/zed/ into ~/.config/zed/
#   3. handler: installs zed-handler.desktop + xdg-mime defaults so
#      files open in Zed. If wal has never run, the "Pywal" theme is
#      skipped — settings.json's catppuccin fallback covers that case.
#
# It deliberately does NOT touch wallpaper/theme/state — no rice, no
# git changes, no services.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user; the script sudo's where needed." >&2
    exit 1
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"

echo "==> Installing Zed (official repo)"
sudo pacman -S --needed --noconfirm zed

echo "==> Installing Zed config into ~/.config/zed/"
mkdir -p "$HOME/.config/zed"
cp -a "$REPO_ROOT/config/zed/." "$HOME/.config/zed/"
# The pywal theme symlink only resolves after a `wal -i` or switch-theme.sh
# run; it harmlessly dangles until then, and catppuccin covers first boot.
mkdir -p "$HOME/.cache/wal" "$HOME/.config/zed/themes"
if [[ -f $HOME/.cache/wal/colors-zed.json ]]; then
    ln -sf "$HOME/.cache/wal/colors-zed.json" "$HOME/.config/zed/themes/pywal.json"
fi

echo "==> Installing zed-handler.desktop + mime defaults"
mkdir -p "$HOME/.local/share/applications"
if [[ -f "$REPO_ROOT/config/applications/zed-handler.desktop" ]]; then
    chmod 644 "$HOME/.local/share/applications"
    cp -f "$REPO_ROOT/config/applications/zed-handler.desktop" \
        "$HOME/.local/share/applications/"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" || true
    fi
    for t in python c c++ lua java rust json javascript typescript toml yaml markdown shellscript plaintext; do
        xdg-mime default zed-handler.desktop "text/$t" 2>/dev/null || true
    done
    xdg-mime default zed-handler.desktop text/plain 2>/dev/null || true
    xdg-mime default zed-handler.desktop application/json 2>/dev/null || true
    echo "    Zed is now the default for code/text files."
else
    echo "    (config/applications/zed-handler.desktop missing — skipping mime wire-up.)"
fi

echo "==> Done. Run 'zed' or open a file with it."
