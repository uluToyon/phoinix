# Shared install configuration — machine-independent defaults.
# Machine-specific values (DISK, partition sizes, data disks) live in hosts/<host>/config.sh,
# which is sourced after this file and may override anything here.

HOSTNAME="archlinux"
USERNAME="ulutoyon"
TIMEZONE="Europe/Berlin"
KEYMAP="de"

# Interface language stays English; regional FORMATS are German (ulu sits in
# Germany but runs his system in English). Both locales must be generated —
# a format locale that locale-gen never built silently falls back to C.
LOCALE="en_US.UTF-8"          # LANG / LC_MESSAGES — the language of the UI
FORMAT_LOCALE="de_DE.UTF-8"   # dates, numbers, currency, paper size
LOCALES=("$LOCALE" "$FORMAT_LOCALE")

# Partition defaults (override per host if needed)
ESP_SIZE="1G"      # 1 GB, not 512 MB — multiple kernels + fallback initramfs outgrow it
ROOT_SIZE="200G"   # /home gets the rest of the disk

# Set to 1 to keep an existing home partition (the "hop back" path):
# partitioning is skipped entirely, only ESP and root are re-formatted.
REUSE_HOME=0
