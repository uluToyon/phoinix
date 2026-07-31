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

# The desktop gives root 200G of a 1TB disk. The test only has to reach a
# booting system, so it runs on a small sparse image. ESP stays at the shared
# 1G — the reason for that size (multiple kernels + fallback initramfs) is
# exactly the kind of thing a test should not quietly deviate from.
ROOT_SIZE="12G"
