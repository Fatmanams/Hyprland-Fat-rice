#!/usr/bin/env bash
# 10-aur.sh — source-built packages using the reviewed AUR workflow:
#   * Pull each AUR repo by git clone (no AUR helper).
#   * Print the PKGBUILD and every other tracked file of the AUR repo
#     (hooks, patches, scripts) to stdout for human review (read it!).
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
#     helium-browser-bin     https://aur.archlinux.org/helium-browser-bin.git
#     mpvpaper               https://aur.archlinux.org/mpvpaper.git
#     vscode-langservers-extracted
#                            https://aur.archlinux.org/vscode-langservers-extracted.git
#     chkrootkit             https://aur.archlinux.org/chkrootkit.git
#     ox-bin                 https://aur.archlinux.org/ox-bin.git
#     neomacs-bin            https://aur.archlinux.org/neomacs-bin.git
#
#     (Zed moved to OFFICIAL repos in 2026 — zed 1.21.0-1 is now in
#     extra/x86_64. We've moved it out of this list into 00-base.sh's
#     official-repo block; the review pipeline here no longer fetches it.)
#
#     (helium-browser-bin: precompiled Helium (imputnet chromium fork),
#     repackaged from the upstream release tarball. Reviewed PKGBUILD
#     0.16.4.1-1: source is the pinned GitHub release tarball WITH its
#     .asc verified via validpgpkeys (Helium signing key), plus two
#     local sha256-pinned patches and the ungoogled-chromium license.
#     package() copies the unpacked tree into /opt and symlinks a wrapper
#     to /usr/bin/helium-browser; desktop file installed as helium.desktop.
#     No build(), no install hooks, no curl|bash, no suspicious URLs.)
#
#     (mpvpaper: video wallpaper daemon for wlroots compositors. Reviewed
#     PKGBUILD 1.9-1 against the live AUR copy: source is a pinned GitHub
#     release tarball with a b2sum, built with meson/ninja, depends on
#     libmpv.so + libwayland (mpv is pulled in automatically by makepkg -s),
#     optdepends socat for socket control, no install hooks, no curl|bash,
#     no suspicious URLs. No red flags.)
#
#     (vscode-langservers-extracted: the HTML/CSS/JSON/ESLint language
#     servers extracted from VSCode, used by Zed and by Emacs' eglot —
#     the rest of the LSP stack is official-repo and installed by
#     00-base.sh. Reviewed PKGBUILD 4.10.0-1 against the live AUR copy:
#     single source, the upstream npm registry tarball, pinned with a
#     sha256sum; package() is a local `npm i -g` into $pkgdir with the
#     cache confined to $srcdir, plus a chown and a license install. No
#     build(), no install hooks, no curl|bash. Note it IS an npm package,
#     so the tarball vendors its own node_modules — that's inherent to
#     the upstream distribution, not something the PKGBUILD adds.)
#
#     (ox-bin + neomacs-bin: existence and metadata verified against the
#     AUR RPC API on 2026-09-25. ox-bin 0.7.7-1 — maintained by curlpipe,
#     the upstream Ox author; provides/conflicts `ox`. neomacs-bin
#     0.0.19-1 — provides `neomacs`, sources eval-exec/neomacs on GitHub.
#     STILL review each PKGBUILD before approving: both repack prebuilt
#     upstream release binaries, so the source=() URLs and checksums are
#     the entire attack surface.)
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
# Red flags that get flagged loudly when found in the PKGBUILD or in
# any *.install hook it ships (post_install/post_upgrade live in those
# hook files, not in the PKGBUILD, so a PKGBUILD-only scan never sees
# them):
#   * `curl ... | bash`  or  `... | sh`  anywhere
#   * anything that downloads something into the install step that
#     isn't from the upstream source declared in source=()
#   * post-registration network fetches
#   * hooks that fetch (curl/wget), spawn `sh -c`, eval, decode
#     base64, run systemctl, or write outside the package
#   * a non-VCS source whose checksum is SKIP (unpinned source)
# The review step below prints a warning for each of these and lists
# the full contents of every tracked file in the repo — but it's still
# your job to read them.

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
    fi
}

# Print the values of a bash array assignment (source=(), sha256sums=(),
# ...) from a PKGBUILD, one per line, in order. Multiline arrays work;
# entries containing whitespace do not (none do in practice upstream).
pkgbuild_array_values() {
    local name="$1" file="$2"
    awk -v n="^${name}[[:space:]]*=" '
        $0 ~ n {
            inp = 1
            sub(/^[^=]*=[[:space:]]*/, "")
        }
        inp {
            line = $0
            if (sub(/\)[^)]*$/, "", line))
                inp = 0
            m = split(line, toks, /[[:space:]]+/)
            for (i = 1; i <= m; i++)
                if (toks[i] != "" && toks[i] != "(")
                    print toks[i]
        }
    ' "$file" | tr -d "()'\""
}

