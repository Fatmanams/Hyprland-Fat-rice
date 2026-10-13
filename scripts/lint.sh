#!/usr/bin/env bash
# lint.sh — the repo's single lint manifest.
#
# Every lint file list lives HERE and nowhere else. CI
# (.github/workflows/lint.yml), the 60-update.sh lint gate, and the
# .zed/tasks.json tasks all call this script; no caller re-declares a
# list. Extend coverage by editing the sets below — globs first, an
# explicit path only where no glob can express it.
#
# Checks (one per CI step, so a red build names the broken class):
#   - bash        bash -n over every shell file, the four preset
#                 colors.sh included (pywal16's format leaves them
#                 shebang-less)
#   - shellcheck  runs shellcheck --severity=error over the same set
#                 minus the shebang-less presets (SC2148 is error
#                 severity; no comment line may start with the bare
#                 word "shellcheck" or it parses as a directive)
#   - json        jq parse: the plain set, the deliberate //-header set
#                 (stripped first), and wlogout's concatenated objects
#   - emacs       byte-compile init.el + the preset/template colors.el
#   - lua         luajit parse of nvim's init.lua (nvim's dialect)
#   - cpp         g++ -fsyntax-only of the rofi keybind menu
#   - themes      scripts/lint-themes.sh (presets + wal templates)
#   - binds       awk duplicate-bind scan over the two hypr confs:
#                 $vars expanded (longest name first), modifiers split
#                 and sorted, keys lowercased, bindm vs bindm only
#   - all         everything above, in that order
#
# Modes:
#   strict (default)   a required tool missing from PATH is a FAIL —
#                      CI must never lose a check silently
#   --skip-missing     a missing tool prints a "SKIPPED (tool absent)"
#                      line for its check and lands in the summary's
#                      skip list; the check is not run (the update gate
#                      and local runs: run what the box has, loudly
#                      skip the rest — a pass is never silent about
#                      what it skipped)
#
# A manifest path that doesn't exist is a FAIL in both modes: that is
# the reverse-drift guard — a rename must update this file in the same
# commit or every check goes red. Read-only; installs nothing; safe to
# run on the live system.

set -u
cd "$(dirname "$0")/.." || exit 1
shopt -s globstar

FAILS=0
SKIP_MISSING=0
SKIPPED=()

# ---- the manifest (globs first) --------------------------------------------------

BASH_SET=(scripts/*.sh scripts/lib/*.sh config/**/*.sh config/vlc/vlc-open)

JSON_PLAIN=(config/nvim/lazy-lock.json .zed/tasks.json \
            config/hypr/themes/*/colors-zed.json config/wal/templates/*.json)

JSON_STRIP=(config/swaync/config.json config/zed/settings.json \
            config/zed/keymap.json postgres-language-server.jsonc \
            config/waybar/config)

JSON_CONCAT=(config/wlogout/layout)

ELISP=(config/emacs/init.el config/hypr/themes/*/colors.el \
       config/wal/templates/*.el)

# The two files Hyprland's bind section actually reads: the main config
# plus the keybinds-extra.conf it sources.
BINDS_FILES=(config/hypr/hyprland.conf config/hypr/keybinds-extra.conf)

# ---- helpers ---------------------------------------------------------------------

usage() {
    cat <<'EOF'
usage: scripts/lint.sh [--skip-missing] <check>...
  checks: bash shellcheck json emacs lua cpp themes binds all
  --skip-missing: SKIP (loudly) instead of FAIL when a tool is absent
EOF
}

need_tool() {  # need_tool <check> <tool>
    local check=$1 tool=$2
    if command -v "$tool" >/dev/null 2>&1; then
        return 0
    fi
    if [[ $SKIP_MISSING -eq 1 ]]; then
        SKIPPED+=("$check")
        echo "==> SKIPPED (tool absent): $check — $tool not in PATH; CI enforces it"
        return 1
    fi
    echo "  FAIL $check: required tool '$tool' not found in PATH" >&2
    FAILS=$((FAILS + 1))
    return 1
}

report() {  # report <check> <rc>
    if [[ $2 -eq 0 ]]; then
        echo "==> PASS: $1"
    else
        echo "==> FAIL: $1" >&2
        FAILS=$((FAILS + 1))
    fi
}

# ---- checks ----------------------------------------------------------------------

check_bash() {
    local f rc=0
    for f in "${BASH_SET[@]}"; do
        if [[ ! -e $f ]]; then
            echo "  FAIL manifest path does not exist: $f" >&2
            rc=1
            continue
        fi
        echo "  bash -n $f"
        bash -n "$f" || { echo "  FAIL bash -n $f" >&2; rc=1; }
    done
    report bash "$rc"
}

check_shellcheck() {
    need_tool shellcheck shellcheck || return 0
    local f rc=0
    for f in "${BASH_SET[@]}"; do
        if [[ ! -e $f ]]; then
            echo "  FAIL manifest path does not exist: $f" >&2
            rc=1
            continue
        fi
        # The preset colors.sh are pywal output format, shebang-less by
        # design, and SC2148 ("add a shebang") is error severity: they are
        # excluded here — the bash check syntax-checks them.
        [[ $f == config/hypr/themes/*/colors.sh ]] && continue
        echo "  shellcheck $f"
        shellcheck --severity=error "$f" \
            || { echo "  FAIL shellcheck $f" >&2; rc=1; }
    done
    report shellcheck "$rc"
}

