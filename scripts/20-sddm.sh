#!/usr/bin/env bash
# 20-sddm.sh — install the static sddm-astronaut-theme asset directly.
#
# This is a static asset repo (QML/JS/CSS for the SDDM greeter), no
# compile step. It installs at a pinned upstream commit (THEME_REF):
# the clone and the checkout run as the normal user in a throwaway
# temp dir, root only copies the reviewed files into
# /usr/share/sddm/themes and records the pin in
# $THEME_DIR/.rice-pinned-ref. Re-runs on the same pin are a no-op; a
# changed pin shows the OLD..NEW diff and asks before replacing. git
# never runs as root here, and nothing is ever pulled in place.
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
# Pinned upstream commit (the repo ships no tags). Bumping it means
# reviewing the OLD..NEW diff first — same obligation as an AUR
# PKGBUILD bump. Recorded on every install in .rice-pinned-ref.
THEME_REF=abb3163c724935af888ba5ea9ac0c4f22afd8048
SDDM_CONF_DIR=/etc/sddm.conf.d
TS=$(date +%Y%m%d-%H%M%S)
SNAP=/root/sddm-snap.$TS
WORK=""

cleanup() {
    if [[ -n "$WORK" && -d "$WORK" ]]; then
        rm -rf "$WORK"
    fi
}
trap cleanup EXIT

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

echo "==> [3/5] Installing theme at pinned commit $THEME_REF"
OLD_REF=""
NEED_SYNC=1
if [[ -d "$THEME_DIR" ]]; then
    OLD_REF=$(sudo cat "$THEME_DIR/.rice-pinned-ref" 2>/dev/null || true)
    if [[ -z "$OLD_REF" && -f "$THEME_DIR/.git/HEAD" ]]; then
        # Install predates pinning: the old script left a root-owned
        # clone. Read its checked-out commit straight out of .git so
        # git itself never runs as root on it.
        LEG_HEAD=$(sudo cat "$THEME_DIR/.git/HEAD" 2>/dev/null || true)
        if [[ "$LEG_HEAD" == "ref: "* ]]; then
            LEG_REF=${LEG_HEAD#ref: }
            OLD_REF=$(sudo cat "$THEME_DIR/.git/$LEG_REF" 2>/dev/null || true)
            if [[ -z "$OLD_REF" && -f "$THEME_DIR/.git/packed-refs" ]]; then
                OLD_REF=$(sudo awk -v ref="$LEG_REF" '$2 == ref {print $1; exit}' \
                    "$THEME_DIR/.git/packed-refs" 2>/dev/null || true)
            fi
        else
            OLD_REF=$LEG_HEAD
        fi
    fi
    if [[ "$OLD_REF" == "$THEME_REF" ]]; then
        echo "    Already at the pinned ref — nothing to fetch or copy."
        NEED_SYNC=0
    fi
fi

if [[ $NEED_SYNC -eq 1 ]]; then
    WORK=$(mktemp -d)
    git clone "$THEME_REPO" "$WORK/theme"
    git -C "$WORK/theme" checkout --detach "$THEME_REF"
    ACTUAL_REF=$(git -C "$WORK/theme" rev-parse HEAD)
    if [[ "$ACTUAL_REF" != "$THEME_REF" ]]; then
        echo "  !! checkout mismatch: HEAD is '$ACTUAL_REF', wanted '$THEME_REF'."
        echo "     NOT touching $THEME_DIR. Stop and review."
        exit 1
    fi
    if [[ -d "$THEME_DIR" ]]; then
        echo "    Existing install differs from the pin (installed: ${OLD_REF:-unknown})."
        if [[ -n "$OLD_REF" ]]; then
            if ! git -C "$WORK/theme" diff --stat "$OLD_REF..$THEME_REF"; then
                if ! git -C "$WORK/theme" diff --stat "$OLD_REF" "$THEME_REF"; then
                    echo "    (no diff available: $OLD_REF is not in the upstream history)"
                fi
            fi
        else
            echo "    (existing install has no readable pin — no diff to show)"
        fi
        REPLY=""
        read -r -p "    Replace $THEME_DIR with the pinned copy? [y/N] " REPLY || true
        case "$REPLY" in
            y|Y) ;;
            *)
                echo "    Declined — keeping the existing theme."
                exit 0
                ;;
        esac
        sudo mv "$THEME_DIR" "$THEME_DIR.bak.$TS"
    fi
    rm -rf "$WORK/theme/.git"
    sudo cp -a "$WORK/theme" "$THEME_DIR"
    sudo chown -R root:root "$THEME_DIR"
    printf '%s\n' "$THEME_REF" | sudo tee "$THEME_DIR/.rice-pinned-ref" >/dev/null
    rm -rf "$WORK"
    WORK=""
    echo "    Installed $THEME_REF (pin recorded in $THEME_DIR/.rice-pinned-ref)"
    if [[ -d "$THEME_DIR.bak.$TS" ]]; then
        echo "    Previous copy kept at $THEME_DIR.bak.$TS — delete it once the new theme is confirmed."
    fi
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
    # installed theme. (The old sed wrote ' astronaut.conf' —
    # unresolvable, so the greeter silently fell back to its defaults.)
    CFG=$(sed -n 's|^ConfigFile=||p' "$META" | tail -n1 || true)
    CFG="${CFG#"${CFG%%[![:space:]]*}"}"
    CFG="${CFG%"${CFG##*[![:space:]]}"}"
    if [[ -z "$CFG" || ! -f "$THEME_DIR/$CFG" ]]; then
        echo "  !! ConfigFile '$CFG' does not resolve inside the installed theme:"
        echo "     $THEME_DIR/$CFG not found — theme layout changed upstream."
        echo "     NOT enabling sddm.service. Stop and review."
        exit 1
    fi
    echo "    ConfigFile resolves inside the installed theme: $CFG"
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
