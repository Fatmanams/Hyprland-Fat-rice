#!/usr/bin/env bash
# 00-base.sh — official-repo installs only. No AUR, no makepkg, no curl|bash.
#
# What this does:
#   1. Enables [multilib] (needed for lib32-mangohud / Steam's wine deps).
#   2. Sets MAKEFLAGS to -j$(nproc) and enables ccache in /etc/makepkg.conf
#      — affects AUR builds done later by 10-aur.sh.
#   3. Installs the official-repo portion of the rice from pacman.
#
# Run this as a normal user (it will sudo internally where needed).
# Review it before running. Nothing is silent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Don't run this as root. Run as your normal user; it'll sudo where needed."
    exit 1
fi

echo "==> [1/3] Enabling [multilib] in /etc/pacman.conf"
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
sudo pacman -Syu --needed --noconfirm

echo "==> [2/3] Configuring /etc/makepkg.conf for parallelism + ccache"
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

echo "==> [3/3] Installing rice packages from official repos"
sudo pacman -S --needed --noconfirm \
    hyprland hypridle hyprlock hyprcursor hyprpaper hyprutils hyprlang \
    wayland wayland-protocols \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    xdg-utils file \
    qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6ct qt5ct \
    sddm \
    rofi-wayland \
    swaync \
    swayidle swaybg sway \
    waybar wob kanshi \
    dunst \
    grim slurp wl-clipboard \
    wlsunset \
    ghostty kitty alacritty \
    zsh \
    nano neovim \
    polkit polkit-gnome polkit-kde-agent gnome-keyring seahorse \
    NetworkManager \
    pipewire wireplumber \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation ttf-dejavu \
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols \
    fontconfig \
    jq curl wget git base-devel \
    gcc clang make cmake meson ninja pkgconf \
    imagemagick ffmpeg \
    pciutils mesa-demos \
    hicolor-icon-theme adwaita-icon-theme papirus-icon-theme sound-theme-freedesktop \
    gamemode gamescope mangohud lib32-mangohud \
    nwg-look kvantum kvantum-qt5 \
    swww cliphist \
    ripgrep fd zoxide chafa \
    poppler \
    yazi thunar tumbler thunar-archive-plugin thunar-volman gvfs \
    vlc \
    kde-cli-tools

echo "==> [3.5/4] GPU driver layer (NVIDIA or Intel/AMD — pick one)"
GPU_CHOSEN=0
CURRENT_GPU=$(lspci -nn 2>/dev/null | grep -Ei '(VGA compatible controller|3D controller|Display controller):' || true)
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

echo "==> DONE. Next: ./10-aur.sh"
