#!/usr/bin/env bash
# qemu-test.sh — run the installer against a throwaway VM.
#
#   usage: qemu-test.sh [--fresh] [--gui]
#
# DESIGN.md calls the QEMU loop "the thing that makes hand-rolling viable";
# this is that loop, as a script instead of a paragraph. It boots the Arch ISO
# with real UEFI firmware (OVMF — behaviour differs from BIOS enough to matter)
# against an empty virtual disk carrying the serial hosts/qemu/config.sh
# expects, so stage 1's by-id guard is exercised rather than bypassed.
#
# Default is a SERIAL console: no window, and the whole session is scriptable
# and logged. The ISO's own boot entry is reused verbatim (read out of the ISO,
# not guessed) with console=ttyS0 appended, because the boot menu cannot be
# clicked when there is no screen.
#
#   --fresh     discard the disk image and start from nothing
#   --gui       open a QEMU window instead (for driving it by hand)
#   --installed boot what was installed, not the ISO — this is how stages 3
#               and 4 get tested at all. Without it QEMU's -kernel wins over
#               the firmware and every reboot lands back on the ISO.
#
# Inside the VM, the thing under test is one line:
#   curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s qemu

set -euo pipefail

ISO="${PHOINIX_ISO:-/mnt/Downloads/archlinux-x86_64.iso}"
WORK="${PHOINIX_QEMU_DIR:-$HOME/.cache/phoinix-qemu}"
DISK_SERIAL="phoinix-test"     # must match DISK in hosts/qemu/config.sh
DISK_SIZE="${PHOINIX_QEMU_DISK:-30G}"
RAM="${PHOINIX_QEMU_RAM:-4G}"

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

FRESH=0
GUI=0
INSTALLED=0
for arg in "$@"; do
    case "$arg" in
        --fresh)     FRESH=1 ;;
        --gui)       GUI=1 ;;
        --installed) INSTALLED=1 ;;
        *) echo "usage: qemu-test.sh [--fresh] [--gui] [--installed]"; exit 1 ;;
    esac
done
[[ "$FRESH" == 1 && "$INSTALLED" == 1 ]] && { echo "ERROR: --fresh wipes what --installed would boot"; exit 1; }

for f in "$ISO" "$OVMF_CODE" "$OVMF_VARS_SRC"; do
    [[ -r "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
done
command -v qemu-system-x86_64 >/dev/null || { echo "ERROR: qemu-system-x86_64 not installed"; exit 1; }

install -d "$WORK"
IMG="$WORK/disk.qcow2"
VARS="$WORK/OVMF_VARS.fd"

if [[ "$FRESH" == 1 ]]; then
    rm -f "$IMG" "$VARS"
fi
# A stale NVRAM carries boot entries pointing at an ESP that no longer exists —
# the exact failure that had to be cleaned by hand on the real install
# (docs/LOG.md 2026-07-30). Firmware variables belong to the disk image.
[[ -e "$VARS" ]] || cp "$OVMF_VARS_SRC" "$VARS"
[[ -e "$IMG" ]]  || qemu-img create -f qcow2 "$IMG" "$DISK_SIZE" >/dev/null

# The ISO's boot entry, read out of the ISO itself. Guessing archisosearchuuid
# would break on every new monthly image; this cannot go stale.
BOOTDIR="$WORK/isoboot"
install -d "$BOOTDIR"
if [[ ! -e "$BOOTDIR/vmlinuz-linux" ]]; then
    bsdtar -xf "$ISO" -C "$BOOTDIR" --strip-components 3 \
        arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img
fi
ISO_OPTIONS="$(bsdtar -xOf "$ISO" loader/entries/01-archiso-linux.conf \
    | awk '$1 == "options" { $1 = ""; sub(/^ /, ""); print; exit }')"
[[ -n "$ISO_OPTIONS" ]] || { echo "ERROR: no boot options found in $ISO"; exit 1; }

QEMU=(
    qemu-system-x86_64
    -enable-kvm -machine q35 -cpu host -m "$RAM" -smp 4
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$VARS"
    # The disk under test. virtio-blk with an explicit serial, because that
    # serial IS the by-id name stage 1 refuses to run without.
    -drive "if=none,id=target,format=qcow2,file=$IMG"
    -device "virtio-blk-pci,drive=target,serial=$DISK_SERIAL"
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
)

# The installed run gets neither the ISO nor -kernel: the firmware has to find
# systemd-boot on the ESP by itself, which is the thing worth testing. Its
# serial console comes from KERNEL_PARAMS in hosts/qemu/config.sh, i.e. from
# the boot entry stage 2 wrote — not from anything this script appends.
if [[ "$INSTALLED" != 1 ]]; then
    QEMU+=(
        -drive "if=none,id=iso,format=raw,readonly=on,file=$ISO"
        -device virtio-blk-pci,drive=iso
        -kernel "$BOOTDIR/vmlinuz-linux"
        -initrd "$BOOTDIR/initramfs-linux.img"
    )
    if [[ "$GUI" == 1 ]]; then
        QEMU+=(-append "$ISO_OPTIONS")
    else
        QEMU+=(-append "$ISO_OPTIONS console=ttyS0,115200")
    fi
fi
[[ "$GUI" == 1 ]] || QEMU+=(-nographic)

echo "phoinix qemu test"
echo "  iso:   $ISO"
echo "  disk:  $IMG ($DISK_SIZE)"
echo "  mode:  $([[ "$GUI" == 1 ]] && echo window || echo "serial console")"
echo
exec "${QEMU[@]}"
