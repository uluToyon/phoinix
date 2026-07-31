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
VPN_CONFIG_DIR=""         # WireGuard .conf files; empty = this host has no VPN

# --- ProtonVPN split tunnel (stages 2 and 3) -------------------------------
# Conventions rather than host facts, so they live here: every machine that
# runs this setup uses the same names, and the names are AUTHORED — none of
# them is read off a running system, which is what CLAUDE.md demands.
#
# The design in one paragraph: the tunnel deliberately does NOT become the
# default route, so everything except qBittorrent keeps using the normal line.
# qBittorrent is started with VPN_GROUP as its effective group, and an nftables
# rule drops every packet from that group that would leave through anything but
# VPN_INTERFACE. The guarantee is therefore the kernel's, not the
# application's — qBittorrent's own "bind to interface" setting is set as well,
# but only as the first of two lines, never as the promise.
VPN_INTERFACE="proton0"   # authored name; both Proton connections share it, so
                          # qBittorrent's binding survives switching countries
VPN_GROUP="vpnonly"       # group whose traffic may only leave via VPN_INTERFACE
VPN_GATEWAY="10.2.0.1"    # Proton's in-tunnel gateway: NAT-PMP peer and DNS

# Policy routing. Two marks and a table, because "bind the app to the
# interface" turned out not to be enough on either side:
#
#   VPN_MARK_APP  is stamped on the group's packets and selects VPN_ROUTE_TABLE,
#                 whose only route is a default via the tunnel. So qBittorrent
#                 is ROUTED into the tunnel rather than trusted to bind itself.
#   VPN_MARK_WG   is what WireGuard stamps on its OWN encapsulated packets
#                 (wireguard.fwmark). Those leave over the normal interface by
#                 necessity — they are the tunnel — and they inherit the group
#                 of whatever process caused them. Without an exception for
#                 this mark the drop rule strangles the tunnel it protects:
#                 measured on the live desktop, 7 packets dropped per attempt.
VPN_MARK_APP="0x51"       # = 81; deliberately the same number as the table
VPN_MARK_WG="0x52"        # = 82; only WireGuard itself ever sets this
VPN_ROUTE_TABLE=51
QBT_WEBUI_PORT=8080       # localhost only, auth bypassed for localhost — this is
                          # how the forwarded port reaches qBittorrent without a
                          # credential existing anywhere

# Set to 1 to keep an existing home partition (the "hop back" path):
# partitioning is skipped entirely, only ESP and root are re-formatted.
REUSE_HOME=0
