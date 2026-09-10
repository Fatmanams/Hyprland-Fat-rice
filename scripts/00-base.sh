#!/usr/bin/env bash
# 00-base.sh — official-repo installs only. No AUR, no makepkg, no curl|bash.
#
# What this does:
#   1. Enables [multilib] (needed for lib32-mangohud / Steam's wine deps).
#   2. Sets MAKEFLAGS to -j$(nproc) and enables ccache in /etc/makepkg.conf
#      — affects AUR builds done later by 10-aur.sh.
#   3. Installs the official-repo portion of the rice from pacman.
#   4. Installs the shared language-server stack. These are plain
#      binaries on $PATH, NOT editor plugins: Zed discovers them itself,
#      Emacs drives them via eglot (in Emacs core since 29 — no
#      package manager needed), and nvim wires them through the
#      nvim-lspconfig plugin block in config/nvim/init.lua.
#      The HTML/CSS/JSON/ESLint servers are AUR-only
#      (vscode-langservers-extracted) and are built by 10-aur.sh.
#   5. Post-install setup: xdg user dirs, bluetooth.service, ufw baseline,
#      ClamAV freshclam (antivirus signature autoupdate).
#   6. GPU driver layer — NVIDIA proprietary or Intel/AMD Mesa.
#   7. Optional: sets the CPU governor to `performance` via cpupower
#      (desktop gaming rig tradeoff — see the block's own comment).
#   8. Optional: installs Emacs (emacs-wayland — the PGTK/native-Wayland
#      build) as a Zed/nvim alternative IDE.
#
# Run this as a normal user (it will sudo internally where needed).
# Review it before running. Nothing is silent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Don't run this as root. Run as your normal user; it'll sudo where needed."
    exit 1
fi

echo "==> [1/8] Enabling [multilib] in /etc/pacman.conf"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    echo "    multilib enabled."
else
    echo "    multilib already enabled."
