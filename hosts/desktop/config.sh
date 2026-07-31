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

# --- Dolphin Places sidebar (stage 4) --------------------------------------
# Order of the DEVICE entries in the Places panel, by filesystem LABEL.
# Labels, not device nodes and not UUIDs: KDE stores this ordering with both
# (`/org/freedesktop/UDisks2/block_devices/sda1` plus the filesystem uuid), and
# both are unusable here — device nodes are assigned in probe order, and the
# root/home UUIDs are created fresh by every install. Stage 4 resolves each
# label at runtime. Root and home carry the labels stage 1 gives them.
# A label that is not present is skipped, so an unplugged disk costs its entry
# and nothing else. Removable media (e.g. the install stick) is deliberately
# absent — it has no business in a reproducible layout.
PLACES_ORDER=(archroot archhome Games FilesMusic Downloads Video)

# --- Window rules (stage 4) ------------------------------------------------
# Sizes are the application's own business, but a POSITION is a coordinate in
# the current monitor layout — write 7280,0 into the repo and it silently
# points somewhere else the day a screen is rearranged. So a position is given
# as a connector name and resolved to that monitor's origin at runtime.
KONSOLE_CONNECTOR="DP-3"      # portrait monitor — Konsole opens at its origin
KONSOLE_SIZE="1440,1262"      # its full width, about half its height
STRAWBERRY_CONNECTOR="DP-2"   # TCL 4K — Strawberry opens at its origin
STRAWBERRY_SIZE="1920,2105"   # its left half, nearly full height
DOLPHIN_SIZE="1295,839"       # size only, no position

# --- Strawberry playlist (stage 4) -----------------------------------------
# ulu's curated playlist lives WITH the music, on a data disk this repo never
# touches — so it survives a reinstall by construction and has no business
# being in the repo. Saved with RELATIVE paths, which makes it independent of
# where the disk is mounted (the mount paths already changed once).
# Strawberry keeps playlists in its database, i.e. in state that a reinstall
# loses; this re-imports the file into a fresh database.
PLAYLIST_FILE="/mnt/FilesMusic/Musik/Default.m3u"
PLAYLIST_NAME="Default"
