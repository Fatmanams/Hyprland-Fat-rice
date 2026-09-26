#!/usr/bin/env bash
# 61-rollback.sh — return the rice to the state recorded before the last
# failed update. Called automatically by 60-update.sh on any gate failure;
# also runnable standalone any time a rollback.env exists.
#
# Scope, in order:
#   1. git: restore the checkout to RICE_PREV_BRANCH@RICE_PREV_COMMIT.
#      Named checkout when the branch still points where the update started;
#      retract the branch when its tip is the failed update's own ff-advance;
#      DETACHED checkout (with a loud note) when someone else moved the
#      branch — no force-reset of refs we don't own, ever.
#   2. ~/.config: restore from RICE_CONFIG_BACKUP (the backup 30-dotfiles.sh
#      took at deploy time, i.e. the pre-update state).
#   3. Re-run 30-dotfiles.sh so binary artifacts (keybind-menu's -DRICE_REPO
#      build) match the restored source.
#   4. Re-gate: hyprctl reload + configerrors, then 50-verify.sh, and report
#      whether the rollback itself came back clean.
#
# Rollback NEVER touches package state. If the failing phase was 00/10/20/40/
# 45, the report says so loudly and prints the snapshot restore command for
# the detected tool; it does NOT run it.
#
# Exit codes: 0 rollback complete + verified / 2 no rollback state found /
# 3 rollback itself failed (report tells you to use the snapshot or Plasma).

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as your normal user — rollback writes to your home, not root's." >&2
    exit 2
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RICE_REPO_ROOT:-$(cd "$SELF_DIR/.." && pwd)}"

# Same re-exec guard as 60: step 1 checks the repo out at an older commit,
# which can rewrite THIS file while bash is parsing it. Copy self+lib into
# a temp dir and re-exec from there once.
if [[ -z ${RICE_ROLLBACK_REEXEC:-} ]]; then
    RUNDIR=$(mktemp -d)
    mkdir -p "$RUNDIR/scripts/lib"
    cp "$REPO_ROOT/scripts/61-rollback.sh" "$RUNDIR/scripts/61-rollback.sh"
    cp -a "$REPO_ROOT/scripts/lib/." "$RUNDIR/scripts/lib/"
    RICE_ROLLBACK_REEXEC=1 RICE_RUNNING_FROM="$RUNDIR" RICE_REPO_ROOT="$REPO_ROOT" \
        exec bash "$RUNDIR/scripts/61-rollback.sh" "$@"
fi
trap 'rm -rf "$RICE_RUNNING_FROM"' EXIT

# shellcheck source=scripts/lib/rice-version.sh
. "$RICE_RUNNING_FROM/scripts/lib/rice-version.sh"

RB_FILE=$(rice_rollback_file)
ENV_FILE=$(rice_env_file)

if [[ ! -f $RB_FILE ]]; then
    echo "61-rollback: no $RB_FILE — nothing recorded to roll back to." >&2
    echo "If the system is broken anyway: log in via the Plasma session in" >&2
    echo "SDDM and restore the snapshot shown by 'snapper list' / Timeshift." >&2
    exit 2
fi

# shellcheck disable=SC1090
. "$RB_FILE"
: "${RICE_PREV_COMMIT:?rollback.env is missing RICE_PREV_COMMIT}"
: "${RICE_PREV_BRANCH:?rollback.env is missing RICE_PREV_BRANCH}"
FAILED_PHASE=${RICE_FAILED_PHASE:-manual}
SNAPSHOT=${RICE_SNAPSHOT:-none}
BACKUP=${RICE_CONFIG_BACKUP:-}
[[ -n $BACKUP && -d $BACKUP ]] || BACKUP=$(ls -1dt "$HOME"/.config-backup-* 2>/dev/null | head -n 1)

echo "==> Rolling back to ${RICE_PREV_BRANCH}@${RICE_PREV_COMMIT:0:12}"
echo "    failed phase: $FAILED_PHASE"
echo "    snapshot:     $SNAPSHOT"

rollback_failed=0

# ---- 1. git -----------------------------------------------------------------

echo "==> [1/4] Restoring git checkout"
if ! rice_git_restore "$REPO_ROOT" "$RICE_PREV_BRANCH" "$RICE_PREV_COMMIT" "${RICE_TARGET_COMMIT:-}"; then
    echo "    git restore FAILED" >&2
    rollback_failed=1
fi

# ---- 2. ~/.config ------------------------------------------------------------

