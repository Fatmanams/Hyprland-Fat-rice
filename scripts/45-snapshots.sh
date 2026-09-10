#!/usr/bin/env bash
# 45-snapshots.sh — system snapshot tooling, picked by the root filesystem.
#
# archinstall asks "btrfs or ext4?" at partitioning time; this script is
# where the rice stops being indifferent about the answer:
#
#   btrfs  -> snapper: snapshots are btrfs subvolume snapshots — instant
#             copy-on-write, no separate backup partition needed. Snapper
#             CANNOT work on ext4; there is no subvolume to snapshot.
#   ext4 (or anything else) -> timeshift in RSYNC mode: file-level copies
#             onto a target partition, filesystem-agnostic. (Timeshift's
#             BTRFS mode would just be snapper-with-a-GUI — on btrfs you
#             already have the native tool above.)
#
# Both are official-repo (extra) packages — package policy rule 1,
# nothing AUR. This script is the single place the btrfs-vs-ext4
# question is answered; if that policy ever changes, change both
# branches here in lockstep.
#
# Deliberately NOT done here (nothing silent):
#   * taking a first snapshot — a timeshift rsync baseline is a
#     full-tree copy and can take a long while; run it yourself with
#     the command this script prints at the end
#   * pacman transaction hooks (snap-pac & friends) — AUR-only, would
#     need the 10-aur.sh pipeline
#   * a /home config — snapshots cover the system root only
#
# Run as your normal user; it sudos where needed (same as 00-base.sh).

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Don't run this as root. Run as your normal user; it'll sudo where needed."
    exit 1
fi

echo "==> [1/3] Detecting root filesystem"
ROOT_FS=$(findmnt -n -o FSTYPE /)
ROOT_DEV=$(findmnt -n -o SOURCE /)
echo "    / is $ROOT_FS on $ROOT_DEV"

if [[ "$ROOT_FS" == "btrfs" ]]; then
    echo "==> [2/3] Installing snapper (official extra)"
    sudo pacman -S --needed --noconfirm snapper

    echo "==> [3/3] Configuring snapper: root config, retention, timers"
    if sudo snapper list-configs 2>/dev/null | awk '{print $1}' | grep -qx root; then
        echo "    snapper root config already exists — leaving it alone."
    elif [[ -e /.snapshots ]]; then
        # archinstall's btrfs layout pre-mounts an empty subvolume at
        # /.snapshots, which makes `create-config /` refuse to run.
        # ArchWiki's fix: drop the empty subvolume, let create-config
        # recreate the dir itself, then remount.
        echo "    /.snapshots already exists (typical archinstall btrfs layout)"
        echo "    and snapper's create-config refuses to touch it."
        read -r -p "    Unmount, delete the EMPTY /.snapshots subvolume, create config, remount? [y/N] " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            sudo umount /.snapshots 2>/dev/null || true
            if ! sudo btrfs subvolume delete /.snapshots 2>/dev/null; then
                sudo rmdir /.snapshots
            fi
            sudo snapper -c root create-config /
            sudo mkdir -p /.snapshots
            # archinstall's fstab usually has a /.snapshots entry — remount it.
            grep -qE '[[:space:]]/\.snapshots[[:space:]]' /etc/fstab && sudo mount /.snapshots || true
            echo "    root config created; /.snapshots remounted."
        else
            echo "    Skipped. Re-run this script after clearing /.snapshots"
            echo "    yourself, or create the config by hand:"
            echo "      sudo snapper -c root create-config /"
            exit 0
        fi
    else
        sudo snapper -c root create-config /
    fi

    # The default template retains far more than a desktop needs; trim
    # to hourly x5 + daily x7, weekly and coarser off. NUMBER_* caps the
    # manual/config snapshots the same way.
    sudo snapper -c root set-config \
        TIMELINE_CREATE=yes TIMELINE_CLEANUP=yes \
        TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
        TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
        NUMBER_CLEANUP=yes NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5

    sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
    echo "    snapper live: timeline timer (hourly) + cleanup timer enabled."
    echo "    Manual snapshot: sudo snapper -c root create -d 'why'"
else
    echo "==> [2/3] Installing timeshift + cronie (official extra)"
    sudo pacman -S --needed --noconfirm timeshift cronie

    echo "==> [3/3] Configuring Timeshift in RSYNC mode on $ROOT_DEV"
    # Config is written through Timeshift's own CLI — never a
    # hand-written default.json (the file's shape drifts between
    # releases, and a stale key set is silently half-read).
    sudo timeshift --rsync --snapshot-device "$ROOT_DEV"
    if [[ ! -f /etc/timeshift/default.json && ! -f /etc/timeshift/timeshift.json ]]; then
        echo "    Timeshift didn't persist a config — run the first-run"
        echo "    wizard once by hand (RSYNC mode, target $ROOT_DEV):"
        echo "      sudo timeshift-gtk"
    fi

    # Arch's timeshift schedules through /etc/cron.d, which needs
    # cronie actually running.
    sudo systemctl enable --now cronie.service
    echo "    RSYNC mode set, target $ROOT_DEV, cronie enabled."
    echo "    First snapshot (full-tree copy — takes a while):"
    echo "      sudo timeshift --create --comments 'baseline'"
fi
