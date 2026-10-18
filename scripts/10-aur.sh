#!/usr/bin/env bash
# 10-aur.sh — source-built packages using the reviewed AUR workflow:
#   * Pull each AUR repo by git clone (no AUR helper).
#   * Print the PKGBUILD and every other tracked file of the AUR repo
#     (hooks, patches, scripts) to stdout for human review (read it!).
#     On later runs, the clone's log and diff since the last approved
#     review replace that full listing (the reviewed commit is stored
#     in $BUILDROOT/.reviewed/<pkg> after each confirmed build).
#   * Wait for explicit confirmation before building.
#   * Build with plain `makepkg -Cs` (clean + syncdeps + build, NO -i).
#
#     NOTE: do NOT use `makepkg -Cso`. The `-o` / `--nobuild` flag means
#     "Download and extract files, run prepare(), but do NOT build them"
#     per makepkg(8). With `-o`, no .pkg.tar.zst is produced, and under
#     `set -euo pipefail` build_one() dies after extraction. `-s` alone
#     is sufficient for sync-deps + build.
#   * Add the resulting .pkg.tar.zst to the local repo with repo-add —
#     copied in as root (`sudo install -m0644`) and registered with
#     `sudo repo-add`. The repo directory is root:root 0755 with 0644
#     files: root pacman installs from it, so nothing user-writable may
#     sit in its path (the directory stays world-readable — pacman
#     downloads from it as the alpm user).
#   * Install via `sudo pacman -S <pkgname>` from that local repo
#     (NOT `pacman -U` — `-S` resolves from the [localrepo] section
#     registered in /etc/pacman.conf, which keeps dependency tracking
#     honest; `-U` would short-circuit that).
#   * Before makepkg: every validpgpkeys entry missing from the keyring
#     is printed with the exact `gpg --recv-keys <fpr>` command and a
#     y/N prompt — keys are NEVER imported silently. Declining (or a
#     failed import) records the package as FAILED and moves on; with
#     the key missing, makepkg would abort on it anyway.
#   * Containment: a makepkg failure or a build that produces no
#     .pkg.tar.zst records the package in FAILED_PACKAGES and the
#     queue continues. The end-of-run summary lists SKIPPED and FAILED
#     separately, and the script exits non-zero when anything FAILED
#     (so 60-update.sh still treats phase 10 as failed).
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
# LOCALREPO_DIR below and adjust if yours is elsewhere. An existing
# user-owned repo directory (the layout this script created before it
# was hardened) is migrated to root:root once, with a message.
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
# the full contents of every tracked file in the repo (on later runs:
# the log + diff since the last approved review) — but it's still
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
FAILED_PACKAGES=()

