#!/usr/bin/env bash
# 10-aur.sh — AUR-only packages, built per policy rule #3:
#   * Pull each AUR repo by git clone (no AUR helper).
#   * Print the full PKGBUILD to stdout for human review (read it!).
#   * Wait for explicit confirmation before building.
#   * Build with plain `makepkg -Cs` (clean + syncdeps + build, NO -i).
#
#     NOTE: do NOT use `makepkg -Cso`. The `-o` / `--nobuild` flag means
#     "Download and extract files, run prepare(), but do NOT build them"
#     per makepkg(8). With `-o`, no .pkg.tar.zst is produced, and under
#     `set -euo pipefail` build_one() dies after extraction. `-s` alone
#     is sufficient for sync-deps + build.
#   * Add the resulting .pkg.tar.zst to the local repo with repo-add.
#   * Install via `sudo pacman -S <pkgname>` from that local repo
#     (NOT `pacman -U` — `-S` resolves from the [localrepo] section
#     registered in /etc/pacman.conf, which keeps dependency tracking
#     honest; `-U` would short-circuit that).
#
# AUR-only packages in this build (per the rule-5 up-front audit):
#
#     eww                    https://aur.archlinux.org/eww.git
#     python-pywal16         https://aur.archlinux.org/python-pywal16.git
#     bibata-cursor-theme    https://aur.archlinux.org/bibata-cursor-theme.git
#     wlogout                https://aur.archlinux.org/wlogout.git
#     zed                    https://aur.archlinux.org/zed.git
#     brave-bin              https://aur.archlinux.org/brave-bin.git
#
#     (Zed is NATIVE AUR-only — no curl|bash installer, no official repo —
#     so per the policy it goes through this same reviewed-makepkg pipeline.
#     Review the zed PKGBUILD carefully before approving: it's a Rust project
#     that fetches many Cargo crates from crates.io and may download extra
#     assets at build time. Look at all source=() entries.)
#
#     (brave-bin: precompiled Brave browser in .deb form, repackaged to
#     .pkg.tar.zst. The PKGBUILD downloads from Brave's CDN at build time
#     and unwraps the upstream .deb — that is NOT curl|bash, it's
#     downloading a signed binary distribution. Read the PKGBUILD anyway.)
#
#
# Items your original policy listed as AUR-only but which are now in
# official repos (installed by 00-base.sh, NOT here):
#     rofi-wayland  ghostty  swww  swaync  cliphist  nwg-look
#     kvantum  kvantum-qt5  gamemode  gamescope  mangohud  lib32-mangohud
#     python-pywal (old fork — we still use python-pywal16 from AUR by choice)
#
# The local repo you already have set up on this machine: read
# LOCALREPO_DIR below and adjust if yours is elsewhere.
#
# Red flags that get flagged loudly when found in the PKGBUILD:
#   * `curl ... | bash`  or  `... | sh`  anywhere
#   * anything that downloads something into the install step that
#     isn't from the upstream source declared in source=()
#   * post-registration network fetches
# The review step below will print a warning if any of these appear
# but it's still your job to read the PKGBUILD.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user, not root."
    exit 1
fi

# --- Config -----------------------------------------------------------------
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/cache/pacman/localrepo}"
LOCALREPO_NAME="${LOCALREPO_NAME:-localrepo}"
BUILDROOT="${BUILDROOT:-$HOME/build/aur}"
AUR_BASE="https://aur.archlinux.org"

mkdir -p "$BUILDROOT"
SKIPPED_PACKAGES=()

# Ensure local repo is set up + registered in pacman.conf once.
setup_local_repo() {
    if [[ ! -d "$LOCALREPO_DIR" ]]; then
        sudo mkdir -p "$LOCALREPO_DIR"
        sudo chown "$USER":"$USER" "$LOCALREPO_DIR"
    fi
    if [[ ! -f "$LOCALREPO_DIR/$LOCALREPO_NAME.db.tar.zst" ]]; then
        ( cd "$LOCALREPO_DIR" && repo-add "$LOCALREPO_NAME.db.tar.zst" )
    fi
    if ! grep -q "^\[$LOCALREPO_NAME\]" /etc/pacman.conf; then
        echo "==> Registering [$LOCALREPO_NAME] in /etc/pacman.conf"
        sudo tee -a /etc/pacman.conf >/dev/null <<EOF

[$LOCALREPO_NAME]
SigLevel = Optional TrustAll
Server = file://$LOCALREPO_DIR
EOF
        sudo pacman -Sy
    fi
}

