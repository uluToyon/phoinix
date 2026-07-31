# QEMU test target — the throwaway machine DESIGN.md's testing loop runs on.
#
# Not a real host. It exists so the installer can be run end to end without
# wiping anything, which is the only way to find out whether the stages still
# chain together. scripts/qemu-test.sh builds exactly the VM described here.

# DECLARED, not discovered — the distinction matters here. On the desktop this
# path is a fact about the hardware; here scripts/qemu-test.sh passes this very
# serial to QEMU (-device virtio-blk-pci,serial=...) and udev builds the by-id
# link from it. So the guard that protects the desktop (a by-id path that does
# not resolve on the wrong machine) is live in the VM too, pointed at a virtual
# disk — which is the point: the test exercises the real guard, not a bypass.
DISK="/dev/disk/by-id/virtio-phoinix-test"

# No data disks in the VM. Stage 1 mounts every label in this list so genfstab
# records it, and would abort on the first one that is absent — correct on real
# hardware, simply not applicable here.
DATA_LABELS=()

# Obvious in the VM's prompt that this is not the real machine.
HOSTNAME="phoinix-test"

# The installed system has no screen — everything after the reboot is only
# observable on the serial line, so the boot entry has to say so. On the
# desktop this variable carries that machine's monitor caps instead; the point
# is that it is per-host at all, which stage 2 did not use to allow.
KERNEL_PARAMS="console=ttyS0,115200"

# The desktop gives root 200G of a 1TB disk. 12G was the first guess here, on
# the assumption that the test only had to reach a booting system — stage 3 ran
# for half an hour and then died on "not enough free disk space" partway through
# the AUR builds. A test host has to be sized for the REAL package set or it
# tests the installer only up to the point where it runs out of room.
# The image is sparse, so this costs nothing until it is used.
# ESP stays at the shared 1G — the reason for that size (multiple kernels +
# fallback initramfs) is exactly what a test should not quietly deviate from.
ROOT_SIZE="60G"
