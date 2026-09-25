#!/usr/bin/env bash
# 60-update.sh — update the rice checkout from origin and redeploy, with
# automatic fail-safe rollback when any gate fails.
#
# Pipeline (each phase prints its own ==> banner):
#   1/8 Preflight  — root? git checkout? clean worktree? deployed.env?
#                    update lock free? --branch exists on origin?
#                    Anything wrong here exits 2 with the reason.
#   2/8 Fetch      — git fetch --tags + show `git log HEAD..origin/<branch>`.
#                    --dry-run stops here (nothing written). Offline = abort.
#   3/8 Snapshot   — snapper (btrfs) or timeshift (else), detected the same
#                    way 45-snapshots.sh does. Missing/failed tool = abort,
#                    unless --no-snapshot. Records the return ticket.
#   4/8 Advance    — git merge --ff-only origin/<branch> ONLY. A non-ff
#                    (diverged history) aborts; nothing was deployed yet.
#   5/8 Lint gate  — the same checks lint.yml runs, on the NEW tree.
#                    Failure: checkout rolled back, exit. Nothing deployed.
#   6/8 Apply      — re-run 00 10 20 30 40 45 in order. Scripts take no
#                    flags; the interactive bits (10-aur's PKGBUILD review)
#                    STAY interactive, that's deliberate.
#   7/8 Gate       — hyprctl reload exit status, then hyprctl configerrors
#                    (both skipped with a note outside a Hyprland session),
#                    then scripts/50-verify.sh's exit code.
#   8/8 Report     — version before -> after, gate results, snapshot id,
#                    state dir path. Exit 0 only when every gate passed.
#
# Any failure from phase 6 on triggers 61-rollback.sh automatically.
# Rollback NEVER touches package state — if the failing phase was
# 00/10/20/40/45, its report prints the snapshot restore command and leaves
# the decision to you.
#
# Branch tracking: --branch <name> tracks origin/<name> through the same
# pipeline, so a feature branch gets full-system testing before its PR
# merges. `--branch main` (or plain 60-update.sh) tracks main again.
#
# Exit codes: 0 ok | 1 aborted (offline / non-ff / snapshot / lint / a gate
# failed but rollback succeeded) | 2 preflight refusal | 3 gate failed AND
# rollback failed.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user, not root — the update writes state into" >&2
    echo "your home and redeploys your configs." >&2
    exit 2
fi

# Preflight first, before anything mutates: a non-repo script location
# can't even complete the self-reexec copy below, so rule it out up front.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RICE_REPO_OVERRIDE:-$(cd "$SELF_DIR/.." && pwd)}"
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "    $REPO_ROOT is not a git checkout — the updater needs the clone." >&2
    exit 2
fi

# Self-reexec: `merge --ff-only` may rewrite this very script (or the lib /
# 61) while bash is still parsing it. Copy the trio to a temp dir and
# re-exec once from there; RICE_REPO_OVERRIDE carries the real repo path
# across so it is not recomputed from the temp copy.
if [[ -z ${RICE_UPDATE_REEXEC:-} ]]; then
    RUNDIR=$(mktemp -d)
    mkdir -p "$RUNDIR/scripts/lib"
    cp "$REPO_ROOT/scripts/60-update.sh" "$RUNDIR/scripts/60-update.sh"
    cp "$REPO_ROOT/scripts/61-rollback.sh" "$RUNDIR/scripts/61-rollback.sh"
    cp -a "$REPO_ROOT/scripts/lib/." "$RUNDIR/scripts/lib/"
    RICE_UPDATE_REEXEC=1 RICE_RUNNING_FROM="$RUNDIR" RICE_REPO_OVERRIDE="$REPO_ROOT" \
        exec bash "$RUNDIR/scripts/60-update.sh" "$@"
fi
trap 'rm -rf "$RICE_RUNNING_FROM"' EXIT

