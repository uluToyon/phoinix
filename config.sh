# Shared install configuration — machine-independent defaults.
# Machine-specific values (DISK, partition sizes, data disks) live in hosts/<host>/config.sh,
# which is sourced after this file and may override anything here.

HOSTNAME="archlinux"
USERNAME="ulutoyon"
TIMEZONE="Europe/Berlin"
KEYMAP="de"

# X11/Wayland layout variant. Kept separate from KEYMAP on purpose: KEYMAP is
# also the vconsole keymap, where the no-dead-keys variant is a different
# keymap NAME (de-latin1-nodeadkeys), not a variant — folding them into one
# value would produce an invalid XkbLayout. Empty means "no variant".
KEYMAP_VARIANT="nodeadkeys"

# Interface language stays English; regional FORMATS are German (ulu sits in
# Germany but runs his system in English). Both locales must be generated —
# a format locale that locale-gen never built silently falls back to C.
LOCALE="en_US.UTF-8"          # LANG / LC_MESSAGES — the language of the UI
FORMAT_LOCALE="de_DE.UTF-8"   # dates, numbers, currency, paper size
LOCALES=("$LOCALE" "$FORMAT_LOCALE")

# Partition defaults (override per host if needed)
ESP_SIZE="1G"      # 1 GB, not 512 MB — multiple kernels + fallback initramfs outgrow it
ROOT_SIZE="200G"   # /home gets the rest of the disk

# --- Optional per-host declarations ----------------------------------------
# Defaulted here so a host may simply omit what it does not have. Sourced
# BEFORE hosts/<host>/config.sh, so any host that HAS these overrides them.
# Empty is a real answer, not an oversight: a machine with one screen has no
# TV clone and no side strips, and a machine whose disks phoinix does not
# manage has no Places ordering. Stage 4 treats an undeclared screen exactly
# like an unplugged one, so absence needs no second code path.
# These are defaults precisely BECAUSE `set -u` turns an omission into
# "unbound variable" from the middle of a pipeline — true and unusable.
KERNEL_PARAMS=""          # extra kernel command line for the boot entry
PANEL_TV_CONNECTOR=""     # second screen that mirrors the main panel
PANEL_SIDE=()             # clock-only strips: "<connector>:<thickness>"
PLACES_ORDER=()           # Dolphin Places device order, by filesystem label

# Set to 1 to keep an existing home partition (the "hop back" path):
# partitioning is skipped entirely, only ESP and root are re-formatted.
REUSE_HOME=0
