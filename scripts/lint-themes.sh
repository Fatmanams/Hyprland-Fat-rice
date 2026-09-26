#!/usr/bin/env bash
# lint-themes.sh — prove all theme presets are internally synchronized.
#
# Palette contract: every preset dir in config/hypr/themes/ must carry the
# same 8 colors.* files switch-theme.sh copies; every hex in any file must
# come from that preset's own colors.sh (the single source of truth per
# theme). Templates under config/wal/templates/ use wal placeholders and are
# checked separately: every {placeholder} must be a name wal exports.
#
# Runs anywhere (CI, lint step, manual). No side effects, read-only.
# Exit 0 = synced. Exit 1 = drift found, with the offending file:line:hex.

set -u
cd "$(dirname "$0")/.." || exit 1

EXPECTED=(colors.sh colors.el colors-hyprland.conf colors-neomutt.muttrc \
          colors-rofi.rasi colors-wal.vim colors-waybar.css colors-zed.json)
FAILS=0

echo "==> [1/3] Per-preset file inventory"
for d in config/hypr/themes/*/; do
    name=${d%/}; name=${name##*/}
    missing=()
    for f in "${EXPECTED[@]}"; do
        [[ -f $d$f ]] || missing+=("$f")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "  FAIL $name: missing ${missing[*]}"
        ((FAILS++))
    else
        echo "  ok   $name: all ${#EXPECTED[@]} files present"
    fi
done
echo

echo "==> [2/3] Palette consistency inside each preset"
# For each preset, seed the known-color set from colors.sh; then walk every
# sibling colors.* file and flag any hex not declared there.
for d in config/hypr/themes/*/; do
    name=${d%/}; name=${name##*/}
    [[ -f $d/colors.sh ]] || continue
    mapfile -t KNOWN < <(grep -oE '#[0-9a-fA-F]{6}' "$d/colors.sh" | tr 'A-F' 'a-f' | sort -u)
    n=${#KNOWN[@]}
    # 8 files * ~19 entries each = manageable in shell
    bad=0
    for f in "${EXPECTED[@]}"; do
        [[ $f == colors.sh ]] && continue
        fp=$d/$f
        [[ -f $fp ]] || continue
        while IFS= read -r hex; do
            hexl=$(printf '%s' "$hex" | tr 'A-F' 'a-f')
            hit=0
            for k in "${KNOWN[@]}"; do [[ $k == "$hexl" ]] && { hit=1; break; }; done
            if [[ $hit -eq 0 ]]; then
                # explain with line number for fast fixing
                while IFS= read -r line; do
                    echo "  FAIL $name $f:$line hex $hex not in colors.sh"
                done < <(grep -nF "$hex" "$fp")
                bad=1
            fi
        done < <(grep -oE '#[0-9a-fA-F]{6}' "$fp" | sort -u)
    done
    if [[ $bad -eq 0 ]]; then
        echo "  ok   $name: $n base colors; all $((${#EXPECTED[@]}-1)) format files in sync"
    else
        ((FAILS++))
    fi
done
echo

echo "==> [3/3] switch-theme.sh copy list == preset inventory"
# Extract the exact `cp -f` block from switch-theme.sh and read the basenames
# off it. Then each preset dir must carry every name it lists. Comparing the
# other direction (presets list more than copied) is also a real bug — an
# orphan file nobody ever installs.
cp_block=$(sed -n '/cp -f/,/WAL_DIR\/"$/p' config/hypr/switch-theme.sh)
cp_list=$(printf '%s\n' "$cp_block" | grep -oE 'colors[A-Za-z0-9.-]+' | sort -u)
preset_list=$(printf '%s\n' "${EXPECTED[@]}" | sort)
if [[ "$cp_list" != "$preset_list" ]]; then
    only_cp=$(comm -23 <(printf '%s\n' "$cp_list") <(printf '%s\n' "$preset_list"))
    only_preset=$(comm -13 <(printf '%s\n' "$cp_list") <(printf '%s\n' "$preset_list"))
    echo "  FAIL: copy list and preset inventory differ"
    [[ -n $only_cp ]]     && echo "    in copy list but unexpected: $only_cp"
    [[ -n $only_preset ]] && echo "    in presets but never copied: $only_preset"
    ((FAILS++))
else
    echo "  ok: switch-theme.sh copies every file the presets ship"
fi
echo

if [[ $FAILS -eq 0 ]]; then
    echo "==> SUMMARY: theme system is fully synchronized."
else
    echo "==> SUMMARY: $FAILS check(s) failed — see FAIL lines above."
fi
exit "$FAILS"