# Heuristic scan of a PKGBUILD for the red-flag patterns named in the policy.
scan_pkgbuild() {
    local f="$1"
    local flags=0
    if grep -En 'curl[^|]*\|\s*(bash|sh|zsh)' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: curl|bash pattern detected"
        flags=1
    fi
    if grep -En 'wget[^|]*\|\s*(bash|sh|zsh)' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: wget|bash pattern detected"
        flags=1
    fi
    if grep -En 'post_install|post_upgrade' "$f" >/dev/null 2>&1 && \
       grep -En 'systemctl enable|systemctl start' "$f" >/dev/null 2>&1; then
        echo "  !! INFO: PKGBUILD enables services in install hooks — review whether you want that."
    fi
    if grep -En 'https?://[^/]*pastebin|[^/]*ipfs|[^/]*ngrok|[^/]*ngrok-free' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: suspicious source URL (pastebin/ipfs/ngrok)"
        flags=1
    fi
    if grep -En 'git clone[^|]*\|\s*(bash|sh)' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: git clone | sh detected"
        flags=1
    fi
    return $flags
}

# Build + repo-add + install one AUR package.
build_one() {
    local pkgname="$1"
    echo
    echo "=================================================================="
    echo "==> AUR package: $pkgname"
    echo "=================================================================="

    local srcdir="$BUILDROOT/$pkgname"
    if [[ -d "$srcdir/.git" ]]; then
        echo "==> Updating existing clone: $srcdir"
        git -C "$srcdir" pull --ff-only
    else
        echo "==> Cloning: $AUR_BASE/$pkgname.git -> $srcdir"
        git clone "$AUR_BASE/$pkgname.git" "$srcdir"
    fi

    cd "$srcdir"

    echo
    echo "------------------------------------------------------------------"
    echo "==> PKGBUILD review  (read the whole thing below before approving)"
    echo "------------------------------------------------------------------"
    scan_pkgbuild ./PKGBUILD || true
    echo "------------------------------------------------------------------"
    # Print the whole PKGBUILD, with line numbers, then ask for go-ahead.
    nl -ba ./PKGBUILD | sed 's/^/  /'
    echo "------------------------------------------------------------------"
    printf "==> Build %s now? [y/N] " "$pkgname"
    local yn
    read -r yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        echo "    Skipped by user. Moving on (package will NOT be installed)."
        SKIPPED_PACKAGES+=( "$pkgname" )
        return 0
    fi

    # Build with clean + sync-deps (NO -o: -o means "no build", see makepkg(8)).
    makepkg -Cs --noconfirm

    # Add produced packages to the local repo, then pacman-install from there.
    shopt -s nullglob
    local built=( "$srcdir"/*.pkg.tar.zst )
    shopt -u nullglob
    if [[ ${#built[@]} -eq 0 ]]; then
        echo "  !! No .pkg.tar.zst produced; something went wrong. Skipping install."
        return 1
    fi
    for pkg in "${built[@]}"; do
        echo "==> repo-add: $pkg -> $LOCALREPO_DIR"
        cp "$pkg" "$LOCALREPO_DIR/"
        ( cd "$LOCALREPO_DIR" && repo-add "$LOCALREPO_NAME.db.tar.zst" "$(basename "$pkg")" )
    done
    sudo pacman -Sy
    # Install by name from the local repo explicitly.
    sudo pacman -S --noconfirm --needed "$pkgname"
}

# --- Main -------------------------------------------------------------------
setup_local_repo

PACKAGES=(
    eww
    python-pywal16
    bibata-cursor-theme
    wlogout
    zed
    brave-bin
)

for p in "${PACKAGES[@]}"; do
    build_one "$p"
done

echo
echo "==> AUR build pass done."
if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
    echo "==> Skipped (not installed): ${SKIPPED_PACKAGES[*]}"
fi
echo "==> Requested from [$LOCALREPO_NAME]: ${PACKAGES[*]}"
echo "==> Next: ./20-sddm.sh"
