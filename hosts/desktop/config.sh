# Desktop: Ryzen 7 7800X3D, 30 GB RAM, Radeon RX 7900 XT, UEFI.
# Target disk by stable ID — never /dev/nvme1n1, enumeration order drifts across boots.
DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NX0T343303X"

# Data disks, mounted by filesystem label under /mnt/<label>.
# These are NEVER formatted by any stage script — they only get fstab entries.
DATA_LABELS=(Games Video Downloads FilesMusic)

# --- Monitors (stage 4 / Plasma panels) ------------------------------------
# Connector names, not Plasma screen numbers: Plasma numbers screens in
# detection order, which is not stable across boots. Stage 4 resolves each
# connector to its geometry at runtime and hands that to the panel script.
PANEL_MAIN_CONNECTOR="DP-1"        # ultrawide 3440x1440 — full panel lives here
PANEL_TV_CONNECTOR="HDMI-A-1"      # television — gets a clone of the main panel
PANEL_MAIN_HEIGHT=46

# Clock-only strips on the remaining monitors: "<connector>:<thickness>".
PANEL_SIDE=("DP-2:55" "DP-3:36")   # TCL 27" 4K, portrait 1440x2560
