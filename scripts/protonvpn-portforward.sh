#!/usr/bin/env bash
# protonvpn-portforward.sh — hold Proton's forwarded port and keep qBittorrent
# pointed at it.
#
#   usage: protonvpn-portforward.sh <host>
#
# Proton does not hand out a permanent port. A P2P server with NAT-PMP enabled
# (the "NAT-PMP (Port Forwarding) = on" line in the WireGuard config) grants a
# mapping on request, with a **60 second lease**. Stop renewing and the port is
# gone; reconnect and it is a different one. So this is not a setup step that
# runs once — it is a service that has to keep running for as long as the port
# is supposed to exist. Proton's own documentation renews every 45 seconds and
# that is what this does.
#
# The port then has to reach qBittorrent, which does not re-read its config
# file while running. Its WebUI API does the job, bound to localhost with
# authentication bypassed for localhost — so no credential exists anywhere,
# which is the whole reason that option is used. See docs/LOG.md 2026-07-31.
#
# Values come from config.sh: VPN_GATEWAY, VPN_INTERFACE, QBT_WEBUI_PORT.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: protonvpn-portforward.sh <host>   (e.g. desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

command -v natpmpc >/dev/null || { echo "ERROR: natpmpc missing (packages/apps.txt: libnatpmp)"; exit 1; }
command -v curl    >/dev/null || { echo "ERROR: curl missing"; exit 1; }

RENEW_INTERVAL=45          # lease is 60s; renewing at 45 leaves room for one miss
LEASE=60
API="http://127.0.0.1:${QBT_WEBUI_PORT}/api/v2/app/setPreferences"

last_port=""

# One mapping request. Prints the granted public port, or nothing on failure.
# `-a <private> <public> <proto> <lifetime>`: public 0 means "whatever you have".
request_port() {
    natpmpc -a 1 0 "$1" "$LEASE" -g "$VPN_GATEWAY" 2>/dev/null |
        awk '/Mapped public port/ { print $4; exit }'
}

echo "=== portforward start: gateway $VPN_GATEWAY, interface $VPN_INTERFACE ==="

while true; do
    # No tunnel, no point asking — and saying so beats a wall of natpmpc errors.
    if [[ ! -d "/sys/class/net/$VPN_INTERFACE" ]]; then
        echo "waiting: $VPN_INTERFACE is not up"
        last_port=""          # forget it, the next tunnel gets a different port
        sleep "$RENEW_INTERVAL"
        continue
    fi

    # BOTH protocols, and udp first, exactly as Proton documents it. They return
    # the same port; asking for only one leaves the other unmapped.
    udp_port="$(request_port udp || true)"
    tcp_port="$(request_port tcp || true)"

    if [[ -z "$udp_port" || -z "$tcp_port" ]]; then
        echo "WARNING: no mapping granted (server not P2P, or NAT-PMP off in this config)"
        sleep "$RENEW_INTERVAL"
        continue
    fi
    if [[ "$udp_port" != "$tcp_port" ]]; then
        echo "WARNING: udp $udp_port != tcp $tcp_port — using $tcp_port"
    fi

    # Renewals return the same port, so only talk to qBittorrent when it
    # actually changed. Otherwise this would rewrite its preferences every 45
    # seconds forever, for nothing.
    if [[ "$tcp_port" != "$last_port" ]]; then
        if curl -fsS --max-time 10 -d "json={\"listen_port\":$tcp_port}" "$API" >/dev/null; then
            echo "port $tcp_port -> qBittorrent"
            last_port="$tcp_port"
        else
            # Do NOT record the port in this case: qBittorrent may just be
            # starting, and the next round has to try again rather than believe
            # it is already set.
            echo "WARNING: qBittorrent WebUI not reachable on port $QBT_WEBUI_PORT — will retry"
        fi
    fi

    sleep "$RENEW_INTERVAL"
done