# shellcheck source=scripts/lib/rice-version.sh
. "$RICE_RUNNING_FROM/scripts/lib/rice-version.sh"
RUN61="$RICE_RUNNING_FROM/scripts/61-rollback.sh"
ENV_FILE=$(rice_env_file)
RB_FILE=$(rice_rollback_file)
STATE_DIR=$(rice_state_dir)

# ---- args -------------------------------------------------------------------

BRANCH=main
DRY_RUN=0
NO_SNAPSHOT=0
STASH=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)     DRY_RUN=1; shift ;;
        --no-snapshot) NO_SNAPSHOT=1; shift ;;
        --stash)       STASH=1; shift ;;
        --branch)
            [[ -n ${2:-} ]] || { echo "--branch needs a value" >&2; exit 2; }
            BRANCH=$2; shift 2 ;;
        -h|--help)
            printf 'usage: %s [--branch <name>] [--dry-run] [--no-snapshot] [--stash]\n' \
                "$0"
            exit 0 ;;
        *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
    esac
done
[[ $BRANCH =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "bogus branch name: $BRANCH" >&2; exit 2; }

rice_log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$(rice_update_log)"; }

# ---- 1/8 preflight ------------------------------------------------------------

echo "==> [1/8] Preflight"

if [[ -n $(git -C "$REPO_ROOT" status --porcelain) ]]; then
    if [[ $STASH -eq 1 ]]; then
        git -C "$REPO_ROOT" stash push -m "rice-update autostash $(date -Iseconds)"
        echo "    dirty worktree — stashed; recover with: git stash pop"
        echo "    (rollback never re-applies your stash; that's manual on purpose)"
    else
        echo "    worktree is dirty. Commit your changes, or re-run with --stash." >&2
        exit 2
    fi
fi

if [[ ! -f $ENV_FILE ]]; then
    echo "    no deployed.env at $ENV_FILE — this machine has no recorded" >&2
    echo "    deploy yet. Run the 00–50 sequence once first (30-dotfiles.sh" >&2
    echo "    is what writes that file)." >&2
    exit 2
fi

# Locking is the write-y part of preflight; --dry-run is documented to write
# absolutely nothing, so it skips the lock (two dry-runs racing is harmless).
if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$STATE_DIR"
    LOCKFILE=$(rice_lock_file)
    exec {LOCKFD}>"$LOCKFILE"
    if ! flock -n "$LOCKFD"; then
        echo "    another update run holds $LOCKFILE — not running in parallel." >&2
        exit 2
    fi
fi

PREV_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
PREV_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)

if [[ $BRANCH != main ]]; then
    # Local remote-refs first; if unknown, fetch just that branch (it may
    # have been pushed since the last fetch) before giving up.
    if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
        # Only updates origin/$BRANCH — no full fetch, no reflpocalypse.
        git -C "$REPO_ROOT" fetch --quiet origin \
            "refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" 2>/dev/null || true
    fi
    if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
        echo "    origin/$BRANCH doesn't exist. Remote branches I can see:" >&2
        git -C "$REPO_ROOT" branch -r >&2
        exit 2
    fi
    echo "    note: tracking origin/$BRANCH — unmerged/unreviewed work (AGENTS.md PR discipline)"
fi

# ---- 2/8 fetch + report -------------------------------------------------------

echo "==> [2/8] Fetching origin"
if ! git -C "$REPO_ROOT" fetch --tags origin; then
    echo "    git fetch failed (offline? origin down?). Clean abort:" >&2
    echo "    no snapshot taken, nothing advanced, nothing deployed." >&2
    exit 1
fi

TARGET="origin/$BRANCH"
TARGET_COMMIT=$(git -C "$REPO_ROOT" rev-parse "$TARGET")

echo "    HEAD..$TARGET:"
git -C "$REPO_ROOT" log --oneline "HEAD..$TARGET"

BEHIND=$(git -C "$REPO_ROOT" rev-list --count "HEAD..$TARGET" 2>/dev/null || echo 0)

