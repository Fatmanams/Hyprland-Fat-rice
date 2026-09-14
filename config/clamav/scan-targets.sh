#!/usr/bin/env bash
# Scan user-download and mail attachment locations with ClamAV.
# This is deliberately on-demand/daily rather than fanotify on-access:
# scanning all file events has a measurable performance cost.

set -uo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as the normal desktop user; clamscan does not need root here." >&2
    exit 1
fi

TARGETS=()
add_target() {
    [[ -d "$1" ]] && TARGETS+=("$1")
}

add_target "$HOME/Downloads"
add_target "$HOME/Mail/gmail"
add_target "$HOME/Mail/other"

# Scan mounted Windows user directories when they are available at boot.
for mount_root in /run/media/"$USER" /mnt; do
    [[ -d "$mount_root" ]] || continue
    while IFS= read -r -d '' users_dir; do
        add_target "$users_dir"
    done < <(find "$mount_root" -maxdepth 3 -type d -iname Users -print0 2>/dev/null)
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "No scan targets are present."
    exit 0
fi

mkdir -p "$HOME/.cache"
log_file="$HOME/.cache/clamav-scan.log"
clamscan --recursive --infected --log="$log_file" "${TARGETS[@]}"
scan_status=$?

case "$scan_status" in
    0)
        message="ClamAV scan clean (${#TARGETS[@]} locations)"
        notify-send --urgency=normal "ClamAV scan" "$message"
        ;;
    1)
        message="Threats detected; review $log_file"
        notify-send --urgency=critical "ClamAV scan" "$message"
        ;;
    *)
        message="Scan error (exit $scan_status); review $log_file"
        notify-send --urgency=critical "ClamAV scan error" "$message"
        ;;
esac

exit "$scan_status"