echo "==> [2/4] Restoring ~/.config"
if [[ -n $BACKUP && -d $BACKUP ]]; then
    # rsync if available for --delete parity, else plain cp -a.
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$BACKUP/" "$HOME/.config/" || rollback_failed=1
    else
        cp -a "$BACKUP/." "$HOME/.config/" || rollback_failed=1
    fi
    echo "    restored from $BACKUP"
else
    echo "    note: RICE_CONFIG_BACKUP unset — nothing deployed this run had" >&2
    echo "    rewritten ~/.config yet (or it was a lint-gate failure)." >&2
    echo "    Skipping the config restore step."
fi

# ---- 3. rebuild from restored source ------------------------------------------

echo "==> [3/4] Re-deploying from the restored checkout (30-dotfiles.sh)"
local_30_rc=0
bash "$REPO_ROOT/scripts/30-dotfiles.sh" || local_30_rc=$?
if [[ $local_30_rc -ne 0 ]]; then
    echo "    30-dotfiles.sh FAILED during rollback (rc=$local_30_rc)" >&2
fi
# Pin the identity fields no matter how the 30-run went: if the restore
# worked, deployed.env must describe the RESTORED tree or the drift check
# in 50-verify will false-fail the rollback itself. An older 30-dotfiles.sh
# may predate the env writer entirely, then this is what writes it at all.
rice_env_set "$ENV_FILE" RICE_COMMIT  "$(git -C "$REPO_ROOT" rev-parse HEAD)"
rice_env_set "$ENV_FILE" RICE_BRANCH  "$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
rice_env_set "$ENV_FILE" RICE_VERSION "$(rice_version_of "$REPO_ROOT")"
rice_env_set "$ENV_FILE" RICE_REPO    "$REPO_ROOT"
rice_env_set "$ENV_FILE" RICE_DEPLOYED_AT "$(date -Iseconds)"
[[ $local_30_rc -eq 0 ]] || rollback_failed=1

# ---- 4. re-gate ----------------------------------------------------------------

echo "==> [4/4] Verifying the rollback"
rollback_verify=pass
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload || rollback_verify=fail
    rb_errors=$(hyprctl configerrors 2>&1 || true)
    [[ -z $rb_errors ]] || { echo "$rb_errors" >&2; rollback_verify=fail; }
else
    echo "    not inside a Hyprland session — skipping hyprctl re-check."
fi
bash "$REPO_ROOT/scripts/50-verify.sh" || rollback_verify=fail

rice_env_set "$ENV_FILE" RICE_VERIFY "$rollback_verify"
printf '%s rollback env=%s branch=%s prev=%s@%s snapshot=%s verify=%s\n' \
    "$(date -Iseconds)" "$(basename "$ENV_FILE")" \
    "${RICE_PREV_BRANCH:-?}" "${RICE_PREV_COMMIT:-unknown}" "$SNAPSHOT" \
    "$rollback_verify" >> "$(rice_update_log)"

# ---- report --------------------------------------------------------------------

echo
echo "==> Rollback report"
echo "    git:      now at $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)@$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
if [[ -n $BACKUP ]]; then echo "    config:   restored from $BACKUP (and rebuilt from restored source)"; fi
echo "    verify:   $rollback_verify"
echo "    snapshot: $SNAPSHOT (untouched — a deeper escape hatch, see below)"

if [[ $FAILED_PHASE =~ ^(00-base|10-aur|20-sddm|40-gaming|45-snapshots)$ ]]; then
    echo
    echo "    !! The failed phase ($FAILED_PHASE) changes packages or system"
    echo "    !! state, and rollback does NOT and will never revert that. If the"
    echo "    !! breakage is at the system level, restore the snapshot by hand:"
    if [[ $SNAPSHOT != none ]]; then
        if [[ ${ROOT_FS:=$(findmnt -n -o FSTYPE /)} == btrfs ]]; then
            echo "    !!   sudo snapper undochange $SNAPSHOT..0"
        else
            echo "    !!   sudo timeshift --restore --snapshot '$SNAPSHOT'"
        fi
    else
        echo "    !!   (no snapshot was taken this run — nothing to point at; the"
        echo "    !!    Plasma session at SDDM is the fallback)"
    fi
    echo "    !! (We will never run that for you — it's your call.)"
fi

if [[ $rollback_failed -ne 0 || $rollback_verify == fail ]]; then
    echo
    echo "==> ROLLBACK DID NOT COME BACK CLEAN."
    echo "    Snapshot: $SNAPSHOT"
    echo "    Last resort: reboot, pick the Plasma session at the SDDM screen,"
    echo "    and restore the snapshot (command above if applicable). The Plasma"
    echo "    session is kept installed for exactly this case."
    exit 3
fi

echo "==> Rollback complete and self-verified."
exit 0
