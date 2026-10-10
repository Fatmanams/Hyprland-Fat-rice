#!/usr/bin/env bash
# scripts/lib/makepkg-conf.sh — /etc/makepkg.conf configuration for
# 00-base.sh step 2. Sourced, never executed directly (the shebang
# exists for shellcheck's SC2148 under lint.yml's error-severity pass).
#
# rice_makepkg_configure FILE applies one idempotent pass:
#   * MAKEFLAGS="-j$(nproc)"          — uncomment the stock #MAKEFLAGS line
#   * BUILDENV ccache enabled         — the ccache package itself is
#                                       installed by the caller (00-base.sh),
#                                       keeping this file pacman-free and
#                                       testable on a plain copy
#   * CFLAGS/CXXFLAGS -march=native   — retarget stock
#                                       "-march=x86-64 -mtune=generic"
#   * RUSTFLAGS -C target-cpu=native  — via the FILE.d/zz-rice.conf drop-in
#
# FILE is a parameter so the whole pass can be exercised on a copy:
#   cp /etc/makepkg.conf ~/mk.conf
#   bash -c '. scripts/lib/makepkg-conf.sh; rice_makepkg_configure ~/mk.conf'
# makepkg treats an alternate --config file the same way (its
# util/config.sh sources "$MAKEPKG_CONF" and then "$MAKEPKG_CONF.d"/*.conf),
# so what this file's probe sees on a copy is what makepkg really gets.
#
# Writes go through sudo only when the target is not user-writable
# ($SUDO below), which is what makes the copy run above sudo-free.
#
# Every edit is re-read afterwards and verified against what makepkg
# will really source: the main file first, then FILE.d/*.conf in glob
# order, exactly makepkg's own order. A failed check prints an ERROR
# naming the file and the manual fix, and exits 1 — same style as the
# ccache check this inherits.

