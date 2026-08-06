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

# --- Commit identity for the user's copy of this repo ----------------------
# Set REPO-LOCALLY by stage 3, never globally. This is the whole defence
# against ulu's real name reaching GitHub, and it has failed twice: once
# through a global git identity (35 commits, docs/LOG.md 2026-07-31) and once
# through GIT_AUTHOR_* exported by a shell profile.
#
# It lives here rather than in hosts/<host>/config.sh because it belongs to the
# person, not the machine — and it lives in the repo at all because it was NOT
# reproducible before: bootstrap clones fresh, `.git/config` is not versioned,
# so the identity was set by hand on the old install and simply gone after the
# reinstall. `git var GIT_AUTHOR_IDENT` said "Author identity unknown"
# (found 2026-07-31, session 7, while committing).
#
# The address is not a secret. It is the GitHub noreply address that already
# appears in every commit of this public repo — it is the substitute for a
# secret, not one.
GIT_IDENTITY_NAME="uluToyon"
GIT_IDENTITY_EMAIL="47314345+uluToyon@users.noreply.github.com"

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
QBT_CONNECTOR=""          # qBittorrent window rule; empty = no rule for it
QBT_OFFSET="0,0"          # offset from that connector's origin
QBT_SIZE=""
DISCORD_CONNECTOR=""      # Discord window rule; empty = no rule for it
DISCORD_OFFSET="0,0"
DISCORD_SIZE=""
PRINTER_NAME=""            # queue name; empty = this host has no printer
PRINTER_MATCH=""
PRINTER_DRIVER=""
PRINTER_OPTIONS=()
DZGUI_PRIVATE_FILE=""      # DZGUI secrets/server list on a data disk; empty = no DZGUI
DZGUI_NAME=""
STEAM_SHORTCUTS_FILE=""   # backup of Steam's non-Steam game list; empty = none
MIRROR_COUNTRY="Germany"  # reflector filter in stage 1; both machines live here
XIVLAUNCHER_DESKTOP=""     # .desktop to link onto the desktop; empty = none
DESKTOP_ICONS=()          # "<basename>.desktop:col,row" per icon; empty = place none
MONITOR_SWITCH=()         # "model:desktop_value:laptop_value"; empty = no switching
MONITOR_SWITCH_REF=""     # which model is asked which side is live
XLCORE_BACKUP_DIR=""       # XIVLauncher/Dalamud backup on a data disk; empty = none
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

# The resolver INSIDE the tunnel, and the reason a nat chain exists at all.
# Until 2026-08-06 the group's traffic went through the tunnel but its NAME
# LOOKUPS did not: qBittorrent asks the systemd-resolved stub on 127.0.0.53,
# which the loopback rule lets through, and resolved — not being in the group —
# then asks Quad9 over the ordinary line. The packets were protected the whole
# time; the names were not, so the resolver saw every tracker.
#
# There is no per-process resolver in glibc, so this is fixed one layer down:
# nftables rewrites the destination of the group's DNS to this address, the
# packet is marked like everything else from the group, and it leaves through
# the tunnel. Verified 2026-08-06 that Proton answers here.
#
# 10.2.0.1 is the peer address of Proton's WireGuard tunnel (the interface
# itself is 10.2.0.2/32) and is the DNS their configs name for every server.
# It is unreachable outside the tunnel, which makes this fail CLOSED: with the
# tunnel down nothing resolves, rather than resolving over the wrong line.
VPN_DNS="10.2.0.1"

# Where the group's lookups are sent instead of the systemd-resolved stub, and
# why there is a forwarder at all rather than a rule pointing straight at
# VPN_DNS. The straight version was built on 2026-08-06 and does not work: a
# query addressed to 127.0.0.53 has already been given 127.0.0.1 as its SOURCE
# before any rule runs, and the kernel will not route a loopback sender out of a
# real interface. Correcting the source in postrouting is too late — the routing
# decision has happened by then. Netfilter cannot change a source address before
# routing, so no arrangement of rules fixes it.
#
# Rewriting one loopback address to another does work: the packet never leaves
# the machine, so nothing is rerouted and nothing is martian. dnsmasq listens
# here, runs with VPN_GROUP as its group, and asks VPN_DNS — and ITS packets get
# a proper source, are marked like everything else from the group, and go
# through the tunnel.
#
# 127.0.0.54 is deliberately NOT used: systemd-resolved already listens there
# (its bypass stub), which cost a rebuild to notice.
VPN_DNS_STUB="127.0.0.61"

# The namespace was built on 2026-08-06 and removed the same day, on ulu's call.
# It did work — qBittorrent ran inside it with the tunnel as its only interface,
# verified by `ip netns identify`, a differing namespace inode and an established
# connection from the tunnel address. What it cost was everything NetworkManager
# gives for free: the tray icon that says whether the tunnel is up, the click
# that toggles it, the click that changes country, and `proton0` being visible
# to ordinary network tools at all. That price was not in the estimate when it
# was proposed, which is the actual mistake — the trade was "the last 0.1 % of
# the guarantee against all of the operability", and it was ulu's to make.
#
# The full construction is written up in docs/LOG.md 2026-08-06 and can be
# rebuilt from there if the bar ever moves back.


# --- DNS (stage 3) ---------------------------------------------------------
# Who resolves ulu's names, and the reason it is a decision rather than a
# default. The tunnel carries qBittorrent's packets but NOT its lookups (see
# stage 3, section 7b), so whatever stands here also sees every tracker name —
# from the home address, in the clear, unless it is encrypted.
#
# Quad9, chosen by ulu 2026-08-01 over Cloudflare and dns0.eu: a foundation
# rather than a corporation, no client-IP logging by its own policy, and a
# malware/phishing filter thrown in. The filter is the one risk worth naming,
# because this resolver now also answers for torrent trackers — a false block
# would look exactly like a broken tracker. `9.9.9.10` / `dns10.quad9.net` is
# the same service unfiltered, i.e. the fix is a value here, not a rebuild.
#
# Empty DNS_TLS_NAME switches the whole section off and leaves DNS to
# NetworkManager. The name is not decoration: it is the TLS certificate this
# resolver must present, and it is what makes "encrypted" mean "encrypted to
# the intended server" rather than to whoever answers on that address.
DNS_SERVERS_V4=("9.9.9.9" "149.112.112.112")
DNS_SERVERS_V6=("2620:fe::fe" "2620:fe::9")
DNS_TLS_NAME="dns.quad9.net"

# Set to 1 to keep an existing home partition (the "hop back" path):
# partitioning is skipped entirely, only ESP and root are re-formatted.
REUSE_HOME=0
