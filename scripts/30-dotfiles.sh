#!/usr/bin/env bash
# 30-dotfiles.sh — install the rice's dotfile tree from this repo into ~/.config.
#
# No clobbering without backup. Existing files get moved into
# ~/.config-backup/<TS>/ first, then the new configs layered on.
#
# Doesn't run any daemons — just lays files down. After this, see the
# README for the post-install session-start procedure.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user."
    exit 1
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CFG_SRC="$REPO_ROOT/config"
TS=$(date +%Y%m%d-%H%M%S)
BAK="$HOME/.config-backup-$TS"

if [[ ! -d "$CFG_SRC" ]]; then
    echo "Expected $CFG_SRC to exist — was README not followed?"
    exit 1
fi

echo "==> Backing up current ~/.config to $BAK"
mkdir -p "$BAK"
if [[ -d "$HOME/.config" ]]; then
    cp -a "$HOME/.config/." "$BAK/"
fi

echo "==> Copying rice configs into ~/.config"
# Make target dirs as needed, one per top-level component.
mkdir -p "$HOME/.config"
cp -a "$CFG_SRC/." "$HOME/.config/"

# The rofi keybind menu is the rice's one compiled component: the repo
# tracks only the .cpp (the binary is gitignored), so rebuild it on every
# deploy — regenerated like the rest of the rice, never hand-maintained.
echo "==> Building rofi keybind menu (g++)"
g++ -std=c++17 -O2 -Wall -Wextra \
    -o "$HOME/.config/rofi/keybind-menu" \
    "$CFG_SRC/rofi/keybind-menu.cpp"

# Mail transport/sync configs and Neomutt account files contain user
# addresses — installed from the public examples only, and never
# overwrite an existing personalized copy.
for pair in \
    "msmtp/config" \
    "isync/mbsyncrc" \
    "neomutt/accounts/gmail.muttrc" \
    "neomutt/accounts/other.muttrc"; do
    target="$HOME/.config/$pair"
    example="$HOME/.config/${pair}.example"
    if [[ ! -f "$target" && -f "$example" ]]; then
        cp -a "$example" "$target"
    fi
done

# config/applications/ only exists as the source for the .desktop install
# below — it does NOT belong under ~/.config/ (nothing reads
# ~/.config/applications/). Remove the stray copy the blanket cp made;
# the real copy lands in ~/.local/share/applications/. Anything removed
# here is recoverable from the $BAK backup taken above.
rm -rf "$HOME/.config/applications"

# Hyprland's `source = ~/.config/hypr/keybinds-extra.conf` line cannot
# take shell redirects, so the file MUST exist for the compositor to load
# the main config without error. cp -a above covers this from the repo's
# config/hypr/keybinds-extra.conf, but defensively touch it here too in
# case the repo file was deleted after install:
mkdir -p "$HOME/.config/hypr"
touch "$HOME/.config/hypr/keybinds-extra.conf"

# The rice ships a zed-handler.desktop file under config/applications/.
# (~/.local/share/applications/). Also refresh the desktop database so
# the file is picked up immediately by xdg-mime and rofi.
echo "==> Installing zed-handler.desktop into ~/.local/share/applications/"
mkdir -p "$HOME/.local/share/applications"
if [[ ! -f "$CFG_SRC/applications/zed-handler.desktop" ]]; then
    echo "Expected $CFG_SRC/applications/zed-handler.desktop to exist."
    exit 1
fi
cp -f "$CFG_SRC/applications/zed-handler.desktop" "$HOME/.local/share/applications/"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || \
    echo "    (update-desktop-database not available — install desktop-file-utils)"

# A couple of paths need to be created/written by tooling on first run;
# make them now so nothing errors out.
mkdir -p "$HOME/.cache/wal"

# Offer the daily on-demand scan. clamonacc/on-access scanning is not
# enabled because fanotify scanning on every file event costs performance.
chmod +x "$HOME/.config/clamav/scan-targets.sh"
chmod +x "$HOME/.config/croft/croft-launch.sh"
chmod +x "$HOME/.config/ox/ox-theme.sh" "$HOME/.config/ox/ox-launch.sh"
chmod +x "$HOME/.config/neomacs/neomacs-launch.sh"
systemctl --user daemon-reload
read -r -p "Enable the daily ClamAV user scan timer? [y/N] " enable_clamav
if [[ "$enable_clamav" =~ ^[Yy]$ ]]; then
    systemctl --user enable --now clamav-scan.timer
else
    echo "    ClamAV timer left disabled; run systemctl --user enable --now clamav-scan.timer when ready."
fi

# Calendar sync is opt-in until the user fills the OAuth example.
if [[ -f "$HOME/.config/vdirsyncer/config" ]]; then
    systemctl --user daemon-reload
    systemctl --user enable --now vdirsyncer-google.timer
else
    echo "    vdirsyncer config not present; copy config.example after adding OAuth credentials."
fi
chmod 600 "$HOME/.config/msmtp/config" "$HOME/.config/isync/mbsyncrc"

# Zed follows the palette through a symlinked custom theme: wal renders
# config/wal/templates/colors-zed.json into ~/.cache/wal/colors-zed.json,
# presets copy theirs into the same path (switch-theme.sh), and Zed
# hot-reloads theme files on change. The link is made here because wal
# itself will only ever write under ~/.cache/wal/.
mkdir -p "$HOME/.config/zed/themes"
ln -sf "$HOME/.cache/wal/colors-zed.json" "$HOME/.config/zed/themes/pywal.json"

echo "==> Generating first pywal palette from wallpaper (if set)"
WALLPAPER="$HOME/.config/hypr/wallpaper.jpg"
chmod +x "$HOME/.config/hypr/switch-theme.sh"
if [[ -f "$WALLPAPER" ]]; then
    wal -i "$WALLPAPER" -q
    echo "    wal ran. colors at ~/.cache/wal/colors.sh"
else
    echo "    no wallpaper at $WALLPAPER — hypr/wallpaper.jpg is a TODO."
    echo "    drop a jpg there and run: wal -i ~/.config/hypr/wallpaper.jpg"
    # No wallpaper yet: seed the default preset so waybar/rofi/nvim have
    # colors on first boot. switch-theme.sh writes into ~/.cache/wal/;
    # running `wal -i` later switches back to wallpaper mode.
    "$HOME/.config/hypr/switch-theme.sh" mocha
fi
"$HOME/.config/ox/ox-theme.sh"

echo
echo "==> Next steps:"
echo "      1. Edit ~/.config/hypr/hyprland.conf  -> set monitor= from 'hyprctl monitors'"
echo "      2. Drop a wallpaper at ~/.config/hypr/wallpaper.jpg"
echo "      3. Re-login -> pick Hyprland in SDDM"
echo "      4. ./40-gaming.sh for gaming extras (if not already run)"
echo "==> DONE"
