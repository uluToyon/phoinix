#!/usr/bin/env bash
# qemu-mon.sh — drive the VM that qemu-test.sh started, through its monitor.
#
#   qemu-mon.sh cmd 'info status'          any monitor command
#   qemu-mon.sh shot /tmp/vm.png           what is on the screen right now
#   qemu-mon.sh key ret                    one key
#   qemu-mon.sh type somestring            a string, key by key
#
# Why this exists: the test runs on a serial console, so stage 4's RESULT — a
# login greeter, a panel with the right launchers — cannot be seen there at
# all, and an unobservable test proves nothing. `shot` is how the greeter was
# confirmed and `type` is how its password field was filled, which is what put
# the real PLM login inside the tested chain instead of outside it.
# See docs/LOG.md 2026-07-31.

set -euo pipefail

WORK="${PHOINIX_QEMU_DIR:-$HOME/.cache/phoinix-qemu}"
SOCK="$WORK/monitor.sock"

usage() { echo "usage: qemu-mon.sh {cmd <monitor-command>|shot <file.png>|key <name>|type <string>}"; }

# Usage first, environment second: called with no arguments this should say how
# to use it, not complain that a VM is not running.
case "${1:-}" in cmd|shot|key|type) ;; *) usage; exit 1 ;; esac

[[ -S "$SOCK" ]] || { echo "ERROR: no monitor socket at $SOCK — is the VM running?"; exit 1; }
command -v socat >/dev/null || { echo "ERROR: socat not installed (packages/dev.txt)"; exit 1; }

# The monitor echoes its own banner and prompt back; drop the banner line so
# callers get the answer rather than the conversation.
mon() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$SOCK" 2>/dev/null | tail -n +2; }

case "${1:-}" in
cmd)
    mon "${2:?usage: qemu-mon.sh cmd '<monitor command>'}"
    ;;
shot)
    out="${2:?usage: qemu-mon.sh shot <file.png>}"
    [[ "$out" == /* ]] || out="$PWD/$out"      # the monitor resolves paths in QEMU's cwd
    mon "screendump $out -f png" >/dev/null
    # screendump returns before the file is complete; wait for it to settle.
    for _ in {1..20}; do [[ -s "$out" ]] && break; sleep 0.2; done
    echo "$out"
    ;;
key)
    mon "sendkey ${2:?usage: qemu-mon.sh key <qemu-key-name>}" >/dev/null
    ;;
type)
    s="${2:?usage: qemu-mon.sh type <string>}"
    # Deliberately limited to what maps to a QEMU key name one-to-one. Anything
    # else would need shift/altgr handling AND would depend on the guest's
    # keyboard layout — the greeter runs the German no-dead-keys layout stage 2
    # writes, so a naive mapping would type something other than what is asked
    # for. Refusing beats typing a wrong password into a login screen.
    [[ "$s" =~ ^[a-z0-9]+$ ]] || {
        echo "ERROR: 'type' handles [a-z0-9] only — anything else depends on the"
        echo "       guest keyboard layout. Use 'key' for individual keys."
        exit 1
    }
    for (( i = 0; i < ${#s}; i++ )); do
        mon "sendkey ${s:i:1}" >/dev/null
        sleep 0.15                              # the guest's input loop needs the gap
    done
    ;;
esac