# Heuristic scan for the red-flag patterns named in the policy. Scans
# the PKGBUILD plus every install hook it ships (*.install files and
# whatever install= names) — post_install/post_upgrade live in those
# hook files, not in the PKGBUILD, so a PKGBUILD-only scan never sees
# them. A hit in a hook counts exactly like one in the PKGBUILD.
scan_pkgbuild() {
    local pkgbuild="$1"
    local flags=0
    local f hits i idx s alg
    local vcs_re='^(git|hg|svn|bzr|cvs)(\+[a-z]+)?://'
    local -a scan_files=() hook_files=() candidates=() labels=() patterns=() srcs=() sums=()
    local -A seen=() warned_skip=()

    # Everything that can execute at install time: the PKGBUILD, every
    # *.install hook in the repo, and any file install= points at (hook
    # files do not have to end in .install). install=$var entries are
    # left to the *.install glob — the file on disk ends in .install.
    candidates=( "$pkgbuild" )
    shopt -s nullglob
    candidates+=( *.install )
    shopt -u nullglob
    while IFS= read -r f; do
        [[ -n $f ]] && candidates+=( "$f" )
    done < <(grep -E '^[[:space:]]*install[[:space:]]*=' "$pkgbuild" 2>/dev/null \
                | sed -E "s/^[[:space:]]*install[[:space:]]*=//; s/[()'\"]//g" \
                | tr -s '[:space:]' '\n' | grep -Ev '^\$|^$' || true)
    for f in "${candidates[@]}"; do
        [[ -f $f ]] || continue
        [[ -n ${seen[$f]:-} ]] && continue
        seen[$f]=1
        scan_files+=( "$f" )
    done
    [[ ${#scan_files[@]} -gt 0 ]] || return 0
    hook_files=( "${scan_files[@]:1}" )
    if [[ ${#hook_files[@]} -gt 0 ]]; then
        echo "  ==> install hooks included in this scan: ${hook_files[*]}"
    fi

    # Patterns checked across the PKGBUILD and every hook file.
    labels=(
        "curl|bash pattern detected"
        "wget|bash pattern detected"
        "suspicious source URL (pastebin/ipfs/ngrok)"
        "git clone | sh detected"
    )
    patterns=(
        'curl[^|]*\|\s*(bash|sh|zsh)'
        'wget[^|]*\|\s*(bash|sh|zsh)'
        'https?://[^/]*pastebin|[^/]*ipfs|[^/]*ngrok|[^/]*ngrok-free'
        'git clone[^|]*\|\s*(bash|sh)'
    )
    for i in "${!labels[@]}"; do
        hits="$(grep -EHn "${patterns[$i]}" "${scan_files[@]}" 2>/dev/null || true)"
        if [[ -n $hits ]]; then
            echo "  !! RED FLAG: ${labels[$i]}"
            sed 's/^/       /' <<< "$hits"
            flags=1
        fi
    done

    # Patterns checked in the install hooks only: nothing a hook runs
    # should fetch over the network, spawn a fresh shell, eval, decode
    # base64, touch services, or write outside the package.
    if [[ ${#hook_files[@]} -gt 0 ]]; then
        labels=(
            "network fetch (curl/wget) in install hook"
            "sh -c in install hook"
            "eval in install hook"
            "base64 in install hook"
            "systemctl in install hook — review whether you want that"
            "write outside the package in install hook"
        )
        patterns=(
            '(^|[^a-zA-Z])(curl|wget)([^a-zA-Z]|$)'
            '(^|[^a-zA-Z])(ba|z|da)?sh[[:space:]]+-c([^a-zA-Z0-9]|$)'
            '(^|[^a-zA-Z])eval([[:space:]]|\()'
            '(^|[^a-zA-Z])base64([^a-zA-Z0-9]|$)'
            '(^|[^a-zA-Z])systemctl([^a-zA-Z0-9]|$)'
            '(^|[^a-zA-Z0-9{}$#!])((/etc|/usr|/opt|/var|/boot|/lib64?|/root|/home|/srv)([^a-zA-Z0-9]|$))'
        )
        for i in "${!labels[@]}"; do
            hits="$(grep -EHn "${patterns[$i]}" "${hook_files[@]}" 2>/dev/null || true)"
            if [[ -n $hits ]]; then
                echo "  !! RED FLAG: ${labels[$i]}"
                sed 's/^/       /' <<< "$hits"
                flags=1
            fi
        done
    fi

    # Unpinned sources: warn for every non-VCS source whose checksum is
    # SKIP. VCS sources (git+https://, hg+ssh://, name::git+https://,
    # ...) legitimately skip checksums, so they are exempt.
    mapfile -t srcs < <(pkgbuild_array_values source "$pkgbuild")
    for alg in sha512sums sha384sums sha256sums sha224sums sha1sums md5sums b2sums cksums; do
        mapfile -t sums < <(pkgbuild_array_values "$alg" "$pkgbuild")
        [[ ${#sums[@]} -eq 0 ]] && continue
        if [[ ${#sums[@]} -eq ${#srcs[@]} ]]; then
            for idx in "${!sums[@]}"; do
                [[ ${sums[$idx]} == SKIP ]] || continue
                s="${srcs[$idx]#*::}"
                [[ $s =~ $vcs_re ]] && continue
                [[ -z ${warned_skip[$idx]:-} ]] || continue
                warned_skip[$idx]=1
                echo "  !! RED FLAG: unpinned source — checksum is SKIP for: ${srcs[$idx]}"
                flags=1
            done
        elif printf '%s\n' "${sums[@]}" | grep -qx 'SKIP'; then
            for s in "${srcs[@]}"; do
                [[ "${s#*::}" =~ $vcs_re ]] && continue
                echo "  !! RED FLAG: unpinned source — a checksum is SKIP but source/checksum arrays could not be paired; review source=() by hand"
                flags=1
                break
            done
        fi
    done

    return $flags
}

# Print every tracked file of the AUR clone for review: the git
# ls-files manifest first, then the contents of every tracked text
# file up to 400 lines, with line numbers — PKGBUILD first, then
# *.install hooks, patches, scripts, and everything else. Files over
# 400 lines or binary get name, size and sha256 instead of contents.
print_review_files() {
    local f n
    local -a pkgs=() hooks=() patches=() scripts=() texts=() big=()

    while IFS= read -r f; do
        [[ -z $f ]] && continue
        n=0
        if grep -Iq . "$f" 2>/dev/null; then
            n="$(wc -l < "$f")"
        fi
        if [[ $n -eq 0 || $n -gt 400 ]]; then
            big+=( "$f" )
        elif [[ $f == PKGBUILD ]]; then
            pkgs+=( "$f" )
        elif [[ $f == *.install ]]; then
            hooks+=( "$f" )
        elif [[ $f == *.patch || $f == *.diff ]]; then
            patches+=( "$f" )
        elif [[ $f == *.sh ]]; then
            scripts+=( "$f" )
        else
            texts+=( "$f" )
        fi
    done < <(git ls-files)

    echo "==> Tracked files in this repo (git ls-files):"
    git ls-files | sed 's/^/    /'
    echo
    for f in "${pkgs[@]}" "${hooks[@]}" "${patches[@]}" "${scripts[@]}" "${texts[@]}"; do
        echo "==> $f ($(wc -l < "$f") lines):"
        nl -ba "./$f" | sed 's/^/  /'
        echo
    done
    for f in "${big[@]}"; do
        echo "==> $f : $(stat -c '%s' "./$f") bytes, sha256 $(sha256sum "./$f" | awk '{print $1}') — binary or over 400 lines, contents not printed"
        echo
    done
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
    echo "==> File review  (scan output first, then every tracked file —"
    echo "    read them all before approving)"
    echo "------------------------------------------------------------------"
    scan_pkgbuild ./PKGBUILD || true
    echo "------------------------------------------------------------------"
    # Print every tracked file (PKGBUILD first, hooks/patches/scripts
    # next, big or binary files as name+size+sha256), then ask.
    print_review_files
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
    # Install by name from the local repo explicitly.
    sudo pacman -S --noconfirm --needed "$pkgname"
}

# --- Main -------------------------------------------------------------------
setup_local_repo

# Full sync+upgrade once per run (not per package — a per-package -Sy/-Syu
# is Arch's partial-upgrade anti-pattern, and upgrading inside the loop
# would repeat a full system upgrade for every AUR build).
echo "==> Syncing + upgrading system once before AUR builds"
sudo pacman -Syu --noconfirm

PACKAGES=(
    eww
    python-pywal16
    bibata-cursor-theme
    wlogout
    helium-browser-bin
    mpvpaper
    vscode-langservers-extracted
    chkrootkit
    ox-bin
    neomacs-bin
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
