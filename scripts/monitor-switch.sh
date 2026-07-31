#!/usr/bin/env bash
# monitor-switch.sh — flip every DDC-capable monitor between this machine and
# the laptop, from one desktop icon.
#
#   usage: monitor-switch.sh <host>
#
# ulu's three monitors are wired to both machines. This used to be two
# hand-written scripts full of `ddcutil --bus 9`, and those bus numbers HAD
# ALREADY DRIFTED once: the desktop-side script carried a commented-out
# `--bus 8` directly above its replacement `--bus 10`, i.e. ulu had renumbered
# it by hand after a reboot moved things. Bus numbers are exactly the kind of
# discovered identifier CLAUDE.md forbids, so this selects by MODEL, which
# comes out of the EDID and travels with the panel.
#
# The direction is decided here, not passed in: the reference monitor is asked
# what it is showing right now and everything moves to the other side. One
# icon, both directions, and no state file that can drift out of sync with what
# the monitors are actually doing.
#
# WHY a reference monitor instead of asking each panel: the two TCLs answer
# 0x07 for the input source no matter what was last written to them, and their
# own capabilities list does not even contain the values that demonstrably work
# (6 and 8). They can be DRIVEN but not BELIEVED. The Acer answers honestly
# (0x0f DisplayPort-1 / 0x11 HDMI-1), so it decides for all three.
#
# The 6 and 8 are deliberately left as bare numbers in the host config. They
# are not derivable from anything — they are values that were tried and work.
# Do not "correct" them to the standard MCCS codes the TCLs advertise.
#
# ddcutil brings its own prerequisites: /usr/lib/modules-load.d/ddcutil.conf
# loads i2c-dev, and its udev rule tags the graphics i2c devices with uaccess.
# So installing the package is enough — no i2c group membership is needed, and
# this repo does not ship a udev rule for it.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: monitor-switch.sh <host>   (e.g. desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

# Clicked from a desktop icon, so there is no terminal to print to. Say it out
# loud where a notification daemon exists, and keep printing for the case where
# this is run from a shell after all.
say() {
    echo "$1"
    command -v notify-send >/dev/null 2>&1 && notify-send -a "phoinix" "Monitors" "$1" || true
}
die() { say "$1"; exit 1; }

[[ ${#MONITOR_SWITCH[@]} -gt 0 ]] || die "no MONITOR_SWITCH configured for host $HOST"
[[ -n "${MONITOR_SWITCH_REF:-}" ]] || die "MONITOR_SWITCH_REF not set for host $HOST"
command -v ddcutil >/dev/null 2>&1 || die "ddcutil is not installed"

# Entries are model:desktop_value:laptop_value. Models may contain spaces (the
# Acer is "XZ322QU V3"), which is why the separator is a colon and not
# whitespace — no EDID model string contains one.
ref_desktop="" ref_laptop=""
for entry in "${MONITOR_SWITCH[@]}"; do
    model="${entry%%:*}"; rest="${entry#*:}"
    if [[ "$model" == "$MONITOR_SWITCH_REF" ]]; then
        ref_desktop="${rest%%:*}"
        ref_laptop="${rest##*:}"
    fi
done
[[ -n "$ref_desktop" ]] || die "MONITOR_SWITCH_REF '$MONITOR_SWITCH_REF' is not in MONITOR_SWITCH"

# `getvcp --terse` answers "VCP 60 SNC x0f" — field 4, hex, with a bare x.
now_raw="$(ddcutil --model "$MONITOR_SWITCH_REF" getvcp 60 --terse 2>/dev/null | awk '{print $4}')"
[[ -n "$now_raw" ]] || die "reference monitor '$MONITOR_SWITCH_REF' did not answer — is it on?"
now=$((16#${now_raw#x}))

# Only the laptop value sends us back; ANYTHING else goes to the laptop. That
# asymmetry is on purpose: this is triggered by a desktop icon, so whoever
# clicked it is sitting at the desktop looking at the desktop, and "I could not
# tell" should still do the thing they asked for.
if [[ "$now" -eq "$ref_laptop" ]]; then
    target="desktop"
else
    target="laptop"
fi

failed=0
for entry in "${MONITOR_SWITCH[@]}"; do
    model="${entry%%:*}"; rest="${entry#*:}"
    if [[ "$target" == "laptop" ]]; then
        value="${rest##*:}"
    else
        value="${rest%%:*}"
    fi
    if ddcutil --model "$model" setvcp 60 "$value" >/dev/null 2>&1; then
        echo "  $model -> $value"
    else
        echo "  WARNING: $model did not accept $value — not connected?"
        failed=$((failed + 1))
    fi
done

# Only worth announcing when switching TO the desktop; the other direction takes
# the screen away before a notification could be read.
if [[ "$failed" -gt 0 ]]; then
    say "switched to $target, $failed monitor(s) did not respond"
elif [[ "$target" == "desktop" ]]; then
    say "switched to $target"
else
    echo "switched to $target"
fi
