#!/usr/bin/env bash
# rice-update-check.sh — notify-only "the rice repo has new commits" ping,
# run daily by rice-update-check.timer (config/systemd/user/).
#
# Reads deployed.env for RICE_REPO + RICE_BRANCH — i.e. whatever the last
# deploy was actually built from (main normally; a feature branch only if
# someone deliberately decided to track one through 60-update.sh). Fetches,
# counts HEAD..origin/<branch>, and notify-sends through swaync when > 0.
# It NEVER applies anything and NEVER writes deployed.env; --dry-run is
# unnecessary because that is all it does.
#
# All failures (offline, repo moved, uncommitted-mid-update state) exit 0
# silently — a notifier must not light up systemctl --user --failed just
# because a laptop had no network for a day.

set -uo pipefail

ENV_FILE="$HOME/.local/state/hyprland-fat-rice/deployed.env"
[[ -f $ENV_FILE ]] || exit 0

# shellcheck disable=SC1090
. "$ENV_FILE"
[[ -n ${RICE_REPO:-} && -n ${RICE_BRANCH:-} ]] || exit 0
[[ -d $RICE_REPO/.git ]] || exit 0

git -C "$RICE_REPO" fetch --quiet origin 2>/dev/null || exit 0   # offline today
n=$(git -C "$RICE_REPO" rev-list --count "HEAD..origin/$RICE_BRANCH" 2>/dev/null || echo 0)
[[ $n =~ ^[0-9]+$ ]] || n=0
if (( n > 0 )); then
    notify-send "Hyprland rice" \
        "$n new commit(s) on origin/$RICE_BRANCH — run scripts/60-update.sh to upgrade"
fi
exit 0
