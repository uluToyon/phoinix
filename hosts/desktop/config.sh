# Desktop: Ryzen 7 7800X3D, 30 GB RAM, Radeon RX 7900 XT, UEFI.
# Target disk by stable ID — never /dev/nvme1n1, enumeration order drifts across boots.
DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NX0T343303X"

# --- Kernel parameters (stage 2, boot entry) -------------------------------
# Two refresh-rate caps, same mechanism, two different reasons:
#   DP-2 @144 — monitor-bug fix: the TCL 27" 4K must never init at native
#     180Hz (DP bandwidth/DSC → black screen with all 4 displays).
#     See docs/LOG.md 2026-07-30.
#   DP-1 @144 — the ultrawide's link runs 4 lanes at HBR3 with no DSC and no
#     FEC; at 170Hz it sits at ~82% utilisation, where a single bit error costs
#     a retrain (= the sporadic black flash). See docs/LOG.md 2026-07-31.
#     PROVISIONAL: a running experiment, not a settled decision.
# These are caps for THIS machine's monitors — which is why they belong here
# and not in stage 2, where every other host used to inherit them.
KERNEL_PARAMS="video=DP-2:3840x2160@144 video=DP-1:3440x1440@144"

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

# --- KeePassXC (stage 3) ---------------------------------------------------
# The password database lives on a data disk and survives reinstalls on its
# own; phoinix only needs to point KeePassXC at it. The database itself is
# never touched, copied or backed up by anything in this repo.
KEEPASS_DB="/mnt/FilesMusic/KeePassXC/Passwords.kdbx"

# --- Captured configs (stage 3) --------------------------------------------
# This host has hosts/desktop/home/ in the repo: the monitor fix
# (kwinoutputconfig.json), kwinrc, kdeglobals, the PipeWire clock drop-in and
# the wireplumber state carrying the soundbar's attenuation. Declared rather
# than detected — stage 3 hard-fails if this says 1 and the files are gone,
# because a silent skip here means a black first login.
CAPTURED_CONFIGS=1

# --- ProtonVPN split tunnel (stage 3) --------------------------------------
# The WireGuard configs live WITH the data, on a disk phoinix never touches, so
# they survive a reinstall by construction — the same anchor pattern as the
# Strawberry playlist. They must never enter the repo: each file carries a
# PrivateKey, and for Proton that key IS the credential (no user/password).
# Two are present, CH and NL, both generated with "NAT-PMP (Port Forwarding)
# = on" and "Moderate NAT = off" — Proton allows only one of those two at a
# time, and port forwarding is the one qBittorrent needs.
# Only the PATH is versioned. Every .conf in here is imported.
VPN_CONFIG_DIR="/mnt/FilesMusic/VPN"

# --- qBittorrent paths (stage 3) -------------------------------------------
# On a data disk, not in ~/Downloads: the system disk is what a reinstall
# wipes, and half-finished torrents have no business living there. TempPath
# keeps incomplete files apart from finished ones, on the same disk so the
# move at completion is a rename rather than a copy.
QBT_SAVE_PATH="/mnt/Downloads/Torrents"
QBT_TEMP_PATH="/mnt/Downloads/Temp"

# --- qBittorrent window (stage 4) ------------------------------------------
# Shares DP-2 with Strawberry: Strawberry takes the left half at the origin,
# qBittorrent the right. Hence an OFFSET rather than a bare connector — the
# offset survives a rearranged desktop, the absolute 1920,804 the GUI produced
# would not.
QBT_CONNECTOR="DP-2"
QBT_OFFSET="1920,0"    # half of DP-2's 3840 width
QBT_SIZE="1920,1053"

# --- Discord window (stage 4) ----------------------------------------------
# Shares the portrait monitor with Konsole: Konsole takes the top half at the
# origin, Discord the bottom. Hence an offset, like qBittorrent on DP-2.
DISCORD_CONNECTOR="DP-3"
DISCORD_OFFSET="0,1262"   # directly below Konsole, which is 1262 high
DISCORD_SIZE="1440,1262"

# --- Printer (stage 3) ------------------------------------------------------
# Samsung SCX-4300, USB, print only — the device is a multifunction unit but no
# scanning stack is installed (see packages/apps.txt).
#
# The DEVICE uri is deliberately NOT here: CUPS builds it as
# usb://Samsung/SCX-4300%20Series?serial=<serial>&interface=1, i.e. it carries
# the printer's serial number. Stage 3 resolves it at runtime with `lpinfo -v`,
# the same way monitors, disks and mice are resolved. What IS stored is the
# driver, which comes from the splix package and is identical on every machine.
PRINTER_NAME="SCX-4300"
PRINTER_MATCH="SCX-4300"                                  # what to look for in `lpinfo -v`
PRINTER_DRIVER="drv:///splix-samsung.drv/scx4300.ppd"     # splix, "Samsung SCX-4300, 2.0.0"
PRINTER_OPTIONS=("PageSize=A4" "printer-is-shared=false")  # Letter is the driver default; sharing is not wanted

# --- DZGUI (stage 3) --------------------------------------------------------
# The DayZ launcher's config holds a Steam Web API key — a hard secret — and
# ulu's server list, which says where he plays. Neither belongs in a public
# repo, and both must survive a reinstall. So they live on a data disk phoinix
# never touches, and only the PATH is versioned: the same anchor pattern as the
# WireGuard configs and the Strawberry playlist.
#
# The file holds exactly {"steam_api": "...", "ip_list": [...]}, mode 0600.
# Everything else in DZGUI's config is plain settings and is authored below.
DZGUI_PRIVATE_FILE="/mnt/FilesMusic/DZGUI/dzgui-private.json"
DZGUI_NAME="uluToyon"        # in-game name; ulu's public handle anyway

# --- Steam non-Steam shortcuts (stage 3) ------------------------------------
# Steam's list of non-Steam games (currently: DZGUI). Kept on the games disk
# rather than in the repo — not because it holds secrets (it holds a name and
# two paths) but because it lives under userdata/<steam-account-id>/, i.e. in a
# directory that only exists after a Steam login, and because it grows as ulu
# adds entries. Backing it up means a reinstall restores whatever is in it,
# not just the one shortcut that existed the day it was scripted.
STEAM_SHORTCUTS_FILE="/mnt/Games/phoinix/shortcuts.vdf"

# --- Desktop icon (stages 3 and 4) ------------------------------------------
# The one icon ulu keeps on an otherwise empty desktop. Steam's was deleted;
# this one is deliberate, so it is scripted — link in stage 3, position in
# stage 4. The position is stored per SCREEN RESOLUTION by Plasma, which is
# resolved from PANEL_MAIN_CONNECTOR at runtime rather than written here.
XIVLAUNCHER_DESKTOP="/usr/share/applications/XIVLauncher-RB.desktop"
DESKTOP_ICON_CELL="1,1"    # column,row in the Folder View grid

# --- XIVLauncher / Dalamud (stage 3) ----------------------------------------
# Next to the game on the games disk, where it belongs thematically and where
# it survives by construction. Holds ~80 MB: launcher settings, the Dalamud
# plugin profile with its third-party repo list, per-plugin settings, and the
# plugin binaries. Everything else in ~/.xlcore (2.6 GB of Proton prefix,
# Dalamud, runtime, assets, Browsingway's browser) re-downloads itself.
#
# accounts.json in there is a credential (account name, last OTP) and is kept
# at 0600. Only the PATH is versioned — never the contents.
XLCORE_BACKUP_DIR="/mnt/Games/FFXIV/xlcore-backup"