check_json() {
    need_tool json jq || return 0
    local f rc=0
    for f in "${JSON_PLAIN[@]}"; do
        [[ -e $f ]] \
            || { echo "  FAIL manifest path does not exist: $f" >&2; rc=1; continue; }
        echo "  jq $f"
        jq empty "$f" || { echo "  FAIL jq $f" >&2; rc=1; }
    done
    # Deliberate //-header comments (they keep the write tool's JSON
    # auto-detect honest — AGENTS.md) are stripped before parsing; the
    # match tolerates leading whitespace because waybar's header block
    # is indented.
    for f in "${JSON_STRIP[@]}"; do
        [[ -e $f ]] \
            || { echo "  FAIL manifest path does not exist: $f" >&2; rc=1; continue; }
        echo "  jq $f (// headers stripped)"
        sed '/^[[:space:]]*\/\//d' "$f" | jq empty \
            || { echo "  FAIL jq $f" >&2; rc=1; }
    done
    for f in "${JSON_CONCAT[@]}"; do
        [[ -e $f ]] \
            || { echo "  FAIL manifest path does not exist: $f" >&2; rc=1; continue; }
        echo "  jq -s $f (concatenated objects)"
        sed '/^[[:space:]]*\/\//d' "$f" | jq -s empty \
            || { echo "  FAIL jq -s $f" >&2; rc=1; }
    done
    report json "$rc"
}

check_emacs() {
    need_tool emacs emacs || return 0
    local f rc=0
    # -Q: no site/user init, so nothing on the box influences the
    # result. Byte-compiling surfaces unbalanced parens and malformed
    # forms — the class of breakage worth catching here (the config is
    # loaded, not linted, at runtime). The .elc files it writes are
    # build artifacts of the check and are not committed.
    for f in "${ELISP[@]}"; do
        [[ -e $f ]] \
            || { echo "  FAIL manifest path does not exist: $f" >&2; rc=1; continue; }
        echo "  byte-compile $f"
        emacs -Q --batch -f batch-byte-compile "$f" \
            || { echo "  FAIL byte-compile $f" >&2; rc=1; }
    done
    find config -name '*.elc' -delete
    report emacs "$rc"
}

check_lua() {
    need_tool lua luajit || return 0
    local rc=0
    # luajit -bl parses init.lua in nvim's exact dialect.
    echo "  luajit -bl config/nvim/init.lua"
    luajit -bl config/nvim/init.lua /dev/null \
        || { echo "  FAIL luajit config/nvim/init.lua" >&2; rc=1; }
    report lua "$rc"
}

check_cpp() {
    need_tool cpp g++ || return 0
    local rc=0
    # g++ -fsyntax-only parses/semantics without producing a binary
    # (30-dotfiles.sh does the real -O2 build); -Werror locks in the
    # currently warning-free compile.
    echo "  g++ -fsyntax-only config/rofi/keybind-menu.cpp"
    g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only \
        config/rofi/keybind-menu.cpp \
        || { echo "  FAIL g++ config/rofi/keybind-menu.cpp" >&2; rc=1; }
    report cpp "$rc"
}

check_themes() {
    local rc=0
    # lint-themes.sh owns the theme contract: preset inventory, hex
    # sync against each preset's own colors.sh, the switch-theme.sh
    # copy list, and the wal-template placeholder names.
    if [[ ! -e scripts/lint-themes.sh ]]; then
        echo "  FAIL manifest path does not exist: scripts/lint-themes.sh" >&2
        rc=1
    else
        bash scripts/lint-themes.sh || rc=1
    fi
    report themes "$rc"
}

