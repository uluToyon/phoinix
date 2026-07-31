#!/usr/bin/env bash
# qbittorrent-vpn.sh — start qBittorrent inside the group the kernel rule binds to.
#
#   usage: qbittorrent-vpn.sh <host> [files…]
#
# This is the piece that makes the guarantee real. The nftables rule drops any
# packet from the VPN_GROUP group that would leave through anything but the
# tunnel — but a rule about a group does nothing until something actually runs
# in that group. Started from the normal launcher, qBittorrent would carry ulu's
# ordinary groups and the rule would never match it.
#
# `sg` rather than a dedicated user: qBittorrent is a GUI application in ulu's
# session, and a second user would drag in a second home directory, permissions
# on the download folder and Wayland socket access — a lot of machinery to
# express one bit. ulu is a member of the group (stage 2), so `sg` switches
# without asking for a password.
#
# Fails CLOSED on purpose: if the group is missing, this refuses to start
# rather than launching an unprotected qBittorrent. A torrent client that
# quietly runs outside the tunnel is the exact outcome this whole setup exists
# to prevent, and "it started, so it must be fine" is how that would happen.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: qbittorrent-vpn.sh <host> [files…]}"
shift

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

die() { echo "ERROR: $1"; echo "       Refusing to start qBittorrent unprotected."; exit 1; }

# Two checks, and the second one is the non-obvious half. Running in the group
# is worth nothing if the rule that watches the group is not loaded — that
# combination fails OPEN: qBittorrent starts, looks configured, and talks to
# the internet directly. Found while testing: `nft` resolves the group name at
# parse time, so a missing group makes the WHOLE ruleset fail to load, which is
# exactly how that state comes about.
# The ruleset itself cannot be read without CAP_NET_ADMIN, so the unit's state
# is the best proxy available to a normal user — and it is the thing that would
# actually be wrong.
getent group "$VPN_GROUP" >/dev/null \
    || die "group '$VPN_GROUP' does not exist — re-run stage 2."
systemctl is-active --quiet nftables.service \
    || die "nftables.service is not active, so nothing enforces the tunnel."

# `sg` hands its argument to a shell, so the file arguments the desktop entry
# passes through (%U) have to be quoted for that shell — otherwise a torrent
# file with a space in its name would arrive as two arguments, or worse.
cmd="qbittorrent"
for arg in "$@"; do
    cmd+=" $(printf '%q' "$arg")"
done

exec sg "$VPN_GROUP" -c "$cmd"
