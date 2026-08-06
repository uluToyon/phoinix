#!/usr/bin/env bash
# vpn-netns.sh — the tunnel in a network namespace of its own.
#
#   usage: vpn-netns.sh <host> up|down|status      (needs root)
#
# WHY THIS EXISTS. The nftables table gives one guarantee: a socket whose group
# is VPN_GROUP may only leave through the tunnel. That is a rule MATCHING a
# property. ulu asked for the stronger thing — not "the rule catches it" but
# "there is no way out" — and that is what a namespace is: inside it the only
# interface is the tunnel, so the ordinary line is not merely forbidden, it is
# absent. Nothing to match, nothing to get wrong.
#
# THE TRICK THAT MAKES IT WORK. A WireGuard interface remembers the namespace it
# was CREATED in for its own encrypted socket, and keeps it when moved. So it is
# created here in the root namespace — where the ordinary line lives, and where
# the encryption must go out — and then moved inside. Plaintext lives in the
# namespace, ciphertext leaves through the normal interface. That is also why
# this cannot be done by creating the interface inside: the tunnel would have no
# way to reach its own endpoint.
#
# The group and the nftables table stay. They are no longer the guarantee but
# the backstop: if qBittorrent is ever started outside the namespace, the old
# rule still applies rather than nothing at all.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: vpn-netns.sh <host> up|down|status}"
ACTION="${2:?usage: vpn-netns.sh <host> up|down|status}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

NS="$VPN_NETNS"
IF="$VPN_INTERFACE"
CONF="$VPN_CONFIG_DIR/active.conf"

die() { echo "ERROR: $1" >&2; exit 1; }

# One value out of the wg-quick config. Deliberately not `source`: that file is
# not shell, and it holds a private key — a stray backtick would be executed.
conf_get() { sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p" "$CONF" | head -1; }

case "$ACTION" in
up)
    [[ $EUID -eq 0 ]] || die "needs root"
    [[ -e "$CONF" ]] || die "$CONF does not exist — run scripts/vpn-switch.sh first"
    command -v wg >/dev/null || die "wireguard-tools is not installed"

    # An interface of this name in the ROOT namespace means NetworkManager still
    # holds the old tunnel. Refuse rather than fight over the name: two things
    # managing one interface is how a tunnel ends up half up.
    ip link show "$IF" &>/dev/null \
        && die "$IF exists in the root namespace — NetworkManager still has it. Deactivate that profile."

    ip netns list | grep -qw "$NS" || ip netns add "$NS"
    ip netns exec "$NS" ip link set lo up

    ip link add "$IF" type wireguard
    # `wg-quick strip` removes the keys wg-quick owns (Address, DNS, MTU) and
    # leaves what the kernel wants. Process substitution so the private key never
    # touches a temporary file.
    wg setconf "$IF" <(wg-quick strip "$CONF")
    ip link set "$IF" netns "$NS"

    addr="$(conf_get Address)"
    [[ -n "$addr" ]] || die "no Address in $CONF"
    IFS=',' read -ra addrs <<< "$addr"
    for a in "${addrs[@]}"; do
        ip -n "$NS" addr add "${a// /}" dev "$IF"
    done

    ip -n "$NS" link set mtu "${VPN_MTU:-1420}" dev "$IF"
    ip -n "$NS" link set "$IF" up
    ip -n "$NS" route add default dev "$IF"
    ip -n "$NS" -6 route add default dev "$IF" 2>/dev/null || true

    # Resolver INSIDE the namespace. `ip netns exec` bind-mounts everything in
    # /etc/netns/<ns>/ over its counterpart in /etc, so a process in here reads
    # this resolv.conf and no other. That is the whole DNS problem solved by
    # construction: the only resolver reachable from in here is the one at the
    # far end of the tunnel.
    install -d -m755 "/etc/netns/$NS"
    printf 'nameserver %s\n' "${VPN_DNS}" > "/etc/netns/$NS/resolv.conf"
    chmod 644 "/etc/netns/$NS/resolv.conf"

    echo "vpn-netns: $IF up inside namespace '$NS' ($(conf_get '# ' 2>/dev/null || basename "$(readlink -f "$CONF")"))"
    ;;

down)
    [[ $EUID -eq 0 ]] || die "needs root"
    # Deleting the namespace takes the interface with it — a wireguard device
    # does not survive its namespace.
    ip netns list | grep -qw "$NS" && ip netns del "$NS"
    echo "vpn-netns: namespace '$NS' removed"
    ;;

status)
    if ! ip netns list | grep -qw "$NS"; then
        echo "namespace '$NS': absent"
        exit 1
    fi
    echo "namespace '$NS':"
    ip -n "$NS" -brief addr show
    echo "routes:"
    ip -n "$NS" route show
    echo "config: $(basename "$(readlink -f "$CONF" 2>/dev/null || echo '?')")"
    ;;

*) die "unknown action '$ACTION' (up|down|status)" ;;
esac
