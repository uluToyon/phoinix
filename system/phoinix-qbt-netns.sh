#!/usr/bin/env bash
# Template — stage 3 installs this as /usr/local/sbin/phoinix-qbt-netns,
# root-owned and 0755, with @USERNAME@, @VPN_GROUP@, @VPN_NETNS@ and
# @VPN_INTERFACE@ substituted.
#
# The only thing on this machine that may be run through sudo without a
# password, and it is deliberately the smallest possible thing: enter the
# namespace, drop straight back to ulu, exec qBittorrent. It takes no decisions
# and reads no configuration, so there is nothing in it to be talked into.
#
# Root is needed for exactly one syscall's worth of work — setns(2). Everything
# after `setpriv` runs as ulu again, which is why the arguments this receives
# (torrent paths from %U) cannot buy anything: they reach a process that has no
# more privilege than the one that asked.
#
# setpriv rather than runuser or su: it changes credentials and NOTHING else. No
# PAM session, no shell, no environment rewriting — the display and bus
# variables sudo was allowed to pass through arrive untouched, which is what a
# GUI needs. HOME and friends are set here because sudo points them at root.
set -euo pipefail

NS="@VPN_NETNS@"
USER_NAME="@USERNAME@"
GROUP_NAME="@VPN_GROUP@"

# Refuse rather than fall back. Without the namespace this would start an
# ordinary qBittorrent as root's child on the open line — the exact outcome the
# whole construction exists to prevent, and it would look like a normal start.
ip netns list | grep -qw "$NS" || {
    echo "ERROR: network namespace '$NS' does not exist." >&2
    echo "       Start it with: systemctl start phoinix-vpn-netns" >&2
    exit 1
}
ip -n "$NS" link show "@VPN_INTERFACE@" &>/dev/null || {
    echo "ERROR: '@VPN_INTERFACE@' is not inside namespace '$NS' — the tunnel is down." >&2
    exit 1
}

HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"

exec ip netns exec "$NS" \
    env HOME="$HOME_DIR" USER="$USER_NAME" LOGNAME="$USER_NAME" \
    setpriv --reuid "$USER_NAME" --regid "$GROUP_NAME" --init-groups \
    /usr/bin/qbittorrent "$@"
