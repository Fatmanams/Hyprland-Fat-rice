#!/usr/bin/env bash
# scripts/lib/rice-version.sh — shared state store + version resolution
# for the update system (60-update.sh / 61-rollback.sh / 30-dotfiles.sh).
# Sourced, never executed directly (the shebang exists for shellcheck's
# SC2148 under lint.yml's error-severity pass).
#
# State lives under "$HOME/.local/state/hyprland-fat-rice/":
#   deployed.env   — what is deployed right now (written by 30-dotfiles.sh;
#                    RICE_SNAPSHOT/RICE_VERIFY finalized by 60/61 after gates)
#   rollback.env   — where to return to (written by 60-update.sh BEFORE the
#                    checkout advances; consumed by 61-rollback.sh, which is
#                    standalone-usable on its own too)
#   update.log     — one line per deploy, incl. branch (a real history)
#   update.lock    — flock target serializing update runs
#
# deployed.env is shell-sourceable by design (systemd EnvironmentFile=).
# Values must therefore never contain newlines.

# --- paths ----------------------------------------------------------------

rice_state_dir()     { printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-fat-rice"; }
rice_env_file()      { printf '%s/deployed.env\n'  "$(rice_state_dir)"; }
rice_rollback_file() { printf '%s/rollback.env\n'  "$(rice_state_dir)"; }
rice_update_log()    { printf '%s/update.log\n'    "$(rice_state_dir)"; }
rice_lock_file()     { printf '%s/update.lock\n'   "$(rice_state_dir)"; }

# --- single-key get/set on a KEY=VALUE env file ----------------------------

rice_env_get() { # FILE KEY -> stdout value (empty if missing)
    [[ -f $1 ]] || return 0
    sed -n "s/^$2=//p" "$1" | head -n 1
}

rice_env_set() { # FILE KEY VALUE — upsert one key, keep it 0600
    local f=$1 k=$2 v=$3
    touch "$f"
    chmod 600 "$f"
    if grep -q "^$k=" "$f"; then
        # $0=k"="v replaces the whole record; FS matters only for matching $1.
        # A VALUE containing '=' is safe: replacement is whole-line ($0=) and
        # rice_env_get strips only the first "$k=" prefix, so the value body
        # is never re-split. (A KEY with '=' would break this — keys here are
        # the fixed RICE_* constants, so that case can't occur.)
        awk -v k="$k" -v v="$v" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v} {print}' \
            "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        chmod 600 "$f"  # mv replaces the 0600 file with a fresh umask-made one
    else
        printf '%s=%s\n' "$k" "$v" >> "$f"
    fi
}

# --- version ---------------------------------------------------------------

# git describe --tags --always --dirty is the version string: with annotated
# tags it yields v1.2.0-3-gabc1234; before the first tag it degrades to the
# commit id alone (still unique, still honest). --dirty marks deploys from a
# dirty worktree (60 refuses those; a hand-run 30 can still produce one —
# honest record beats cosmetic cleanliness).
rice_version_of() { # REPO -> stdout
    git -C "$1" describe --tags --always --dirty 2>/dev/null || echo unknown
}

# --- deployed.env (30-dotfiles.sh calls this at the end of a deploy) -------

rice_env_write_deployed() { # REPO CONFIG_BACKUP_DIR
    local repo=$1 backup=$2 state_dir env_file
    state_dir=$(rice_state_dir)
    env_file="$state_dir/deployed.env"
    mkdir -p "$state_dir"

    # RICE_SNAPSHOT / RICE_VERIFY belong to the update/rollback gates; a
    # plain deploy keeps whatever was there (or the first-install defaults).
    local snap=none verify=pending
    if [[ -f $env_file ]]; then
        snap=$(rice_env_get "$env_file" RICE_SNAPSHOT)
        verify=$(rice_env_get "$env_file" RICE_VERIFY)
        [[ -n $snap ]]   || snap=none
        [[ -n $verify ]] || verify=pending
    fi

    local ver commit branch now
    ver=$(rice_version_of "$repo")
    commit=$(git -C "$repo" rev-parse HEAD)
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
    now=$(date -Iseconds)

    cat > "$env_file" <<EOF
RICE_VERSION=$ver
RICE_COMMIT=$commit
RICE_BRANCH=$branch
RICE_REPO=$repo
RICE_DEPLOYED_AT=$now
RICE_CONFIG_BACKUP=$backup
RICE_SNAPSHOT=$snap
RICE_VERIFY=$verify
EOF
    chmod 600 "$env_file"
    printf '%s deploy branch=%s commit=%s version=%s backup=%s snapshot=%s verify=%s\n' \
        "$now" "$branch" "$commit" "$ver" "$backup" "$snap" "$verify" \
        >> "$state_dir/update.log"
}

# --- rollback.env (60-update.sh writes this BEFORE advancing the checkout) -

rice_rollback_write() { # PREV_COMMIT PREV_BRANCH SNAPSHOT TARGET_COMMIT TARGET_BRANCH
    local state_dir f
    state_dir=$(rice_state_dir)
    f="$state_dir/rollback.env"
    mkdir -p "$state_dir"
    cat > "$f" <<EOF
RICE_PREV_COMMIT=$1
RICE_PREV_BRANCH=$2
RICE_SNAPSHOT=$3
RICE_TARGET_COMMIT=$4
RICE_TARGET_BRANCH=$5
RICE_CONFIG_BACKUP=
RICE_FAILED_PHASE=none
EOF
    chmod 600 "$f"
}

# --- git restore shared by 60's lint gate and 61 ---------------------------
#
# Restore the checkout to PREV_BRANCH@PREV_COMMIT. Cases, in order:
#   * prev branch tip still == prev commit      -> plain named checkout
#     (a checkout that switched branch but never advanced anything yet).
#   * prev branch tip == target commit          -> WE advanced it via the
#     ff-only merge this run, so moving it back is safe: checkout -B.
#   * tip is anything else                      -> someone else moved the
#     branch mid-update; do NOT force-reset a ref others may be using.
#     Detach at the recorded commit and say so loudly instead.
#   * branch no longer exists / never existed   -> detach at the commit.
#
# The caller logs; this function explains its choice and returns git's rc.
rice_git_restore() { # REPO PREV_BRANCH PREV_COMMIT [TARGET_COMMIT]
    local repo=$1 branch=$2 commit=$3 target=${4:-} tip

    if [[ $branch == HEAD ]]; then
        echo "    was detached at $commit before the update — returning detached" >&2
        git -C "$repo" checkout --detach "$commit"
        return
    fi

    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        tip=$(git -C "$repo" rev-parse "refs/heads/$branch")
        if [[ $tip == "$commit" ]]; then
            git -C "$repo" checkout "$branch"
            return
        fi
        if [[ -n $target && $tip == "$target" ]]; then
            echo "    moving $branch back to $commit (its tip is the" >&2
            echo "    failed update's own ff-advance; safe to retract)" >&2
            git -C "$repo" checkout -B "$branch" "$commit"
            return
        fi
        echo "    WARNING: branch '$branch' is at $tip — neither the pre-update" >&2
        echo "    commit nor this run's target. Something else advanced it;" >&2
        echo "    NOT resetting it. Detaching at $commit instead." >&2
    else
        echo "    branch '$branch' no longer exists locally — detaching at $commit" >&2
    fi
    git -C "$repo" checkout --detach "$commit"
}
