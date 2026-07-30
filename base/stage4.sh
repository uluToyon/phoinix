#!/usr/bin/env bash
# stage4.sh — runs INSIDE a running Plasma session, as the regular user.
#
#   usage: stage4.sh <host>        e.g. stage4.sh desktop
#
# Everything Plasma only accepts while its shell is alive: panel contents,
# widget configuration, anything keyed by an applet id or activity UUID.
# Stage 3 cannot do this — it runs before the first graphical login, when
# none of those files exist yet and none of those ids are known.
#
# Installed by stage 3 as a systemd user unit that fires ONCE, after
# plasma-plasmashell.service, on the first graphical login. Re-runnable by
# hand at any time; it is idempotent and never asks a question.
#
# Rule for this file: address widgets by TYPE, never by id. Applet numbers
# and activity UUIDs are generated per installation — hard-coding them
# produces a script that silently edits the wrong widget after a reinstall.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: stage4.sh <host>   (e.g. stage4.sh desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

[[ $EUID -ne 0 ]] || { echo "ERROR: run stage 4 as your user, not root"; exit 1; }

exec > >(tee -a "$HOME/stage4.log") 2>&1
echo "=== stage 4 start: $(date -Is) ==="

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/phoinix"
MARKER="$STATE_DIR/stage4.done"

# ------------------------------------------------- the desired Plasma state
# Pinned launchers of the main panel, in display order. The TV panel is a
# clone of that panel, so this list reaches both.
PANEL_LAUNCHERS='["applications:org.kde.konsole.desktop","applications:org.kde.dolphin.desktop","applications:brave-browser.desktop","applications:org.keepassxc.KeePassXC.desktop","applications:org.strawberrymusicplayer.strawberry.desktop","applications:discord.desktop","applications:org.qbittorrent.qBittorrent.desktop"]'

# Kickoff favourites. Plasma's default list ships Discover AND Kontact,
# neither of which is installed here — they would sit there as dead entries.
KICKOFF_FAVOURITES="preferred://browser,systemsettings.desktop,org.kde.dolphin.desktop"

# ------------------------------------------------- 1. wait for the shell
# The unit orders itself after plasma-plasmashell.service, but systemd
# considers the service started once the process exists — the scripting
# interface comes up a moment later. Poll instead of guessing a sleep.
plasma_ready() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'print(0)' >/dev/null 2>&1
}
for _ in {1..60}; do
    plasma_ready && break
    sleep 1
done
plasma_ready || { echo "ERROR: plasmashell scripting interface never appeared"; exit 1; }

plasma_script() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"
}

# ------------------------------------------------- 2. panels
# Connector -> "x,y,width,height", straight from KScreen. This is the bridge
# between the stable name of a physical output and the unstable number Plasma
# uses internally; panels.js matches on the geometry, never on the number.
connector_geometry() {
    kscreen-doctor -o 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' | awk -v want="$1" '
        /^Output:/  { name = $3 }
        /Geometry:/ && name == want {
            split($2, pos, ","); split($3, dim, "x");
            print pos[1] "," pos[2] "," dim[1] "," dim[2];
            found = 1; exit
        }
        END { if (!found) print "-1,-1,-1,-1" }'   # not connected -> panels.js skips it
}

PANEL_JS="$(mktemp)"
trap 'rm -f "$PANEL_JS"' EXIT

sed -e "s|@MAIN_GEOM@|$(connector_geometry "$PANEL_MAIN_CONNECTOR")|" \
    -e "s|@TV_GEOM@|$(connector_geometry "$PANEL_TV_CONNECTOR")|" \
    -e "s|@SIDE1_GEOM@|$(connector_geometry "${PANEL_SIDE[0]%%:*}")|" \
    -e "s|@SIDE1_THICKNESS@|${PANEL_SIDE[0]##*:}|" \
    -e "s|@SIDE2_GEOM@|$(connector_geometry "${PANEL_SIDE[1]%%:*}")|" \
    -e "s|@SIDE2_THICKNESS@|${PANEL_SIDE[1]##*:}|" \
    -e "s|@MAIN_HEIGHT@|$PANEL_MAIN_HEIGHT|" \
    -e "s|@LAUNCHERS@|$PANEL_LAUNCHERS|" \
    "$REPO_DIR/plasma/panels.js" > "$PANEL_JS"

