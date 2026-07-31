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
    # NOTE: awk deliberately reads to the end instead of `exit`ing on the first
    # match. Exiting closes the pipe while kscreen-doctor is still writing,
    # which raises SIGPIPE upstream: harmless where the result is only
    # interpolated into an argument (it merely logged "sed: couldn't flush
    # stdout: Broken pipe"), but fatal in `x="$(connector_geometry ...)"`,
    # where the substitution's status IS the assignment's and `set -e` aborts
    # the whole stage. Reading on costs nothing and removes both.
    kscreen-doctor -o 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' | awk -v want="$1" '
        /^Output:/  { name = $3 }
        /Geometry:/ && name == want && !found {
            split($2, pos, ","); split($3, dim, "x");
            print pos[1] "," pos[2] "," dim[1] "," dim[2];
            found = 1
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

# ------------------------------------------------- 5. Places sidebar order
# Dolphin's Places panel lists device entries in an order KDE persists as
# <separator> markers in user-places.xbel — one per device, identifying it by
# UDI (which contains the device node) AND filesystem uuid:
#
#   <UDI>/org/freedesktop/UDisks2/block_devices/sda1</UDI>
#   <uuid>4eb23c82-...</uuid>
#
# Neither may be written into the repo: device nodes are handed out in probe
# order, and the root/home UUIDs are generated by every fresh install. So the
# repo stores an order of LABELS (PLACES_ORDER in hosts/<host>/config.sh) and
# this resolves them here, at runtime. Same principle as the panel geometry and
# the pointer profile.
#
# Stage 4 rather than stage 3 because the file has to exist first: it is
# created by KDE with its standard bookmarks, and writing it from scratch would
# mean authoring KDE's bookmark ids as well.
PLACES_FILE="$HOME/.local/share/user-places.xbel"

if [[ ! -f "$PLACES_FILE" ]]; then
    echo "WARNING: $PLACES_FILE does not exist yet — Places order not applied."
    echo "         Open Dolphin once, then re-run: $0 $HOST"
else
    separators=""
    for label in "${PLACES_ORDER[@]}"; do
        dev="$(readlink -f "/dev/disk/by-label/$label" 2>/dev/null || true)"
        if [[ -z "$dev" || ! -b "$dev" ]]; then
            echo "places: label '$label' not present — skipped"
            continue
        fi
        uuid="$(lsblk -no UUID "$dev" 2>/dev/null | head -1)"
        if [[ -z "$uuid" ]]; then
            echo "places: no uuid for '$label' ($dev) — skipped"
            continue
        fi
        separators+=" <separator>
  <info>
   <metadata owner=\"http://www.kde.org\">
    <UDI>/org/freedesktop/UDisks2/block_devices/$(basename "$dev")</UDI>
    <isSystemItem>true</isSystemItem>
    <uuid>$uuid</uuid>
   </metadata>
  </info>
 </separator>
"
        echo "places: $label -> $(basename "$dev")"
    done

    # Refuse to rewrite when nothing resolved. Without this guard the awk below
    # strips every existing marker and puts nothing back — an empty
    # PLACES_ORDER, or a machine with its disks unplugged, would silently
    # DESTROY the ordering instead of leaving it alone. Cost one accidental
    # wipe during development to learn.
    if [[ -z "$separators" ]]; then
        echo "WARNING: no label from PLACES_ORDER resolved — sidebar left untouched"
    else
        # Drop every existing separator, then insert ours before </xbel>.
        # Rebuilt rather than patched: the previous order is unknown state, and
        # the markers carry no clue which of them a user put where.
        tmp="$(mktemp)"
        awk -v blocks="$separators" '
            /<separator>/            { skip = 1 }
            skip && /<\/separator>/  { skip = 0; next }
            skip                     { next }
            /<\/xbel>/               { printf "%s", blocks }
                                     { print }
        ' "$PLACES_FILE" > "$tmp" && mv "$tmp" "$PLACES_FILE"
        echo "places: sidebar order written"
    fi
fi

# ------------------------------------------------- 6. window rules
# ALL window rules live here, including ones that would work fine in stage 3.
# They share a single index — `count` and `rules` in [General] list every rule
# id — so two stages writing into kwinrulesrc would sooner or later have one
# overwrite the other's entries. One owner, and it is the stage that can also
# resolve a screen position.
#
# Positions are the reason: a rule storing `position=7280,0` encodes a
# coordinate in the current monitor layout, and it points somewhere else the
# day a screen is rearranged, silently. The repo stores a connector name
# instead and this resolves it to that monitor's origin at runtime, reusing the
# same connector_geometry() the panels use.
#
# Rule ids are UUIDs authored here and kept FIXED, so a re-run updates a rule
# instead of appending a duplicate.
KWIN_RULES=()

rule_set() {   # $1 = rule uuid, rest = key=value pairs
    local uuid="$1"; shift
    local kv
    for kv in "$@"; do
        kwriteconfig6 --file kwinrulesrc --group "$uuid" --key "${kv%%=*}" "${kv#*=}"
    done
    KWIN_RULES+=("$uuid")
}

# Dolphin: size only, no position — it may open wherever it likes.
rule_set "29ab85f8-8f9d-4b32-8d51-59a70e84660d" \
    "Description=Application settings for org.kde.dolphin" \
    "wmclass=dolphin org.kde.dolphin" \
    "wmclasscomplete=true" \
    "wmclassmatch=1" \
    "size=$DOLPHIN_SIZE" \
    "sizerule=3"

# Konsole: opens at the origin of its configured monitor. "Apply Initially"
# for both, so the window starts there and stays movable afterwards.
konsole_geom="$(connector_geometry "$KONSOLE_CONNECTOR")"
IFS=, read -r kx ky _ _ <<< "$konsole_geom"
if [[ "$kx" == "-1" ]]; then
    echo "WARNING: $KONSOLE_CONNECTOR not connected — Konsole rule without position"
    rule_set "02b2155b-05b1-4162-8852-f76552df6f06" \
        "Description=Application settings for org.kde.konsole" \
        "wmclass=konsole org.kde.konsole" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$KONSOLE_SIZE" "sizerule=3"
else
    echo "window rules: Konsole -> $KONSOLE_CONNECTOR origin $kx,$ky"
    rule_set "02b2155b-05b1-4162-8852-f76552df6f06" \
        "Description=Application settings for org.kde.konsole" \
        "wmclass=konsole org.kde.konsole" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$kx,$ky" "positionrule=3" \
        "size=$KONSOLE_SIZE" "sizerule=3"
fi

# Strawberry: opens at the origin of its configured monitor.
strawberry_geom="$(connector_geometry "$STRAWBERRY_CONNECTOR")"
IFS=, read -r sx sy _ _ <<< "$strawberry_geom"
if [[ "$sx" == "-1" ]]; then
    echo "WARNING: $STRAWBERRY_CONNECTOR not connected — Strawberry rule without position"
    rule_set "75ed2684-49b4-4641-b015-894da96da0c8" \
        "Description=Application settings for org.strawberrymusicplayer.strawberry" \
        "wmclass=strawberry org.strawberrymusicplayer.strawberry" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$STRAWBERRY_SIZE" "sizerule=3"
else
    echo "window rules: Strawberry -> $STRAWBERRY_CONNECTOR origin $sx,$sy"
    rule_set "75ed2684-49b4-4641-b015-894da96da0c8" \
        "Description=Application settings for org.strawberrymusicplayer.strawberry" \
        "wmclass=strawberry org.strawberrymusicplayer.strawberry" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$sx,$sy" "positionrule=3" \
        "size=$STRAWBERRY_SIZE" "sizerule=3"
fi

# The order of this list is the order KWin applies the rules in, so it only
# matters once two rules can match the SAME window. These match different
# applications, hence any order is correct here.
kwriteconfig6 --file kwinrulesrc --group General --key count "${#KWIN_RULES[@]}"
kwriteconfig6 --file kwinrulesrc --group General --key rules "$(IFS=,; echo "${KWIN_RULES[*]}")"

# KWin reads its rules at startup, so a fresh install would otherwise only see
# them from the SECOND login onwards. This makes them take effect immediately.
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null \
    && echo "window rules: KWin reconfigured" \
    || echo "WARNING: could not ask KWin to reload its rules — they apply at next login"

# ------------------------------------------------- 7. Strawberry playlist
# Re-imports ulu's playlist file into a fresh Strawberry database. The file
# itself is not ours — it lives with the music on a data disk, grows over time,
# and survives reinstalls on its own. Only the import belongs to phoinix.
#
# Strawberry does NOT keep the file in sync with the running playlist: saving
# is a one-off export. So the file is an anchor, not a mirror, and re-saving it
# after adding tracks stays a manual step (STATUS.md).
#
# sqlite3 is safe to rely on here: strawberry depends on it directly, so it
# exists wherever this step can do anything at all.
if [[ -n "${PLAYLIST_FILE:-}" && -f "$PLAYLIST_FILE" ]]; then
    SB_DB="$HOME/.local/share/strawberry/strawberry/strawberry.db"

    # Guard against a second import. Stage 4 is single-shot, but it gets re-run
    # by hand during development, and `--create` would happily build a second
    # playlist with the same name every time. Names are compared with grep -Fx
    # rather than an SQL WHERE clause, which keeps the playlist name out of the
    # query string entirely.
    if [[ -f "$SB_DB" ]] && sqlite3 "file:$SB_DB?mode=ro" "SELECT name FROM playlists;" 2>/dev/null \
         | grep -Fxq "$PLAYLIST_NAME"; then
        echo "playlist: '$PLAYLIST_NAME' already exists — not importing again"
    else
        strawberry --create "$PLAYLIST_NAME" "$PLAYLIST_FILE" >/dev/null 2>&1 \
            && echo "playlist: imported $PLAYLIST_FILE as '$PLAYLIST_NAME'" \
            || echo "WARNING: could not import $PLAYLIST_FILE"
    fi
elif [[ -n "${PLAYLIST_FILE:-}" ]]; then
    echo "playlist: $PLAYLIST_FILE not present — skipped"
fi

# ------------------------------------------------- 8. restart the shell
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
