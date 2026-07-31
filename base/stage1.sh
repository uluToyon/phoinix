#!/usr/bin/env bash
# stage1.sh — runs on the Arch ISO, as root.
#
#   usage: stage1.sh <host>        e.g. stage1.sh desktop
#
# Partitions DISK (destructive!), creates filesystems, mounts everything
# under /mnt, mounts the data disks so genfstab records them, runs
# pacstrap + genfstab, and copies this repo into the target for stage 2.
#
# Guard rails, in order of how much they actually protect:
#   1. DISK is a /dev/disk/by-id/ path, i.e. it CONTAINS the disk's serial.
#      On any machine that is not this one it does not resolve and stage 1
#      aborts before touching anything. This is the real protection.
#   2. Refuses to run without UEFI.
#   3. Refuses a target that has mounted partitions, or that hosts the ISO.
#   4. A countdown, against the accidental invocation. PHOINIX_YES=1 skips it.
# There used to be a "type the disk serial to continue" prompt. It was dropped
# on purpose: the serial is two lines up in hosts/<host>/config.sh, so it only
# ever proved that the config had been read — while making the documented
# one-command install impossible. See docs/LOG.md 2026-07-31.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: stage1.sh <host>   (e.g. stage1.sh desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

# Log everything — this doubles as the installation record.
exec > >(tee -a /var/log/stage1.log) 2>&1

# ---------------------------------------------------------------- sanity
[[ -n "${DISK:-}" ]]      || { echo "ERROR: DISK not set in hosts/$HOST/config.sh"; exit 1; }
[[ -e "$DISK" ]]          || { echo "ERROR: $DISK does not exist"; exit 1; }
[[ -d /sys/firmware/efi ]] || { echo "ERROR: not booted in UEFI mode"; exit 1; }

REAL_DISK="$(readlink -f "$DISK")"

if lsblk -rno MOUNTPOINTS "$REAL_DISK" | grep -q .; then
    echo "ERROR: $REAL_DISK has mounted partitions — refusing."
    exit 1
fi
if [[ "$(lsblk -rno MOUNTPOINTS "$REAL_DISK" || true)" == *archiso* ]]; then
    echo "ERROR: $REAL_DISK hosts the running ISO — refusing."
    exit 1
fi

# ---------------------------------------------------------- confirmation
SERIAL="$(lsblk -dno SERIAL "$REAL_DISK")"
echo
echo "Target: $DISK"
echo "        ($REAL_DISK, serial: $SERIAL)"
echo
echo "Current contents that will be DESTROYED:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$REAL_DISK"
echo
if [[ "$REUSE_HOME" == 1 ]]; then
    echo "REUSE_HOME=1: partition table kept, only ESP + root re-formatted, home untouched."
else
    echo "Layout to create: ESP $ESP_SIZE | root $ROOT_SIZE (ext4) | home = rest (ext4)"
fi
# Deliberately NOT a prompt: this script is driven by scripts/bootstrap.sh from
# a single piped command, where stdin is the pipe and any `read` gets EOF, not
# a human. A countdown needs no stdin at all and still catches the one case
# the by-id check cannot: right machine, right disk, started by accident.
if [[ "${PHOINIX_YES:-0}" != 1 ]]; then
    for ((i = 10; i > 0; i--)); do
        printf '\r  DESTROYING the above in %2ds  (Ctrl-C to abort) ' "$i"
        sleep 1
    done
    printf '\r%*s\r' 55 ''
fi

timedatectl set-ntp true

# ------------------------------------------------------------- partition
ESP="${DISK}-part1"
ROOT="${DISK}-part2"
HOME_PART="${DISK}-part3"

if [[ "$REUSE_HOME" != 1 ]]; then
    sgdisk --zap-all "$DISK"
    sgdisk  -n1:0:+"$ESP_SIZE"  -t1:ef00 -c1:"EFI" \
            -n2:0:+"$ROOT_SIZE" -t2:8304 -c2:"root" \
            -n3:0:0             -t3:8302 -c3:"home" \
            "$DISK"
    partprobe "$REAL_DISK"
fi
udevadm settle

# ------------------------------------------------------------ filesystems
mkfs.fat  -F 32 -n EFI "$ESP"
mkfs.ext4 -F -L archroot "$ROOT"
if [[ "$REUSE_HOME" != 1 ]]; then
    mkfs.ext4 -F -L archhome "$HOME_PART"
fi

# ----------------------------------------------------------------- mount
mount "$ROOT" /mnt
mount --mkdir "$ESP" /mnt/boot
mount --mkdir "$HOME_PART" /mnt/home

# Mount data disks (never formatted!) so genfstab picks them up.
for label in "${DATA_LABELS[@]}"; do
    mount --mkdir "/dev/disk/by-label/$label" "/mnt/mnt/$label"
done

# ------------------------------------------------------------ mirrorlist
# Sorted BEFORE pacstrap, and that ordering is the whole point: pacstrap copies
# the ISO's /etc/pacman.d/mirrorlist into the new system, so whatever is in
# place at this moment is also what the installed machine keeps afterwards. One
# sort therefore pays twice — for the ~1 GB pacstrap pulls here, and for every
# package stage 3 installs later.
#
# Until 2026-07-31 the repo did not touch this at all: every install simply took
# whatever ordering the ISO happened to ship with. That worked, but it was luck
# rather than a decision, and luck is not what this repo is for.
#
# GUARDED, not assumed: archiso ships reflector today, but a download-speed
# optimisation must never be the reason an install aborts. No mirrors, no
# network, reflector gone — all of it falls through to the ISO's own list.
if command -v reflector >/dev/null 2>&1; then
    echo "sorting mirrors (${MIRROR_COUNTRY})..."
    if reflector --country "$MIRROR_COUNTRY" --protocol https --age 12 \
                 --latest 20 --sort rate --save /etc/pacman.d/mirrorlist 2>&1
    then
        echo "  mirrorlist: $(grep -c '^Server' /etc/pacman.d/mirrorlist) servers"
    else
        echo "  WARNING: reflector failed — keeping the ISO's mirrorlist"
    fi
else
    echo "no reflector on this ISO — keeping its mirrorlist as shipped"
fi

# -------------------------------------------------------------- pacstrap
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$REPO_DIR/packages/pacstrap.txt")
pacstrap -K /mnt "${PACKAGES[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# Data disks must never block booting when one dies or is unplugged.
# genfstab writes real option strings (rw,relatime,...), so append per field,
# matching the mountpoint column exactly.
# Timeout 30s, NOT less: SATA spinning disks need 10-20s to be probed at boot —
# 5s silently dropped all three on first boot (learned 2026-07-30).
labels_re="$(IFS='|'; echo "${DATA_LABELS[*]}")"
awk -v re="^/mnt/(${labels_re})$" '
    $1 !~ /^#/ && $2 ~ re { $4 = $4 ",nofail,x-systemd.device-timeout=30s" }
    { print }
' /mnt/etc/fstab > /mnt/etc/fstab.new && mv /mnt/etc/fstab.new /mnt/etc/fstab

# ---------------------------------------------------- hand off to stage 2
rsync -a "$REPO_DIR/" /mnt/root/phoinix/
cp /var/log/stage1.log /mnt/var/log/stage1.log

echo
echo "stage 1 done. bootstrap.sh continues with stage 2 by itself."
echo "Started by hand instead? Next:"
echo "  arch-chroot /mnt /root/phoinix/base/stage2.sh $HOST"