check_binds() {
    local f rc=0
    for f in "${BINDS_FILES[@]}"; do
        [[ -e $f ]] \
            || { echo "  FAIL manifest path does not exist: $f" >&2; rc=1; }
    done
    if [[ $rc -eq 0 ]]; then
        echo "  hypr bind duplicate scan: ${BINDS_FILES[*]}"
        # Hyprland key names are case-insensitive and it does not
        # de-duplicate: two binds that normalize to the same
        # (modifiers, key) both fire on one keypress. The scan below
        # mirrors the parser just enough to catch that: variables are
        # expanded ($name = value, value = first token, comments
        # stripped, longest names first so $key_lock is not eaten by a
        # hypothetical $key_l), flag suffixes on the bind keyword
        # (binde/bindl/bindel/...) are ignored, modifiers are split
        # and sorted, keys are lowercased, and mouse binds (bindm)
        # are compared only against other mouse binds. Pure awk, no
        # new runtime dependency.
        awk '
            # Pass 1: collect $name = value assignments and remember
            # every bind line (lowercased, comments stripped).
            {
                s = tolower($0)
                sub(/#.*/, "", s)
                if (match(s, /^[ \t]*\$[a-z0-9_]+[ \t]*=/)) {
                    head = substr(s, RSTART, RLENGTH)
                    sub(/^[ \t]*\$/, "", head)
                    sub(/[ \t]*=$/, "", head)
                    rest = substr(s, RSTART + RLENGTH)
                    sub(/^[ \t]+/, "", rest)
                    split(rest, tok, /[ \t]+/)
                    if (head != "" && tok[1] != "") vars[head] = tok[1]
                } else if (s ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
                    nb++
                    bloc[nb] = FILENAME ":" FNR
                    bline[nb] = s
                }
            }

            # Replace whole-word occurrences of $name in sv. The scan
            # offset jumps past inserted values, so a value can never
            # re-trigger itself.
            function expand_var(sv, n,    name, val, off, rest, pos, absp, endc) {
                name = "$" n
                val = vars[n]
                off = 1
                while (off <= length(sv)) {
                    rest = substr(sv, off)
                    pos = index(rest, name)
                    if (pos == 0) break
                    absp = off + pos - 1
                    endc = substr(sv, absp + length(name), 1)
                    if (endc == "" || endc !~ /[a-z0-9_]/) {
                        sv = substr(sv, 1, absp - 1) val \
                             substr(sv, absp + length(name))
                        off = absp + length(val)
                    } else {
                        off = absp + 1
                    }
                }
                return sv
            }

            END {
                for (v in vars) names[++nn] = v
                for (i = 2; i <= nn; i++) {
                    cur = names[i]
                    for (j = i - 1; j >= 1 && length(names[j]) < length(cur); j--)
                        names[j + 1] = names[j]
                    names[j + 1] = cur
                }
                rc = 0
                if (nb == 0) {
                    print "  FAIL binds: no bind lines found in the manifest files" | "cat 1>&2"
                    rc = 1
                }
                for (b = 1; b <= nb; b++) {
                    s = bline[b]
                    for (iter = 0; iter < 8; iter++) {
                        changed = 0
                        for (i = 1; i <= nn; i++) {
                            t = expand_var(s, names[i])
                            if (t != s) { s = t; changed = 1 }
                        }
                        if (!changed) break
                    }
                    split(s, fld, ",")
                    # fld[1] is "bind = <mods>" — the first comma comes
                    # after the mods, so keyword and mods split on the
                    # "=", and the key is fld[2].
                    eqp = index(fld[1], "=")
                    if (eqp == 0) continue
                    kw = substr(fld[1], 1, eqp - 1)
                    mods = substr(fld[1], eqp + 1)
                    gsub(/^[ \t]+|[ \t]+$/, "", kw)
                    if (kw !~ /^bind[a-z]*$/) continue
                    kind = (substr(kw, 5) ~ /m/) ? "bindm" : "bind"
                    gsub(/^[ \t]+|[ \t]+$/, "", mods)
                    nm = split(mods, mtok, /[ \t]+/)
                    for (i = 2; i <= nm; i++) {
                        cur = mtok[i]
                        for (j = i - 1; j >= 1 && mtok[j] > cur; j--)
                            mtok[j + 1] = mtok[j]
                        mtok[j + 1] = cur
                    }
                    cmods = ""
                    for (i = 1; i <= nm; i++) {
                        sep = (i > 1) ? "+" : ""
                        cmods = cmods sep mtok[i]
                    }
                    key = fld[2]
                    gsub(/^[ \t]+|[ \t]+$/, "", key)
                    id = kind SUBSEP cmods SUBSEP key
                    if (id in seen) {
                        print "  FAIL binds: duplicate " kind " [" cmods " + " key "] at " seen[id] " and " bloc[b] | "cat 1>&2"
                        rc = 1
                    } else {
                        seen[id] = bloc[b]
                    }
                }
                exit rc
            }
        ' "${BINDS_FILES[@]}" || rc=1
    fi
    report binds "$rc"
}

# ---- main ------------------------------------------------------------------------

CHECKS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-missing) SKIP_MISSING=1 ;;
        -h|--help) usage; exit 0 ;;
        bash|shellcheck|json|emacs|lua|cpp|themes|binds|all) CHECKS+=("$1") ;;
        *) echo "lint.sh: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
[[ ${#CHECKS[@]} -gt 0 ]] || { usage >&2; exit 2; }

EXPANDED=()
for c in "${CHECKS[@]}"; do
    if [[ $c == all ]]; then
        EXPANDED+=(bash shellcheck json emacs lua cpp themes binds)
    else
        EXPANDED+=("$c")
    fi
done

for c in "${EXPANDED[@]}"; do
    echo "==> check: $c"
    "check_$c"
done

echo
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo "==> SKIPPED (tool absent): ${SKIPPED[*]}"
    echo "    did not run here — CI enforces them on every push"
fi
if [[ $FAILS -eq 0 ]]; then
    if [[ ${#SKIPPED[@]} -eq 0 ]]; then
        echo "==> SUMMARY: all requested checks passed."
    else
        echo "==> SUMMARY: all runnable checks passed; skips named above."
    fi
    exit 0
fi
echo "==> SUMMARY: $FAILS check(s) failed — see FAIL lines above."
exit 1