fi
if ! awk '
    /^\[multilib\]$/ { in_multilib=1; next }
    /^\[/ { in_multilib=0 }
    in_multilib && /^Include = \/etc\/pacman\.d\/mirrorlist$/ { found=1 }
    END { exit !found }
' /etc/pacman.conf; then
    sudo sed -i '/^#Include = \/etc\/pacman\.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    echo "    multilib mirrorlist enabled."
fi
sudo pacman -Syu --noconfirm

echo "==> [2/8] Configuring /etc/makepkg.conf for parallelism + ccache + native tuning"
MAKEPKG=/etc/makepkg.conf
if ! grep -q '^MAKEFLAGS="-j' "$MAKEPKG"; then
    sudo sed -i "s|^#MAKEFLAGS=\"-j2\"|MAKEFLAGS=\"-j$(nproc)\"|" "$MAKEPKG"
    echo "    MAKEFLAGS set to -j$(nproc)"
else
    echo "    MAKEFLAGS already set."
fi
if ! command -v ccache >/dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed ccache
fi
if grep -q '^BUILDENV=' "$MAKEPKG" && grep -q '!ccache' "$MAKEPKG"; then
    sudo sed -i 's|^BUILDENV=.*|BUILDENV=(!distcc !color ccache check !sign)|' "$MAKEPKG"
    echo "    ccache enabled in BUILDENV"
elif ! grep -q '^BUILDENV=.*\bccache\b' "$MAKEPKG"; then
    sudo sed -i 's|^BUILDENV=.*|BUILDENV=(!distcc !color ccache check !sign)|' "$MAKEPKG"
    echo "    ccache enabled in BUILDENV"
else
    echo "    ccache already in BUILDENV"
fi

# Everything the rice actually compiles (the AUR set in 10-aur.sh) gets
# CPU-native flags — prefer compiled-and-native for what's built anyway.
# pacman binaries stay upstream generic x86-64 (rebuilding those would
# be a source distro, not a rice). -march=native implies -mtune=native;
# O2 stays (O3 here is all cost, no measurable win).
if ! grep -q -- '-march=native' "$MAKEPKG"; then
    sudo sed -i -E 's|^((C|CXX)FLAGS=")-march=x86-64 -mtune=generic|\1-march=native|' "$MAKEPKG"
    echo "    CFLAGS/CXXFLAGS retargeted to -march=native (AUR builds)"
fi
if ! grep -q '^RUSTFLAGS=' "$MAKEPKG"; then
    # Stock makepkg.conf only ships a commented #RUSTFLAGS= line;
    # makepkg sources the file, so a trailing assignment wins.
    echo 'RUSTFLAGS="-C target-cpu=native"' | sudo tee -a "$MAKEPKG" >/dev/null
    echo "    RUSTFLAGS set to -C target-cpu=native (AUR builds)"
fi

echo "==> [3/8] Installing rice packages from official repos"
sudo pacman -S --needed --noconfirm \
    hyprland hypridle hyprlock hyprcursor hyprpaper hyprutils hyprlang \
    wayland wayland-protocols \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    xdg-utils xdg-user-dirs file \
    qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6ct qt5ct \
    sddm \
    rofi-wayland \
    swaync \
    waybar kanshi \
    grim slurp wl-clipboard \
    wlsunset \
    ghostty kitty alacritty \
    fish \
    nano neovim \
    polkit polkit-gnome polkit-kde-agent gnome-keyring seahorse \
    NetworkManager \
    pipewire wireplumber \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation ttf-dejavu \
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols \
    fontconfig \
    jq curl wget git base-devel \
    neomutt isync msmtp gnupg khal vdirsyncer \
    gcc clang make cmake meson ninja pkgconf \
    imagemagick ffmpeg \
    pciutils mesa-demos \
    hicolor-icon-theme adwaita-icon-theme papirus-icon-theme sound-theme-freedesktop \
    gamemode gamescope mangohud lib32-mangohud steam \
    nwg-look kvantum kvantum-qt5 \
    swww cliphist \
    ripgrep fd zoxide chafa \
    poppler \
    yazi thunar tumbler thunar-archive-plugin thunar-volman gvfs \
    vlc \
    yt-dlp streamlink \
    bitwarden \
    bluez bluez-utils blueman \
    ufw \
    clamav apparmor firejail \
    kde-cli-tools

echo "==> [4/8] Language servers (shared by Zed and Emacs/eglot)"
# These are standalone LSP server binaries on $PATH — not editor plugins.
# Who consumes them:
#   * Zed  — discovers servers from $PATH itself (no settings.json entry
#            needed; config/zed/settings.json deliberately has none).
#   * Emacs — via eglot, which is part of Emacs core since 29 (`M-x eglot`
#            in a project buffer). That's what keeps config/emacs/init.el
#            free of any package manager, matching init.lua's philosophy.
#   * nvim  — wired into these servers by nvim-lspconfig (lazy.nvim
#     plugin block in init.lua, added when the editor plugin rule was
#     lifted). If a server binary is missing, that filetype just edits
#     without LSP — nothing crashes.
#
# Installed as a separate transaction from the main rice list so a failure
# here is obviously an editor-tooling failure, not a desktop one.
#
# Package names verified against the official Arch package DB, not memory
# (repo/version at time of writing):
#   pyright 1.1.411 (extra/any)   rust-analyzer 20260608 (extra/x86_64)
#   clang 22.1.8 (extra/x86_64 — provides clangd via clang-tools-extra)
#   lua-language-server 3.19.1 (extra/x86_64)
#   bash-language-server 5.6.0 (extra/any)
#   gopls 0.23.0 (extra/x86_64)
#   typescript-language-server 5.1.3 (extra/any)
# HTML/CSS/JSON/ESLint servers (vscode-langservers-extracted) are NOT in
# official repos — AUR-only, so they go through 10-aur.sh's reviewed
# reviewed source-build pipeline, not here.
sudo pacman -S --needed --noconfirm \
    pyright \
    rust-analyzer \
    clang \
    lua-language-server \
    bash-language-server \
    gopls \
    typescript-language-server

echo "==> [5/8] Post-install setup: user dirs, Bluetooth, firewall"
xdg-user-dirs-update
echo "    xdg user dirs created/updated (~/Pictures, ~/Downloads, ...)."

sudo systemctl enable --now bluetooth.service
echo "    bluetooth.service enabled."

# Default-deny incoming / allow outgoing baseline for a personal desktop.
# NOTE: hosting game servers or LAN services (e.g. a Minecraft server)
# will need explicit `sudo ufw allow <port>` rules added later.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
# ufw --force enable only starts it for THIS boot; on Arch the firewall
# comes back after reboot only if ufw.service is enabled (ArchWiki).
sudo systemctl enable --now ufw.service
echo "    ufw active and enabled at boot: deny incoming, allow outgoing."

# ClamAV: only the signature updater is enabled (unit name verified
# against the clamav package file list). Scanning itself is on-demand
# (`clamscan <path>`); the resident daemon (clamav-daemon.service) stays
# off until you opt in — most desktops don't need it running.
sudo systemctl enable --now clamav-freshclam.service
echo "    clamav-freshclam.service enabled: virus DB keeps itself current."

# NOTE: apparmor (installed above) is deliberately NOT activated here.
# It needs `lsm=landlock,lockdown,yama,integrity,apparmor,bpf` on the
# kernel cmdline first — that's a hand-edit of YOUR bootloader entry
# (README -> Mandatory first-boot TODOs), same philosophy as the
# monitor=/wallpaper stopgaps: this script never touches boot config.

echo "==> [6/8] GPU driver layer (NVIDIA or Intel/AMD — pick one)"
GPU_CHOSEN=0
CURRENT_GPU=$(lspci -nn 2>/dev/null | grep -Ei '(VGA compatible controller|3D controller|Display controller)' || true)
echo "    Detected GPU line: ${CURRENT_GPU:-unknown}"

if echo "$CURRENT_GPU" | grep -qi 'nvidia'; then
    echo "    Looks NVIDIA. Will install: nvidia nvidia-utils lib32-nvidia-utils"
    echo "    (If that's wrong, Ctrl-C now, then re-run and pick manually.)"
    read -r -p "    Proceed with NVIDIA drivers? [Y/n] " yn
    if [[ "$yn" =~ ^[Nn]$ ]]; then
        GPU_CHOSEN=0
    else
        sudo pacman -S --needed --noconfirm nvidia nvidia-utils
        sudo pacman -S --needed --noconfirm --overwrite '/usr/lib32/libGL*' lib32-nvidia-utils
        GPU_CHOSEN=1
        echo "    NVIDIA installed. Make sure kernel cmdline has:"
        echo "      nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
        echo "    (grub: /etc/default/grub -> GRUB_CMDLINE_LINUX_DEFAULT -> update-grub; systemd-boot: /etc/kernel/cmdline -> reinstall linux-lts)"
    fi
fi

if [[ $GPU_CHOSEN -eq 0 ]]; then
    echo "    Installing Intel/AMD open stack (works on both):"
    sudo pacman -S --needed --noconfirm \
        mesa lib32-mesa \
        vulkan-radeon lib32-vulkan-radeon \
        vulkan-intel lib32-vulkan-intel \
        intel-media-driver libva-mesa-driver mesa-vdpau \
        vulkan-mesa-layers lib32-vulkan-mesa-layers
fi

echo "==> [7/8] CPU performance governor (cpupower) — desktop gaming tradeoff"
# Installs `cpupower` (official extra) and sets the scaling governor to
# `performance`. Read this comment before accepting — it's a deliberate
# tradeoff, not a "free speed":
#   + lower input latency, more consistent frame times in games
#   - the CPU spends less time in deep idle, so idle/light loads run
#     hotter and the fans spin up sooner. Reasonable for a desktop
#     gaming box; NOT something to silently reuse on a laptop config
#     (battery). Reuse this rice on a laptop? Remove this block or
#     flip the governor to `schedutil`/`powersave`.
#
# Driver reality (verified against the ArchWiki "CPU frequency scaling"
# page, 2026-08): on modern AMD Zen (incl. the Ryzen 5 PRO 4650G this
# rice targets) the kernel may load `amd_pstate` in *active* (EPP) mode,
# where `performance`/`powersave` become an energy-preference HINT to
# the hardware's autonomous governor rather than a hard frequency lock
# (different from the classic acpi-cpufreq hard-governor model). We set
# `performance` either way — the literal is accepted by both drivers —
# but the *effect* differs. Verify on the target with:
#   cpupower frequency-info | grep -i driver
#   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
#
# We do NOT disable Spectre/Meltdown mitigations (mitigations=off) here —
# that's a real security tradeoff this rice declines to make by default.
# It's left as a manual, off-by-default kernel-cmdline opt-in you'd add
# yourself in /etc/default/grub or /boot/loader/entries, not something
# this script touches.
sudo pacman -S --needed --noconfirm cpupower

# cpupower.service reads its config from /etc/default/. The package has
# shipped TWO different filenames across versions (the ArchWiki itself
# quotes both `cpupower-service.conf` AND `cpupower` — a known doc
# inconsistency). Detect the real path the installed systemd unit sources
# rather than hardcode a guess that would silently write a file nothing
# reads (the exact memory-vs-verified trap this repo keeps catching).
CPUPOWER_CONF=""
for cand in /etc/default/cpupower-service.conf /etc/default/cpupower; do
    # Match the file the installed /usr/lib/systemd/scripts/cpupower actually
    # sources, if grep-able there.
    if grep -q "[\"']${cand}[\"']" /usr/lib/systemd/scripts/cpupower 2>/dev/null \
       || [[ -f "$cand" ]]; then
        CPUPOWER_CONF="$cand"
        break
    fi
done
if [[ -z "$CPUPOWER_CONF" ]]; then
    echo "    !! Could not auto-detect cpupower's config file path."
    echo "       Check 'cat /usr/lib/systemd/scripts/cpupower' for the source line"
    echo "       and set the governor manually: cpupower frequency-set -g performance"
else
    sudo tee "$CPUPOWER_CONF" >/dev/null <<'EOF'
# Set by linux-rice 00-base.sh. Restore the stock default by deleting the
# `governor=` line below and re-running: sudo systemctl restart cpupower
governor='performance'
EOF
    echo "    wrote $CPUPOWER_CONF  (governor='performance')"
    sudo systemctl enable --now cpupower.service
    echo "    cpupower.service enabled. Verify: cpupower frequency-info"
fi

echo "==> [8/8] Emacs — OPTIONAL editor/IDE (Zed + nvim already cover this)"
# Emacs is opt-in: it's a ~264MB installed Lisp image and most users of
# this rice edit in Zed (GUI) or nvim (terminal). Say yes only if you
# actually want it; the config at config/emacs/init.el follows the same
# no-plugin-manager philosophy as init.lua, with pywal-driven colors via
# the config/wal/templates/colors.el template. LSP comes from eglot
# (Emacs core since 29) driving the servers installed in step [4/8] —
# nothing extra to install.
#
# WHICH PACKAGE: `emacs-wayland`, not `emacs`. Both are the same 30.2
# source; emacs-wayland is the PGTK build (`provides=emacs`,
# `conflicts=emacs`) that talks Wayland natively instead of going through
# XWayland — the right pick for a Hyprland rice, same reasoning as
# QT_QPA_PLATFORM=wayland for Qt apps. Verified on
# archlinux.org/packages/extra/x86_64/emacs-wayland/.
#
# Decline and nothing Emacs-related is installed; 30-dotfiles.sh still
# copies config/emacs/ into ~/.config/ (it's a blanket copy of config/),
# where it sits inert without the binary — `rm -rf ~/.config/emacs` to
# tidy up.
read -r -p "    Install Emacs (optional)? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm emacs-wayland
    echo "    emacs-wayland (PGTK) installed. Config at ~/.config/emacs/init.el"
    echo "    LSP: open a project file and run 'M-x eglot' (no plugins needed)."
else
    echo "    Skipped Emacs. (config/emacs/ files are still copied by 30-dotfiles.sh,"
    echo "    but ignored without the binary — remove ~/.config/emacs to tidy up.)"
fi

echo "==> DONE. Next: ./10-aur.sh"