if [[ $DRY_RUN -eq 1 ]]; then
    echo "==> dry-run: $BEHIND commit(s) behind $TARGET. Nothing was written:"
    echo "    no snapshot, no advance, no deploy."
    exit 0
fi

if [[ $PREV_COMMIT == "$TARGET_COMMIT" && $PREV_BRANCH == "$BRANCH" ]]; then
    echo "==> already up to date at $TARGET."
    exit 0
fi

# One place decides ahead-ness: unpushed local commits on the branch we're
# already tracking would make the merge a non-fast-forward, and this updater
# never merges for you. Abort cleanly. (Switching to a *different* branch is
# legitimate and handled by the checkout in phase 4.)
AHEAD=$(git -C "$REPO_ROOT" rev-list --count "$TARGET..HEAD")
if [[ $AHEAD -gt 0 && $PREV_BRANCH == "$BRANCH" ]]; then
    echo "    local $PREV_BRANCH is $AHEAD commit(s) ahead of $TARGET." >&2
    echo "    That is not a fast-forward — aborting with nothing touched." >&2
    echo "    Push (and merge) the local commits first, or handle the" >&2
    echo "    divergence by hand." >&2
    exit 1
fi

OLD_VER=$(rice_version_of "$REPO_ROOT")
NEW_VER=$(git -C "$REPO_ROOT" describe --tags --always "$TARGET_COMMIT")

# ---- 3/8 snapshot -------------------------------------------------------------

echo "==> [3/8] Failsafe snapshot (before any change)"
SNAPSHOT=none
if [[ $NO_SNAPSHOT -eq 1 ]]; then
    echo "    --no-snapshot given: skipped. No system-level escape hatch"
    echo "    this run — the rollback still covers git + ~/, not packages."
else
    # Same root-fs fork 45-snapshots.sh installs and 50-verify.sh checks.
    ROOT_FS=$(findmnt -n -o FSTYPE /)
    if [[ $ROOT_FS == btrfs ]]; then
        if ! command -v snapper >/dev/null 2>&1; then
            echo "    btrfs root but no snapper — run scripts/45-snapshots.sh," >&2
            echo "    or pass --no-snapshot if you really mean it." >&2
            exit 1
        fi
        if ! SNAPSHOT=$(sudo snapper -c root create --print-number \
                        -d "pre-rice-update $NEW_VER"); then
            echo "    snapper failed — refusing to update without the hatch." >&2
            exit 1
        fi
        echo "    snapper snapshot #$SNAPSHOT"
    else
        if ! command -v timeshift >/dev/null 2>&1; then
            echo "    $ROOT_FS root but no timeshift — run scripts/45-snapshots.sh," >&2
            echo "    or pass --no-snapshot if you really mean it." >&2
            exit 1
        fi
        if ! sudo timeshift --create --comments "pre-rice-update $NEW_VER"; then
            echo "    timeshift failed — refusing to update without the hatch." >&2
            exit 1
        fi
        SNAPSHOT=$(sudo ls -1t /timeshift/snapshots | head -n 1)
        echo "    timeshift snapshot: $SNAPSHOT"
    fi
fi

# Return ticket, BEFORE advancing. TARGET_COMMIT is recorded so rollback can
# tell "we advanced this branch ourselves" apart from "someone else moved it".
rice_rollback_write "$PREV_COMMIT" "$PREV_BRANCH" "$SNAPSHOT" "$TARGET_COMMIT" "$BRANCH"
rice_env_set "$ENV_FILE" RICE_SNAPSHOT "$SNAPSHOT"
rice_log "update-start branch=$BRANCH prev=$PREV_BRANCH@$PREV_COMMIT target=$TARGET_COMMIT snapshot=$SNAPSHOT"

# ---- 4/8 advance (ff-only, never anything else) --------------------------------