# Ensure local repo is set up + registered in pacman.conf once.
#
# Hardening: the repo is root:root 0755 with 0644 package/db files.
# Root pacman consumes this repo, so a user-writable copy would let
# anything running as $USER plant a newer package under an
# already-reviewed name and have the next `pacman -Syu` install it as
# root. The directory stays world-readable: pacman downloads from it
# as the dedicated alpm user. An existing user-owned directory (the
# pre-hardening layout) is migrated once, with a message; runs over
# an already-root-owned repo are no-ops.
setup_local_repo() {
    if [[ ! -d "$LOCALREPO_DIR" ]]; then
        echo "==> Creating local repo directory: $LOCALREPO_DIR"
        sudo mkdir -p "$LOCALREPO_DIR"
    fi
    local owner perms
    owner="$(stat -c '%U' "$LOCALREPO_DIR")"
    perms="$(stat -c '%a' "$LOCALREPO_DIR")"
    if [[ "$owner" != "root" ]]; then
        echo "==> $LOCALREPO_DIR is owned by '$owner', not root — migrating"
        echo "    to root:root (root pacman installs from this repo; a"
        echo "    user-writable one would let anything running as $USER"
        echo "    plant packages pacman then installs as root)"
        sudo chown -R root:root "$LOCALREPO_DIR"
        sudo find "$LOCALREPO_DIR" -mindepth 1 -type f -exec chmod 0644 {} +
    fi
    if [[ "$perms" != "755" ]]; then
        echo "==> $LOCALREPO_DIR mode is $perms, fixing to 755 (pacman"
        echo "    downloads from it as the alpm user)"
        sudo chmod 0755 "$LOCALREPO_DIR"
    fi
    if [[ ! -f "$LOCALREPO_DIR/$LOCALREPO_NAME.db.tar.zst" ]]; then
        sudo repo-add "$LOCALREPO_DIR/$LOCALREPO_NAME.db.tar.zst"
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

# Every validpgpkeys entry that is missing from the user's keyring is
# printed with the exact import command and gets a y/N prompt BEFORE
# makepkg runs — a key is never imported silently. Declining (or a
# failed import) fails this check so build_one records the package as
# FAILED: with the key missing, makepkg would abort on source
# signature verification anyway ("unknown public key").
# Runs in the package's clone directory (reads .SRCINFO via
# `makepkg --printsrcinfo`, same parser makepkg itself uses).
ensure_pgp_keys() {
    local pkgname="$1" fpr yn
    local -a missing=()
    while IFS= read -r fpr; do
        [[ -n "$fpr" ]] || continue
        gpg --list-keys "$fpr" >/dev/null 2>&1 || missing+=( "$fpr" )
    done < <(makepkg --printsrcinfo 2>/dev/null \
                | awk '$1 == "validpgpkeys" { print $3 }')
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    echo "==> $pkgname pins its sources with validpgpkeys; key(s) missing"
    echo "    from your keyring (makepkg would abort on them):"
    for fpr in "${missing[@]}"; do
        echo "        $fpr"
    done
    for fpr in "${missing[@]}"; do
        echo "==> Exact import command: gpg --recv-keys $fpr"
        printf "==> Import %s into your keyring now? [y/N] " "$fpr"
        read -r yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            if gpg --recv-keys "$fpr"; then
                echo "    Imported $fpr."
            else
                echo "  !! Import of $fpr failed — recording $pkgname as FAILED."
                return 1
            fi
        else
            echo "    Declined. Not building $pkgname: its sources are"
            echo "    signature-pinned, and without the key makepkg cannot"
            echo "    verify them. Recording $pkgname as FAILED."
            return 1
        fi
    done
    return 0
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

    # Last reviewed commit for this package: $BUILDROOT/.reviewed/<pkg>
    # holds the HEAD the user approved at the last confirmed build.
    local reviewed="$BUILDROOT/.reviewed/$pkgname"
    local old=""
    if [[ -s "$reviewed" ]]; then
        old="$(<"$reviewed")"
        if ! git merge-base --is-ancestor "$old" HEAD 2>/dev/null; then
            echo "==> Stored review commit ${old:0:12} is no longer in this repo's"
            echo "    history (force-pushed AUR repo?). Falling back to full file review."
            old=""
        fi
    fi

    echo
    echo "------------------------------------------------------------------"
    echo "==> File review  (scan output first, then every tracked file on a"
    echo "    first run — or the diff since your last review afterwards)"
    echo "------------------------------------------------------------------"
    scan_pkgbuild ./PKGBUILD || true
    echo "------------------------------------------------------------------"
    if [[ -n "$old" && "$old" == "$(git rev-parse HEAD)" ]]; then
        echo "==> No changes since last review $(git rev-parse --short "$old")."
    elif [[ -n "$old" ]]; then
        echo "==> Changes since last review $(git rev-parse --short "$old"):"
        echo
        git log --oneline "$old..HEAD"
        echo
        git diff "$old..HEAD"
        echo
    else
        # First run (or fallen-back) review: print every tracked file
        # (PKGBUILD first, hooks/patches/scripts next, big or binary
        # files as name+size+sha256), then ask.
        print_review_files
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

    # The user just approved this tree; remember the commit so the next
    # run reviews the diff since here instead of re-printing everything.
    mkdir -p "$BUILDROOT/.reviewed"
    git rev-parse HEAD > "$reviewed"

    # validpgpkeys gate: explicit y/N import prompt per missing key.
    # Declined or failed import → FAILED (recorded), queue continues.
    if ! ensure_pgp_keys "$pkgname"; then
        FAILED_PACKAGES+=( "$pkgname" )
        return 0
    fi

    # Build with clean + sync-deps (NO -o: -o means "no build", see
    # makepkg(8)). A makepkg failure is contained: record FAILED and
    # let the rest of the queue run; the summary + exit code report it.
    if ! makepkg -Cs --noconfirm; then
        echo "  !! makepkg failed for $pkgname — recording FAILED, continuing."
        FAILED_PACKAGES+=( "$pkgname" )
        return 0
    fi

    # Add produced packages to the local repo, then pacman-install from there.
    shopt -s nullglob
    local built=( "$srcdir"/*.pkg.tar.zst )
    shopt -u nullglob
    if [[ ${#built[@]} -eq 0 ]]; then
        echo "  !! No .pkg.tar.zst produced — recording $pkgname as FAILED,"
        echo "     continuing."
        FAILED_PACKAGES+=( "$pkgname" )
        return 0
    fi
    for pkg in "${built[@]}"; do
        echo "==> repo-add: $(basename "$pkg") -> $LOCALREPO_DIR"
        # Copy as root with explicit 0644 — the local repo must hold only
        # root-owned, non-user-writable files — then register as root too.
        sudo install -m0644 "$pkg" "$LOCALREPO_DIR/"
        sudo repo-add "$LOCALREPO_DIR/$LOCALREPO_NAME.db.tar.zst" \
            "$LOCALREPO_DIR/$(basename "$pkg")"
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
    echo "==> Skipped (user declined the build): ${SKIPPED_PACKAGES[*]}"
fi
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo "==> FAILED: ${FAILED_PACKAGES[*]}"
fi
echo "==> Requested from [$LOCALREPO_NAME]: ${PACKAGES[*]}"
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo "  !! ${#FAILED_PACKAGES[@]} AUR package(s) FAILED — fix the cause"
    echo "     above and re-run; already-approved builds go straight to the"
    echo "     since-last-review diff next time. Exiting non-zero so"
    echo "     60-update.sh treats phase 10 as failed."
    exit 1
fi
echo "==> Next: ./20-sddm.sh"
