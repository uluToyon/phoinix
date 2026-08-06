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

# --- entering the group ----------------------------------------------------
# This used to be `sg "$VPN_GROUP" -c …`, and `sg` is GONE from Arch: shadow no
# longer ships it and util-linux, which took `newgrp` over, never did. The line
# had worked for months and failed the first time it ran on a fresh install —
# "exec: sg: not found". It failed CLOSED, which is the only reason this was an
# annoyance rather than an incident, and the reason the guards above are worth
# their lines.
#
# `newgrp` is the replacement: setuid root, part of util-linux, present on any
# system that can log a user in. Unlike `sg` it takes no command argument — it
# execs the login shell — so the command reaches it on stdin.
#
# What deliberately does NOT cross that boundary are the file arguments the
# desktop entry passes through (%U). They would have to be quoted for whatever
# the login shell happens to be (zsh here, not sh), and a torrent path
# containing a quote is precisely how such a string turns into two arguments or
# into an executed command. They travel in the ENVIRONMENT instead — measured
# to survive `newgrp` byte for byte — NUL-separated and base64'd, so nothing in
# them can be special. Only this script's own path and the host name are
# interpolated into the shell line, and both are %q-quoted.
VPN_GID="$(getent group "$VPN_GROUP" | cut -d: -f3)"

if [[ -z "${PHOINIX_QBT_INNER:-}" ]]; then
    command -v newgrp >/dev/null \
        || die "newgrp is missing — no way to enter group '$VPN_GROUP'."
    if (($#)); then
        PHOINIX_QBT_ARGV="$(printf '%s\0' "$@" | base64 -w0)"
    else
        PHOINIX_QBT_ARGV=""
    fi
    export PHOINIX_QBT_ARGV PHOINIX_QBT_INNER=1
    exec newgrp "$VPN_GROUP" <<< "exec $(printf '%q' "$0") $(printf '%q' "$HOST")"
fi

# --- inside the group ------------------------------------------------------
# VERIFY the switch instead of trusting it. Everything above this line is a
# check that the machinery is *present*; this is the only one that establishes
# it actually WORKED, and it is the one that matters. A half-working switch is
# the fail-OPEN case — qBittorrent running, looking configured, and talking to
# the internet directly past a rule that matches nothing.
[[ "$(id -g)" == "$VPN_GID" ]] \
    || die "effective group is $(id -gn), not '$VPN_GROUP' — the switch did not take."

argv=()
if [[ -n "${PHOINIX_QBT_ARGV:-}" ]]; then
    while IFS= read -r -d '' a; do argv+=("$a"); done \
        < <(printf '%s' "$PHOINIX_QBT_ARGV" | base64 -d)
fi

# ABSOLUTE path, and that is not style. Since 2026-08-06 a wrapper named
# `qbittorrent` sits in ~/.local/bin, ahead of /usr/bin in PATH, so that typing
# the name in a terminal cannot start an unprotected client. Resolving by name
# here would find that wrapper and call this script again, forever.
exec /usr/bin/qbittorrent "${argv[@]}"
