#!/usr/bin/env bash
# 20-sddm.sh — install the static sddm-astronaut-theme asset directly.
#
# This is a static asset repo (QML/JS/CSS for the SDDM greeter), no
# compile step. Bare git clone straight from upstream into
# /usr/share/sddm/themes per the README.
#
# SAFETY (per your rollback plan):
#   1. Does NOT remove the plasma/kde session entries — they stay selectable.
#   2. Snapshots /etc/sddm.conf.d and /usr/share/sddm/themes before changes.
#   3. Records the currently-working Current= value into a revert file.
#   4. Edits metadata.desktop to pick the "astronaut" sub-theme.
#
# RECOVERY (also in the README): if SDDM renders black after install:
#   Ctrl+Alt+F3 -> sudo systemctl stop sddm
#   -> sudo systemctl edit --full sddm (or revert metadata.desktop)
#   -> sudo systemctl start sddm
# The snapshot at /root/sddm-snap.<TS> has your previous files.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user (it sudos internally)."
    exit 1
fi

THEME_DIR=/usr/share/sddm/themes/sddm-astronaut-theme
THEME_REPO=https://github.com/Keyitdev/sddm-astronaut-theme.git
SDDM_CONF_DIR=/etc/sddm.conf.d
TS=$(date +%Y%m%d-%H%M%S)
SNAP=/root/sddm-snap.$TS

echo "==> [1/5] Installing sddm-astronaut deps from official repos"
sudo pacman -S --needed --noconfirm \
    qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg \
    sddm

echo "==> [2/5] Snapshotting current SDDM state to $SNAP"
sudo mkdir -p "$SNAP"
[[ -d "$SDDM_CONF_DIR" ]] && sudo cp -a "$SDDM_CONF_DIR" "$SNAP/sddm.conf.d"
[[ -d /usr/share/sddm/themes ]] && sudo cp -a /usr/share/sddm/themes "$SNAP/themes"
CURRENT_THM=$(
    grep -E '^Current=' $SDDM_CONF_DIR/*.conf 2>/dev/null | tail -n1 | cut -d= -f2 || true
)
echo "$CURRENT_THM" | sudo tee "$SNAP/PREVIOUS_Current.txt" >/dev/null
echo "    Previous Current= recorded in $SNAP/PREVIOUS_Current.txt (value: '$CURRENT_THM')"

echo "==> [3/5] Cloning theme (depth=1, master) to $THEME_DIR"
if [[ -d "$THEME_DIR/.git" ]]; then
    echo "    Existing clone — pulling latest master."
    sudo git -C "$THEME_DIR" pull --ff-only
else
    if [[ -d "$THEME_DIR" ]]; then
        echo "    $THEME_DIR exists without .git — moving to $THEME_DIR.bak.$TS"
        sudo mv "$THEME_DIR" "$THEME_DIR.bak.$TS"
    fi
    sudo git clone -b master --depth 1 "$THEME_REPO" "$THEME_DIR"
fi

echo "==> [4/5] Selecting 'astronaut' sub-theme in metadata.desktop"
META="$THEME_DIR/metadata.desktop"
if [[ -f "$META" ]]; then
    # Keyitdev's metadata.desktop ships ConfigFile=Themes/<name>.conf —
    # the greeter resolves that path relative to the theme dir. Upstream
    # master (v1.4, Theme-API=2.0) already defaults to
    # Themes/astronaut.conf; pin it so a later upstream default change
    # can't silently swap the sub-theme.
    if grep -q '^ConfigFile=' "$META"; then
        sudo sed -i 's|^ConfigFile=.*|ConfigFile=Themes/astronaut.conf|' "$META"
        echo "    metadata.desktop -> ConfigFile=Themes/astronaut.conf"
    else
        echo "  !! metadata.desktop has no ConfigFile= line — theme layout changed upstream."
        echo "     NOT enabling sddm.service. Stop and review $META."
        exit 1
    fi
    # Fail loudly BEFORE sddm.service is enabled: the ConfigFile value
    # the greeter will actually load must resolve to a file inside the
    # clone. (The old sed wrote ' astronaut.conf' — unresolvable, so
    # the greeter silently fell back to its defaults.)
    CFG=$(sed -n 's|^ConfigFile=||p' "$META" | tail -n1 || true)
    CFG="${CFG#"${CFG%%[![:space:]]*}"}"
    CFG="${CFG%"${CFG##*[![:space:]]}"}"
    if [[ -z "$CFG" || ! -f "$THEME_DIR/$CFG" ]]; then
        echo "  !! ConfigFile '$CFG' does not resolve inside the clone:"
        echo "     $THEME_DIR/$CFG not found — theme layout changed upstream."
        echo "     NOT enabling sddm.service. Stop and review."
        exit 1
    fi
    echo "    ConfigFile resolves inside the clone: $CFG"
    if ! grep -q '^Name=' "$META"; then
        echo "    (metadata.desktop has no Name= line — review manually)"
    fi
else
    echo "  !! metadata.desktop not found at $META — theme layout may have changed. Stop and review."
    exit 1
fi

echo "==> [5/5] Enabling sddm.service and pointing Current= at the theme"
sudo systemctl enable sddm
SDDM_CONF="$SDDM_CONF_DIR/10-theme.conf"
sudo mkdir -p "$SDDM_CONF_DIR"
if [[ ! -f "$SDDM_CONF" ]]; then
    sudo tee "$SDDM_CONF" >/dev/null <<'EOF'
[Theme]
Current=sddm-astronaut-theme
EOF
else
    sudo sed -i 's|^Current=.*|Current=sddm-astronaut-theme|' "$SDDM_CONF"
fi

echo
echo "==> Preview (you should see the greeter in a window):"
echo "      sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
echo
echo "==> Snapshot kept at $SNAP — delete it manually once you confirm it's stable."
echo "==> Next: ./30-dotfiles.sh"