plasma_script "$(< "$PANEL_JS")"

# ------------------------------------------------- 3. kickoff favourites
# Stored in kactivitymanagerd-statsrc under a group name built from the
# Kickoff applet id and the activity UUID — both installation-specific, so
# both are looked up at runtime rather than written into this file.
KICKOFF_ID="$(plasma_script '
var id = "";
panels().forEach(function(p) {
    p.widgets().forEach(function(w) {
        if (w.type.indexOf("kickoff") !== -1) { id = w.id; }
    });
});
print(id);' | tr -dc '0-9')"

ACTIVITY="$(qdbus6 org.kde.ActivityManager /ActivityManager/Activities \
            org.kde.ActivityManager.Activities.CurrentActivity 2>/dev/null || true)"

if [[ -n "$KICKOFF_ID" ]]; then
    # The daemon caches this file and writes it back on exit — stop it first,
    # or the edit is lost at the end of the session.
    systemctl --user stop plasma-kactivitymanagerd.service || true

    for suffix in global ${ACTIVITY:-}; do
        kwriteconfig6 --file kactivitymanagerd-statsrc \
            --group "Favorites-org.kde.plasma.kickoff.favorites.instance-${KICKOFF_ID}-${suffix}" \
            --key ordering "$KICKOFF_FAVOURITES"
    done

    systemctl --user start plasma-kactivitymanagerd.service || true
    echo "kickoff favourites set (applet $KICKOFF_ID, activity ${ACTIVITY:-none})"
else
    echo "WARNING: no kickoff applet found — favourites left untouched"
fi

# ------------------------------------------------- 4. flat pointer profile
# This is a gaming PC: NO mouse gets pointer acceleration. Deliberately a rule
# about every pointer rather than a setting on one device.
#
# Why this is stage 4 and not stage 3: KDE stores the profile per device, in a
# group built from vendor id, product id and device NAME —
#   [Libinput][13364][53321][Keychron Keychron M6 8K]
# Writing that literally would put three discovered identifiers into the repo
# (against CLAUDE.md), cover exactly one mouse, and silently do nothing the day
# a different one is plugged in.
#
# Instead: ask KWin at runtime which pointers exist and set the property on
# each. KWin builds the group name and persists it to kcminputrc itself, so no
# identifier is ever authored here. Same principle as the panels — look ids up,
# never hard-code them.
#
# Devices that report no support for the flat profile (the "Consumer Control"
# pseudo-devices every keyboard registers) are skipped; setting it would fail.
kwin_dev_get() {
    qdbus6 org.kde.KWin "$1" org.freedesktop.DBus.Properties.Get \
           org.kde.KWin.InputDevice "$2" 2>/dev/null
}

pointers="$(qdbus6 org.kde.KWin /org/kde/KWin/InputDevice \
            org.kde.KWin.InputDeviceManager.ListPointers 2>/dev/null || true)"
if [[ -z "$pointers" ]]; then
    echo "WARNING: KWin listed no pointer devices — acceleration profile untouched"
fi
for sys in $pointers; do
    dev="/org/kde/KWin/InputDevice/$sys"
    [[ "$(kwin_dev_get "$dev" supportsPointerAccelerationProfileFlat)" == "true" ]] || continue
    qdbus6 org.kde.KWin "$dev" org.freedesktop.DBus.Properties.Set \
           org.kde.KWin.InputDevice pointerAccelerationProfileFlat true 2>/dev/null \
        && echo "flat pointer profile: $(kwin_dev_get "$dev" name)"
done

# ------------------------------------------------- 5. restart the shell
# Freshly created task-manager widgets read their launcher list once, when
# they are built — writing the config afterwards reaches the file but not the
# running instance, so the panel would show the built-in default (with its
# broken Discover icon) until the next login. Restarting plasmashell is what
# makes the panels look the way this script just described them. Windows are
# unaffected; only the shell reloads.
systemctl --user restart plasma-plasmashell.service
echo "plasmashell restarted"

# ------------------------------------------------- done
install -d "$STATE_DIR"
date -Is > "$MARKER"
echo "=== stage 4 done — marker: $MARKER ==="
echo "The systemd unit skips itself from now on; delete the marker to re-arm it."
