#!/usr/bin/env bash
# stage1.sh — runs on the Arch ISO, as root.
#
#   usage: stage1.sh <host>        e.g. stage1.sh desktop
#
# Partitions DISK (destructive!), creates filesystems, mounts everything
# under /mnt, mounts the data disks so genfstab records them, runs
# pacstrap + genfstab, and copies this repo into the target for stage 2.
#
# Guard rails: refuses to run without UEFI, refuses a mounted target,
# and requires typing the disk's serial number — not y/N — to proceed.

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
read -rp "Type the disk serial to continue: " CONFIRM
[[ "$CONFIRM" == "$SERIAL" ]] || { echo "Serial mismatch — aborting."; exit 1; }

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

# -------------------------------------------------------------- pacstrap
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$REPO_DIR/packages/pacstrap.txt")
pacstrap -K /mnt "${PACKAGES[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# Data disks must never block booting when one dies or is unplugged.
for label in "${DATA_LABELS[@]}"; do
    sed -i "\|/mnt/$label|s|defaults|defaults,nofail,x-systemd.device-timeout=5s|" /mnt/etc/fstab
done

# ---------------------------------------------------- hand off to stage 2
rsync -a "$REPO_DIR/" /mnt/root/phoinix/
cp /var/log/stage1.log /mnt/var/log/stage1.log

echo
echo "stage 1 done. Next:"
echo "  arch-chroot /mnt /root/phoinix/base/stage2.sh $HOST"
