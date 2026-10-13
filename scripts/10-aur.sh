#!/usr/bin/env bash
# 10-aur.sh — source-built packages using the reviewed AUR workflow:
#   * Pull each AUR repo by git clone (no AUR helper).
#   * Print every tracked file of the AUR repo to stdout for human
#     review (read it all!): PKGBUILD first, then *.install scripts,
#     then patches/helpers — text files up to 400 lines in full with
#     line numbers, bigger or binary files as name + size + sha256.
#     On re-runs, show the commits and the full diff since the commit
#     you last approved (recorded in $BUILDROOT/.reviewed/<pkg>)
#     instead of the whole files; if HEAD is unchanged, say so.
#   * Scan the PKGBUILD and its install scripts for the red-flag
#     patterns listed at the bottom of this header, and warn
#     "unpinned source" for any non-VCS source whose checksum is SKIP.
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
# Red flags that get flagged loudly when found in the PKGBUILD or its
# install scripts:
#   * `curl ... | bash`  or  `... | sh`  anywhere
#   * anything that downloads something into the install step that
#     isn't from the upstream source declared in source=()
#   * post-registration network fetches (curl/wget in install scripts)
#   * eval / `sh -c` / base64 in install scripts
#   * install scripts writing outside the package (absolute paths)
#   * systemctl in install scripts (INFO — enable/start especially)
#   * non-VCS sources whose checksum is SKIP ("unpinned source";
#     VCS sources like git+https are normally SKIP and exempt)
# The review step below will print a warning if any of these appear
# but it's still your job to read everything it prints.

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