# Print the value VAR resolves to after sourcing FILE and FILE.d/*.conf
# in makepkg's order. bash -c gives a clean shell per call; the four
# flag vars are unset first so the value can only come from the files.
# A VAR that is unset after sourcing prints empty — callers treat that
# as "not configured" and fail closed.
rice_makepkg_value() { # FILE VAR -> stdout
    bash -c '
        unset CFLAGS CXXFLAGS MAKEFLAGS RUSTFLAGS
        [[ -r $1 ]] && source "$1"
        if [[ -d "$1.d" ]]; then
            for c in "$1.d"/*.conf; do
                [[ -e $c ]] && source "$c"
            done
        fi
        printf %s "${!2}"
    ' rice-makepkg-probe "$1" "$2"
}

rice_makepkg_configure() { # FILE
    local file=$1
    local SUDO='' changed=0 val cxx_val jobs dropin rust_line

    if [[ -z $file || ! -f $file ]]; then
        echo "    ERROR: makepkg.conf not found: ${file:-<empty path>}." >&2
        echo "           Manual fix: pass an existing makepkg.conf to rice_makepkg_configure." >&2
        exit 1
    fi
    # Copies under $HOME are user-writable and need no sudo; /etc does.
    # $SUDO is deliberately unquoted: it expands to zero words when empty.
    [[ -w $file ]] || SUDO='sudo'

    # --- MAKEFLAGS: parallel make -----------------------------------------
    if grep -q '^MAKEFLAGS="-j' "$file"; then
        echo "    MAKEFLAGS already set."
    else
        jobs=$(nproc)
        $SUDO sed -i "s|^#MAKEFLAGS=\"-j2\"|MAKEFLAGS=\"-j${jobs}\"|" "$file"
        val=$(rice_makepkg_value "$file" MAKEFLAGS)
        if [[ $val != *-j* ]]; then
            echo "    ERROR: MAKEFLAGS has no -j after configuration in $file." >&2
            echo "           Manual fix: edit $file and set MAKEFLAGS=\"-j\$(nproc)\"." >&2
            exit 1
        fi
        echo "    MAKEFLAGS set to -j${jobs}"
    fi

    # --- BUILDENV: ccache ---------------------------------------------------
    changed=0
    if grep -q '^BUILDENV=.*!ccache' "$file"; then
        $SUDO sed -i 's|^BUILDENV=.*|BUILDENV=(!distcc !color ccache check !sign)|' "$file"
        changed=1
    elif ! grep -q '^BUILDENV=' "$file"; then
        printf '%s\n' 'BUILDENV=(!distcc !color ccache check !sign)' | $SUDO tee -a "$file" >/dev/null
        changed=1
    elif ! grep -q '^BUILDENV=.*\bccache\b' "$file"; then
        $SUDO sed -i 's|^BUILDENV=.*|BUILDENV=(!distcc !color ccache check !sign)|' "$file"
        changed=1
    fi
    # ccache must now appear enabled on the BUILDENV line. Match the
    # disabled token explicitly — \bccache\b alone also matches "!ccache".
    if grep -q '^BUILDENV=.*!ccache' "$file" \
            || ! grep -q '^BUILDENV=.*\bccache\b' "$file"; then
        echo "    ERROR: ccache is not enabled in BUILDENV after configuration in $file." >&2
        echo "           Manual fix: edit $file and set BUILDENV=(!distcc !color ccache check !sign)." >&2
        exit 1
    fi
    if [[ $changed -eq 1 ]]; then
        echo "    ccache enabled in BUILDENV"
    else
        echo "    ccache already enabled in BUILDENV"
    fi

    # --- CFLAGS/CXXFLAGS: -march=native -------------------------------------
    # Everything the rice actually compiles (the AUR set in 10-aur.sh) gets
    # CPU-native flags — prefer compiled-and-native for what's built anyway.
    # pacman binaries stay upstream generic x86-64 (rebuilding those would
    # be a source distro, not a rice). -march=native implies -mtune=native;
    # O2 stays (O3 here is all cost, no measurable win).
    val=$(rice_makepkg_value "$file" CFLAGS)
    cxx_val=$(rice_makepkg_value "$file" CXXFLAGS)
    if [[ $val == *-march=native* && $cxx_val == *-march=native* ]]; then
        echo "    CFLAGS/CXXFLAGS already configured for -march=native"
    else
        # '#' as the s/// delimiter: the pattern carries a '|' alternation
        # ((C|CXX)FLAGS), which a '|' delimiter collides with — GNU sed
        # dies with "unknown option to `s'", aborting the whole install
        # under set -euo pipefail. Stock CXXFLAGS may derive from
        # "$CFLAGS" (current pacman) instead of spelling the flags out
        # (older stock did); the effective check below covers both.
        $SUDO sed -i -E 's#^((C|CXX)FLAGS=")-march=x86-64 -mtune=generic#\1-march=native#' "$file"
        val=$(rice_makepkg_value "$file" CFLAGS)
        if [[ $val != *-march=native* ]]; then
            echo "    ERROR: CFLAGS does not resolve to -march=native after configuration in $file." >&2
            echo "           Manual fix: edit $file and replace -march=x86-64 -mtune=generic with -march=native in CFLAGS." >&2
            exit 1
        fi
        cxx_val=$(rice_makepkg_value "$file" CXXFLAGS)
        if [[ $cxx_val != *-march=native* ]]; then
            echo "    ERROR: CXXFLAGS does not resolve to -march=native after configuration in $file." >&2
            echo "           Manual fix: edit $file — CXXFLAGS must use -march=native itself or derive from \$CFLAGS." >&2
            exit 1
        fi
        echo "    CFLAGS/CXXFLAGS retargeted to -march=native (AUR builds)"
    fi

    # --- RUSTFLAGS: native Rust target, via drop-in ---------------------------
    # Current pacman (>= 6.1) sources FILE.d/*.conf AFTER the main file and
    # ships its own /etc/makepkg.conf.d/rust.conf setting RUSTFLAGS — a
    # RUSTFLAGS appended to the main file is silently overridden and never
    # reaches builds. zz-rice.conf sorts after rust.conf, so it wins; it
    # appends to $RUSTFLAGS, keeping whatever rust.conf set (currently
    # -C force-frame-pointers=yes). ${RUSTFLAGS:+$RUSTFLAGS } yields
    # "existing " when set and nothing when unset — no leading space.
    dropin="${file}.d/zz-rice.conf"
    rust_line='RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C target-cpu=native"'
    if [[ -f $dropin && $(<"$dropin") == "$rust_line" ]]; then
        echo "    RUSTFLAGS already configured ($dropin)"
    else
        $SUDO mkdir -p "${file}.d"
        printf '%s\n' "$rust_line" | $SUDO tee "$dropin" >/dev/null
        $SUDO chmod 0644 "$dropin"
        val=$(rice_makepkg_value "$file" RUSTFLAGS)
        if [[ -z $val || $val != *target-cpu=native* ]]; then
            echo "    ERROR: RUSTFLAGS does not contain -C target-cpu=native after writing $dropin." >&2
            echo "           Manual fix: check $dropin and makepkg's FILE.d/*.conf sourcing order, then re-run." >&2
            exit 1
        fi
        echo "    RUSTFLAGS set to -C target-cpu=native (AUR builds, via $dropin)"
    fi
}
