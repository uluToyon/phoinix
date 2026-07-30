# Shared install configuration — machine-independent defaults.
# Machine-specific values (DISK, partition sizes, data disks) live in hosts/<host>/config.sh,
# which is sourced after this file and may override anything here.

HOSTNAME="archlinux"
USERNAME="ulutoyon"
TIMEZONE="Europe/Berlin"
LOCALE="en_US.UTF-8"
KEYMAP="de"

# Partition defaults (override per host if needed)
ESP_SIZE="1G"      # 1 GB, not 512 MB — multiple kernels + fallback initramfs outgrow it
ROOT_SIZE="200G"   # /home gets the rest of the disk

# Set to 1 to keep an existing home partition (the "hop back" path):
# partitioning is skipped entirely, only ESP and root are re-formatted.
REUSE_HOME=0
