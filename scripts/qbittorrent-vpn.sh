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
# A group switch rather than a dedicated user: qBittorrent is a GUI application
# in ulu's session, and a second user would drag in a second home directory,
# permissions on the download folder and Wayland socket access — a lot of
# machinery to express one bit. ulu is a member of the group (stage 2), so the
# switch needs no password.
#
# Fails CLOSED on purpose: if anything it depends on is missing, this refuses to
# start rather than launching an unprotected qBittorrent. A torrent client that
# quietly runs outside the tunnel is the exact outcome this whole setup exists
# to prevent, and "it started, so it must be fine" is how that would happen.
#
# REWRITTEN 2026-08-06. It used to enter VPN_GROUP with newgrp and start
# qBittorrent there, relying on the nftables rule to catch anything that tried
# to leave elsewhere. That is a rule matching a property. ulu asked for the
# stronger form, so the client now runs inside a network namespace whose only
# interface is the tunnel — the ordinary line is not forbidden in there, it does
# not exist. The group and the rule stay: the helper still sets VPN_GROUP as the
# effective group, so if qBittorrent ever runs outside the namespace the old
# guarantee applies instead of none.

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
systemctl is-active --quiet "$VPN_NETNS_UNIT" \
    || die "$VPN_NETNS_UNIT is not active — the tunnel namespace does not exist."
ip netns list 2>/dev/null | grep -qw "$VPN_NETNS" \
    || die "network namespace '$VPN_NETNS' is missing, even though its unit claims to be up."

# --- into the namespace ----------------------------------------------------
# Entering a namespace needs root, so this hands over to a helper that is
# allowed through sudo without a password — the smallest possible thing: setns,
# drop back to ulu, exec. See system/phoinix-qbt-netns.sh.
#
# The newgrp machinery that used to live here is gone with it, and so is the
# base64 argument smuggling it needed: sudo passes arguments as arguments, so a
# torrent path containing a quote is just a path again.
# `sudo -l` asks whether the rule exists, without running anything. Probing by
# actually invoking the helper would start a qBittorrent just to check that a
# qBittorrent can be started.
sudo -n -l /usr/local/sbin/phoinix-qbt-netns >/dev/null 2>&1 \
    || die "sudo will not run the namespace helper without a password — is /etc/sudoers.d/phoinix-vpn installed?"

exec sudo -n /usr/local/sbin/phoinix-qbt-netns "$@"