echo "==> [4/8] Advancing checkout to $TARGET"
if [[ $PREV_BRANCH != "$BRANCH" ]]; then
    if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git -C "$REPO_ROOT" checkout "$BRANCH"
    else
        git -C "$REPO_ROOT" checkout -b "$BRANCH" --track "origin/$BRANCH"
    fi
fi
if ! git -C "$REPO_ROOT" merge --ff-only "$TARGET"; then
    echo "    $TARGET is NOT a fast-forward (history diverged)." >&2
    echo "    This updater never merges, rebases, or auto-resolves — the" >&2
    echo "    checkout was not advanced and nothing was deployed." >&2
    rice_log "update-abort branch=$BRANCH reason=non-ff target=$TARGET_COMMIT"
    exit 1
fi

# ---- 5/8 lint gate on the new tree ----------------------------------------------

echo "==> [5/8] Lint gate (fast subset of .github/workflows/lint.yml)"
# This gate runs what can run on the box right now without installing
# anything: bash -n on all scripts (incl. scripts/lib/, systemd helpers),
# jq parse on the three `// -prefixed` JSONs + wlogout's layout, the
# g++ -fsyntax-only build of keybind-menu.cpp, and the lint-themes.sh
# palette-sync check (pure bash + comm). CI additionally runs shellcheck,
# emacs byte-compile, and luajit (tools the box may not have).
# If the new tree breaks any of those, it fails here too IF and ONLY IF
# the tool is present — so keep them non-optional in CI, never silent here.
# NOTE: a (...)-list followed by `||` DISABLES `set -e` inside it, so this
# gate runs in a subshell with set -e and the parent captures the status
# with errexit deliberately off.
set +e
(
    set -e
    cd "$REPO_ROOT"
    for f in scripts/*.sh scripts/lib/*.sh \
             config/hypr/gpu-env.sh config/hypr/switch-theme.sh config/hypr/start-mpvpaper.sh \
             config/vlc/vlc-open config/ghostty/ghostty-theme.sh \
             config/clamav/scan-targets.sh config/croft/croft-launch.sh \
             config/ox/ox-theme.sh config/ox/ox-launch.sh config/neomacs/neomacs-launch.sh \
             config/systemd/user/rice-update-check.sh; do
        [[ -e $f ]] || continue   # a file may arrive/leave with the update
        bash -n "$f"
    done
    for f in config/swaync/config.json config/zed/settings.json config/zed/keymap.json postgres-language-server.jsonc; do
        sed '/^\/\//d' "$f" | jq empty
    done
    sed '/^\/\//d' config/wlogout/layout | jq -s empty
    # The C++ check only exists once the keybind-menu branch lands; the
    # update that carries it adds the file, later updates keep checking it.
    if [[ -f config/rofi/keybind-menu.cpp ]]; then
        g++ -std=c++17 -Wall -Wextra -Werror -fsyntax-only config/rofi/keybind-menu.cpp
    fi
    # Same story for the theme-sync check (arrived with the theme system).
    if [[ -f scripts/lint-themes.sh ]]; then
        bash scripts/lint-themes.sh
    fi
)
lint_rc=$?
set -e
if [[ $lint_rc -ne 0 ]]; then
    echo "    lint gate FAILED on the new tree (rc=$lint_rc) — nothing was deployed." >&2
    echo "    Restoring the checkout and stopping." >&2
    rice_git_restore "$REPO_ROOT" "$PREV_BRANCH" "$PREV_COMMIT" "$TARGET_COMMIT"
    rice_log "update-abort branch=$BRANCH reason=lint-gate"
    exit 1
fi
echo "    lint gate passed"

# ---- 6/8 apply: re-run the install sequence -------------------------------------

FAILED_PHASE=none
for phase in 00-base 10-aur 20-sddm 30-dotfiles 40-gaming 45-snapshots; do
    echo "==> [6/8] deploy phase: $phase"
    # These scripts take no flags (they had none when written; don't invent
    # any) and their interactive prompts remain interactive on purpose.
    if ! bash "$REPO_ROOT/scripts/$phase.sh"; then
        echo "    phase $phase FAILED — automatic rollback." >&2
        FAILED_PHASE=$phase
        break
    fi
done
# Whatever happened, point rollback at the newest deploy backup 30 made this
# run (the pre-update ~/.config); a failed run before 30 keeps the previous
# deployed.env's path, which is still a sane state to return to.
upd_backup=$(rice_env_get "$ENV_FILE" RICE_CONFIG_BACKUP)
[[ -n $upd_backup ]] || upd_backup=$(ls -1dt "$HOME"/.config-backup-* 2>/dev/null | head -n 1)
rice_env_set "$RB_FILE" RICE_CONFIG_BACKUP "${upd_backup:-}"

# ---- 7/8 gate --------------------------------------------------------------------

    FAILED_GATE=none
    if [[ $FAILED_PHASE == none ]]; then
        echo "==> [7/8] Gates"
        if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
            if ! hyprctl reload; then
                echo "    hyprctl reload exited non-zero" >&2
                FAILED_GATE=hyprctl
            fi
            # Always look at configerrors too: Hyprland accepts a broken
            # config and reports errors rather than dying, so the reload
            # exit code alone is not sufficient.
            cfgerrors=$(hyprctl configerrors 2>&1 || true)
            if [[ -n $cfgerrors ]]; then
                echo "    hyprctl configerrors:" >&2
                echo "$cfgerrors" >&2
                [[ $FAILED_GATE == none ]] && FAILED_GATE=hyprctl-configerrors
            fi
        else
            echo "    no HYPRLAND_INSTANCE_SIGNATURE — not in a Hyprland session,"
            echo "    skipping hyprctl gates; 50-verify still runs."
        fi
        if [[ $FAILED_GATE == none ]]; then
            if ! bash "$REPO_ROOT/scripts/50-verify.sh"; then
                echo "    50-verify.sh FAILED (see its summary above)." >&2
                FAILED_GATE=50-verify
            fi
        fi
    fi

# ---- 8/8 report (rollback first on failure) ---------------------------------------

if [[ $FAILED_PHASE != none || $FAILED_GATE != none ]]; then
    what_failed=$FAILED_PHASE
    [[ $FAILED_PHASE == none ]] && what_failed="gate-$FAILED_GATE"
    rice_env_set "$RB_FILE" RICE_FAILED_PHASE "$what_failed"
    rice_log "update-failed branch=$BRANCH phase=$what_failed -> rollback"
    echo
    echo "==> Update FAILED (phase: $what_failed) — automatic rollback starting"
    if RICE_REPO_ROOT="$REPO_ROOT" bash "$RUN61"; then
        rb_rc=0
    else
        rb_rc=$?
    fi
    echo
    echo "==> Report"
    echo "    version:  $OLD_VER -> $NEW_VER (rolled back — NOT in effect)"
    echo "    failed:   $what_failed"
    echo "    rollback: $(if [[ $rb_rc -eq 0 ]]; then echo "complete + self-verified"; else echo "ITSELF FAILED — use snapshot $SNAPSHOT or the Plasma session at SDDM"; fi)"
    echo "    snapshot: $SNAPSHOT"
    echo "    state:    $STATE_DIR (deployed.env, rollback.env, update.log)"
    [[ $rb_rc -eq 0 ]] && exit 1 || exit 3
fi

rice_env_set "$ENV_FILE" RICE_VERIFY pass
rice_log "update-ok branch=$BRANCH commit=$TARGET_COMMIT ver=$NEW_VER snapshot=$SNAPSHOT"
echo
echo "==> Report"
echo "    version:  $OLD_VER -> $NEW_VER"
echo "    branch:   $BRANCH"
echo "    gates:    hyprctl + 50-verify all passed"
echo "    snapshot: $SNAPSHOT"
echo "    state:    $STATE_DIR (deployed.env, rollback.env, update.log)"
exit 0
