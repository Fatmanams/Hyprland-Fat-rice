#!/usr/bin/env bash
# scripts/lib/rice-backup.sh — manifest-scoped ~/.config backup/restore
# for the deploy/update/rollback pipeline (30-dotfiles.sh /
# 60-update.sh / 61-rollback.sh). Sourced, never executed directly (the
# shebang exists for shellcheck's SC2148 under lint.yml's error pass).
#
# The rice only ever writes the paths its own config/ tree provides
# (minus config/applications/, which 30-dotfiles.sh keeps OUT of
# ~/.config), so both directions are scoped to exactly that set:
#
#   rice_backup_config REPO DEST
#       For every rice-owned path: copy the current ~/.config/<path>
#       into DEST/files/<path> (cp -a, symlinks stay links) and record
#       "present <path>", or record "absent <path>" when nothing is
#       there yet. DEST/MANIFEST carries the replay script, and
#       DEST/.rice-backup-complete is touched only after every copy
#       succeeded — a run that dies mid-backup leaves no marker, and a
#       markerless backup is never restorable. Browser profiles,
#       wallpapers, other apps' state: never copied, by design.
#
#   rice_restore_config BACKUP
#       Refuse a backup without the marker (incomplete or stale).
#       Then replay MANIFEST line by line: "present" -> copy the
#       saved file back over ~/.config/<path>, "absent" -> delete
#       exactly that one file. No rsync --delete, no directory
#       pruning: nothing outside the manifest is read, written, or
#       removed.
#
#   rice_backup_prune [KEEP]
#       Keep only the newest KEEP (default 5) ~/.config-backup-* dirs,
#       never one still referenced by deployed.env or rollback.env.

# shellcheck source=scripts/lib/rice-version.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rice-version.sh"

RICE_BACKUP_MARKER=.rice-backup-complete

# Rice-owned ~/.config paths, one per line, relative to ~/.config: the
# repo's config/ tree (git ls-files when REPO is a checkout, find
# otherwise), minus config/applications/ — 30-dotfiles.sh deletes that
# stray from ~/.config right after copying it, so it is not a deployed
# path and must not ride along in backups.
rice_backup_owned_paths() { # REPO -> stdout
    local repo=$1 p
    if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$repo" ls-files -- config/
    else
        (cd "$repo" && find config -type f)
    fi | while IFS= read -r p; do
        case $p in
            config/applications|config/applications/*) ;;
            config/*) printf '%s\n' "${p#config/}" ;;
        esac
    done
}

rice_backup_config() { # REPO DEST
    local repo=$1 dest=$2 list rel src dir
    if [[ -e $dest/$RICE_BACKUP_MARKER ]]; then
        echo "rice_backup_config: $dest already holds a complete backup —" >&2
        echo "refusing to overwrite it; pick a fresh destination." >&2
        return 1
    fi
    if ! list=$(rice_backup_owned_paths "$repo"); then
        echo "rice_backup_config: could not list rice-owned paths in $repo" >&2
        return 1
    fi
    if [[ -z $list ]]; then
        echo "rice_backup_config: no owned paths under $repo/config —" >&2
        echo "not a rice checkout? refusing to write an empty backup." >&2
        return 1
    fi
    mkdir -p "$dest/files"
    : > "$dest/MANIFEST"
    while IFS= read -r rel; do
        [[ -n $rel ]] || continue
        src="$HOME/.config/$rel"
        if [[ -e $src || -L $src ]]; then
            dir=${rel%/*}
            [[ $dir == "$rel" ]] || mkdir -p "$dest/files/$dir"
            cp -a -- "$src" "$dest/files/$rel" \
                || { echo "rice_backup_config: copy failed for $rel" >&2
                     return 1; }
            printf 'present %s\n' "$rel"
        else
            printf 'absent %s\n' "$rel"
        fi
    done <<<"$list" >>"$dest/MANIFEST"
    touch -- "$dest/$RICE_BACKUP_MARKER"
}

rice_restore_config() { # BACKUP
    local backup=$1 state rel dest saved
    if [[ ! -f $backup/$RICE_BACKUP_MARKER ]]; then
        echo "rice_restore_config: $backup lacks $RICE_BACKUP_MARKER —" >&2
        echo "incomplete or stale backup; refusing to restore from it." >&2
        return 1
    fi
    if [[ ! -f $backup/MANIFEST ]]; then
        echo "rice_restore_config: $backup/MANIFEST is missing — refusing." >&2
        return 1
    fi
    # Validate the whole manifest before touching anything, so a backup
    # that turns out corrupt can never leave a half-replayed ~/.config
    # because its line 300 was the broken one.
    while IFS=' ' read -r state rel; do
        [[ -n $state ]] || continue
        saved="$backup/files/$rel"
        case $state in
            present)
                if [[ ! -e $saved && ! -L $saved ]]; then
                    echo "rice_restore_config: saved copy missing for '$rel'" >&2
                    return 1
                fi ;;
            absent) ;;
            *)
                echo "rice_restore_config: bogus MANIFEST line: '$state $rel'" >&2
                return 1 ;;
        esac
    done <"$backup/MANIFEST"
    # Replay: "present" copies the saved file back (rm first so a
    # symlink parked at the destination can never be written through
    # into some other file; a directory sitting on a manifest path the
    # deploy clobbered gets cleared the same way — it is the manifest's
    # own path), "absent" deletes that one file and nothing else.
    while IFS=' ' read -r state rel; do
        [[ -n $state ]] || continue
        dest="$HOME/.config/$rel"
        if [[ $state == present ]]; then
            if [[ -d $dest && ! -L $dest ]]; then
                rm -rf -- "$dest" \
                    || { echo "rice_restore_config: cannot clear '$rel'" >&2
                         return 1; }
            else
                rm -f -- "$dest" \
                    || { echo "rice_restore_config: cannot clear '$rel'" >&2
                         return 1; }
            fi
            case $rel in
                */*) mkdir -p -- "$HOME/.config/${rel%/*}" \
                    || { echo "rice_restore_config: cannot create dir for '$rel'" >&2
                         return 1; } ;;
            esac
            cp -a -- "$backup/files/$rel" "$dest" \
                || { echo "rice_restore_config: copy failed for '$rel'" >&2
                     return 1; }
        else
            rm -f -- "$dest" \
                || { echo "rice_restore_config: cannot remove '$rel'" >&2
                     return 1; }
        fi
    done <"$backup/MANIFEST"
}

rice_backup_prune() { # [KEEP] — keep the newest ~/.config-backup-* dirs
    local keep=${1:-5} env_bak rb_bak d count
    env_bak=$(rice_env_get "$(rice_env_file)" RICE_CONFIG_BACKUP)
    rb_bak=$(rice_env_get "$(rice_rollback_file)" RICE_CONFIG_BACKUP)
    count=0
    while IFS= read -r d; do
        [[ -n $d ]] || continue
        count=$((count + 1))
        [[ $count -le $keep ]] && continue
        if [[ $d == "$env_bak" || $d == "$rb_bak" ]]; then
            echo "    keeping $d (still referenced by deployed.env/rollback.env)"
            continue
        fi
        echo "    pruning old config backup: $d"
        rm -rf -- "$d" || echo "    warn: could not prune $d" >&2
    done < <(ls -1dt "$HOME"/.config-backup-* 2>/dev/null || true)
}