# Heuristic scan of a PKGBUILD — and of every *.install script in the
# repo plus the file named by install= (those run as ROOT via pacman) —
# for the red-flag patterns named in the policy. RED FLAG findings set
# the return status to 1; INFO findings do not.
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
    if grep -En 'https?://[^/]*pastebin|[^/]*ipfs|[^/]*ngrok|[^/]*ngrok-free' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: suspicious source URL (pastebin/ipfs/ngrok)"
        flags=1
    fi
    if grep -En 'git clone[^|]*\|\s*(bash|sh)' "$f" >/dev/null 2>&1; then
        echo "  !! RED FLAG: git clone | sh detected"
        flags=1
    fi

    # --- install scripts: *.install glob + the install= file ----------
    local installfile=""
    local maybeline
    maybeline=$(sed -n 's/^[[:space:]]*install[[:space:]]*=[[:space:]]*//p' "$f" | head -n1)
    if [[ -n $maybeline ]]; then
        installfile=${maybeline%%#*}
        installfile=${installfile//\"/}
        installfile=${installfile//\'/}
        installfile=${installfile//[[:space:]]/}
    fi
    local -a install_scripts=()
    local g dup
    shopt -s nullglob
    for g in *.install; do
        install_scripts+=("$g")
    done
    shopt -u nullglob
    if [[ -n $installfile && -f $installfile ]]; then
        dup=0
        for g in "${install_scripts[@]}"; do
            if [[ $g == "$installfile" ]]; then
                dup=1
            fi
        done
        if (( dup == 0 )); then
            install_scripts+=("$installfile")
        fi
    fi
    local s wlines
    for s in "${install_scripts[@]}"; do
        if grep -Eq 'systemctl.*[[:space:]]enable\b|systemctl.*[[:space:]]start\b' "$s" 2>/dev/null; then
            echo "  !! INFO: $s enables/starts systemd services — review whether you want that."
        elif grep -Eq '\bsystemctl\b' "$s" 2>/dev/null; then
            echo "  !! INFO: $s uses systemctl — review what it does."
        fi
        if grep -Eq '\bcurl\b' "$s" 2>/dev/null; then
            echo "  !! RED FLAG: $s: curl in install script — network fetch at install time"
            flags=1
        fi
        if grep -Eq '\bwget\b' "$s" 2>/dev/null; then
            echo "  !! RED FLAG: $s: wget in install script — network fetch at install time"
            flags=1
        fi
        if grep -Eq '\b(bash|sh)[[:space:]]+-c\b' "$s" 2>/dev/null; then
            echo "  !! RED FLAG: $s: sh -c in install script"
            flags=1
        fi
        if grep -Eq '\beval\b' "$s" 2>/dev/null; then
            echo "  !! RED FLAG: $s: eval in install script"
            flags=1
        fi
        if grep -Eq '\bbase64\b' "$s" 2>/dev/null; then
            echo "  !! RED FLAG: $s: base64 in install script — possible payload obfuscation"
            flags=1
        fi
        wlines=$(grep -En '[0-9]?>>?[[:space:]]*/' "$s" 2>/dev/null | grep -Ev '/dev/(null|zero)' || true)
        if [[ -z $wlines ]]; then
            wlines=$(grep -En '[[:space:]](cp|mv|install|ln|rm|touch|mkdir|tee|sed|chmod|chown)[[:space:]][^#]*[[:space:]]*/[^[:space:]#]' "$s" 2>/dev/null || true)
        fi
        if [[ -n $wlines ]]; then
            echo "  !! RED FLAG: $s: writes outside the package (absolute-path write)"
            flags=1
        fi
    done

    # --- unpinned sources: non-VCS source whose checksum is SKIP -----
    local tokpat="'[^']*'|\"[^\"]*\"|[^[:space:]()\"']+"
    local arr sumblock tok u i isvcs
    local -a toks=() srcs=() arrtoks=()
    local -A pinned=()
    for arr in source md5sums sha1sums sha224sums sha256sums sha384sums sha512sums b2sums; do
        sumblock=$(awk -v arr="$arr" '
            $0 ~ "^[[:space:]]*" arr "([_[:alnum:]]*)?[[:space:]]*=" { inblock=1 }
            inblock { print }
            inblock && /\)/ { inblock=0 }
        ' "$f")
        if [[ -z $sumblock ]]; then
            continue
        fi
        mapfile -t toks < <(printf '%s\n' "$sumblock" | sed 's/#.*$//' | grep -oE "$tokpat")
        arrtoks=()
        for tok in "${toks[@]}"; do
            if [[ $tok =~ ^[[:alpha:]_][[:alnum:]_]*= ]]; then
                continue
            fi
            tok=${tok//\"/}
            tok=${tok//\'/}
            if [[ -n $tok ]]; then
                arrtoks+=("$tok")
            fi
        done
        if [[ $arr == "source" ]]; then
            srcs=("${arrtoks[@]}")
        else
            i=0
            for tok in "${arrtoks[@]}"; do
                if [[ ${tok^^} != "SKIP" ]]; then
                    pinned[$i]=1
                fi
                i=$((i+1))
            done
        fi
    done
    i=0
    for tok in "${srcs[@]}"; do
        u=${tok#*::}
        u=${u%%#*}
        isvcs=0
        case "$u" in
            git+*|git://*|bzr+*|bzr://*|hg+*|hg://*|svn+*|svn://*) isvcs=1 ;;
            *.git) isvcs=1 ;;
        esac
        if (( isvcs == 0 )) && (( ${pinned[$i]:-0} == 0 )); then
            echo "  !! RED FLAG: unpinned source: $tok (checksum is SKIP or missing)"
            flags=1
        fi
        i=$((i+1))
    done
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

    # The commit the user last approved is recorded in
    # $BUILDROOT/.reviewed/<pkg> so re-runs show only what changed
    # upstream instead of re-printing every file.
    mkdir -p "$BUILDROOT/.reviewed"
    local reviewed_file="$BUILDROOT/.reviewed/$pkgname"
    local head_rev
    local old_rev=""
    head_rev=$(git rev-parse HEAD)
    if [[ -f $reviewed_file ]]; then
        old_rev=$(<"$reviewed_file")
    fi
    if [[ -n $old_rev ]] && ! git cat-file -e "$old_rev^{commit}" 2>/dev/null; then
        echo "==> NOTE: recorded review commit $old_rev is not in this clone;"
        echo "    showing the full review instead of a diff."
        old_rev=""
    fi

    echo
    echo "------------------------------------------------------------------"
    if [[ -n $old_rev && $old_rev == "$head_rev" ]]; then
        echo "==> $pkgname: HEAD $head_rev is exactly the commit you reviewed"
        echo "    and approved last time — nothing changed since then, so"
        echo "    the file listing is skipped."
    else
        echo "==> AUR repo review  (read everything below before approving)"
        echo "------------------------------------------------------------------"
        echo "==> Tracked files in this AUR repo:"
        git ls-files | sed 's/^/    /'
        echo "------------------------------------------------------------------"
        if [[ -n $old_rev ]]; then
            echo "==> Commits since the review you approved ($old_rev..HEAD):"
            git log --oneline "$old_rev..HEAD"
            echo
            echo "==> Full diff since that review, shown instead of the whole files:"
            git diff "$old_rev" HEAD
        else
            # PKGBUILD first, then *.install scripts, then everything
            # else (patches, helpers, .SRCINFO). Text files up to 400
            # lines are printed in full with line numbers; bigger or
            # binary files show as name + size + sha256.
            local rf
            local lines size sum
            local -a install_files=() other_files=() review_files=( PKGBUILD )
            while IFS= read -r rf; do
                case "$rf" in
                    PKGBUILD) ;;
                    *.install) install_files+=("$rf") ;;
                    *) other_files+=("$rf") ;;
                esac
            done < <(git ls-files)
            review_files+=( "${install_files[@]}" "${other_files[@]}" )
            for rf in "${review_files[@]}"; do
                if [[ -f $rf ]] && grep -Iq . "$rf" 2>/dev/null; then
                    lines=$(wc -l < "$rf")
                    if (( lines <= 400 )); then
                        echo "==> $rf (${lines} lines):"
                        nl -ba "$rf" | sed 's/^/  /'
                    else
                        size=$(wc -c < "$rf")
                        sum=$(sha256sum "$rf" | awk '{print $1}' || true)
                        echo "==> $rf: ${lines} lines (over 400 — not shown):"
                        echo "    ${size} bytes, sha256 ${sum:-N/A}"
                    fi
                else
                    size=$(wc -c < "$rf" 2>/dev/null || printf '?')
                    sum=$(sha256sum "$rf" 2>/dev/null | awk '{print $1}' || true)
                    echo "==> $rf: binary or empty — not shown:"
                    echo "    ${size} bytes, sha256 ${sum:-N/A}"
                fi
                echo
            done
        fi
        echo "------------------------------------------------------------------"
        scan_pkgbuild ./PKGBUILD || true
    fi
    echo "------------------------------------------------------------------"
    printf "==> Build %s now? [y/N] " "$pkgname"
    local yn
    read -r yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        echo "    Skipped by user. Moving on (package will NOT be installed)."
        SKIPPED_PACKAGES+=( "$pkgname" )
        return 0
    fi

    # Approved: remember this commit so the next run diffs against it.
    printf '%s\n' "$head_rev" > "$reviewed_file"

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
