#!/usr/bin/env bash
# vpn-switch.sh — choose which Proton server the namespace tunnel uses.
#
#   usage: vpn-switch.sh <host> [ch|nl|<name>]      (no argument = show)
#
# Replaces the NetworkManager applet, which cannot follow the tunnel into a
# namespace. One symlink decides: $VPN_CONFIG_DIR/active.conf points at the
# chosen .conf, and the unit reads only that. Switching is therefore a symlink
# and a restart, which is scriptable and leaves a trace — the applet was neither.
#
# The configs themselves stay on the data disk and never enter the repo: each
# carries a PrivateKey, which for Proton IS the credential.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: vpn-switch.sh <host> [ch|nl|<name>]}"
WANT="${2:-}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

LINK="$VPN_CONFIG_DIR/active.conf"

available() { find "$VPN_CONFIG_DIR" -maxdepth 1 -name '*.conf' ! -name 'active.conf' -printf '%f\n' | sort; }

if [[ -z "$WANT" ]]; then
    echo "active: $(basename "$(readlink -f "$LINK" 2>/dev/null || echo 'none')")"
    echo "available:"
    available | sed 's/^/  /'
    exit 0
fi

# Match on a fragment so `ch` finds protonvpnCH-CH-919.conf without anyone
# having to type it. Ambiguity is an error rather than a guess — picking the
# wrong country silently is exactly the kind of quiet wrongness this repo tries
# to avoid.
mapfile -t hits < <(available | grep -i -- "$WANT" || true)
case "${#hits[@]}" in
    0) echo "ERROR: nothing matches '$WANT'. Available:"; available | sed 's/^/  /'; exit 1 ;;
    1) : ;;
    *) echo "ERROR: '$WANT' is ambiguous:"; printf '  %s\n' "${hits[@]}"; exit 1 ;;
esac

ln -sfn "$VPN_CONFIG_DIR/${hits[0]}" "$LINK"
echo "vpn: active.conf -> ${hits[0]}"

if systemctl is-active --quiet "$VPN_NETNS_UNIT"; then
    sudo systemctl restart "$VPN_NETNS_UNIT"
    echo "vpn: $VPN_NETNS_UNIT restarted"
else
    echo "vpn: $VPN_NETNS_UNIT is not running — start it to apply"
fi
