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

# What this host must declare. Checked here, by name, because `set -u` alone
# reports "PANEL_MAIN_CONNECTOR: unbound variable" from somewhere in the middle
# of a sed pipeline — true, useless, and 200 lines away from the file that
# actually has to change. A second host is what exposed this: adding one used
# to mean discovering the required set one crash at a time.
# NOT in this list: the TV clone and the side strips. A machine with fewer
# monitors declares fewer, and that is normal rather than incomplete — the
# laptop this repo already plans for has exactly one screen.
missing=()
for v in PANEL_MAIN_CONNECTOR PANEL_MAIN_HEIGHT \
         KONSOLE_CONNECTOR KONSOLE_SIZE STRAWBERRY_CONNECTOR STRAWBERRY_SIZE \
         DOLPHIN_SIZE; do
    [[ -n "${!v:-}" ]] || missing+=("$v")
done
if (( ${#missing[@]} )); then
    echo "ERROR: hosts/$HOST/config.sh does not declare: ${missing[*]}"
    exit 1
fi

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

# An optional panel that this host does not declare gets the same
# "not connected" geometry as one whose cable is out — panels.js already skips
# that, so absence needs no second code path. Undeclared and unplugged are the
# same thing from the panel's point of view.
NO_SCREEN="-1,-1,-1,-1"
opt_geom()       { [[ -n "${1:-}" ]] && connector_geometry "$1" || echo "$NO_SCREEN"; }
side_geom()      { [[ -n "${1:-}" ]] && connector_geometry "${1%%:*}" || echo "$NO_SCREEN"; }
side_thickness() { [[ -n "${1:-}" ]] && echo "${1##*:}" || echo "0"; }

PANEL_JS="$(mktemp)"
trap 'rm -f "$PANEL_JS"' EXIT

sed -e "s|@MAIN_GEOM@|$(connector_geometry "$PANEL_MAIN_CONNECTOR")|" \
    -e "s|@TV_GEOM@|$(opt_geom "${PANEL_TV_CONNECTOR:-}")|" \
    -e "s|@SIDE1_GEOM@|$(side_geom "${PANEL_SIDE[0]:-}")|" \
    -e "s|@SIDE1_THICKNESS@|$(side_thickness "${PANEL_SIDE[0]:-}")|" \
    -e "s|@SIDE2_GEOM@|$(side_geom "${PANEL_SIDE[1]:-}")|" \
    -e "s|@SIDE2_THICKNESS@|$(side_thickness "${PANEL_SIDE[1]:-}")|" \
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

# And it has to be WAITED for, because stage 4 and the session that creates it
# start together. Measured on the reinstall run of 2026-08-01: the step gave up
# at 12:13:44 and the file was created at 12:13:44.871 — the same second, a few
# hundred milliseconds after the check. The session creates it by itself
# (KIO/plasmashell), so waiting is reliable; it is only ever early, never
# absent. The closing tag is part of the test on purpose: a file caught halfway
# through being written exists without being usable, and here it is being
# written at exactly this moment.
if [[ ${#PLACES_ORDER[@]} -gt 0 ]]; then
    for _ in $(seq 30); do
        [[ -f "$PLACES_FILE" ]] && grep -q "</xbel>" "$PLACES_FILE" 2>/dev/null && break
        sleep 1
    done
fi

if [[ ${#PLACES_ORDER[@]} -eq 0 ]]; then
    # A host that declares no ordering keeps KDE's. Distinct from the guard
    # further down, which catches a declared ordering that resolved to nothing
    # — that one means disks are missing and must not rewrite the file.
    echo "places: no PLACES_ORDER declared for $HOST — sidebar left untouched"
elif [[ ! -f "$PLACES_FILE" ]] || ! grep -q "</xbel>" "$PLACES_FILE" 2>/dev/null; then
    echo "WARNING: $PLACES_FILE still absent or incomplete after 30s —"
    echo "         Places order not applied. Open Dolphin once, then re-run: $0 $HOST"
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
#
# The two maximize keys are not decoration — without them the size rule is
# silently defeated on a FRESH install (measured 2026-08-01, first start after
# the scripted reinstall): Strawberry comes up maximized when it has no saved
# geometry, so "Apply Initially" sets 1920x2105 at map time and the maximized
# state then covers the whole monitor. It does not heal itself either — on exit
# Strawberry saves `maximized`, so every later start reproduces it until the
# window is resized by hand. "Apply Initially" here too: the window merely
# STARTS unmaximized, and the maximize button keeps working.
strawberry_geom="$(connector_geometry "$STRAWBERRY_CONNECTOR")"
IFS=, read -r sx sy _ _ <<< "$strawberry_geom"
if [[ "$sx" == "-1" ]]; then
    echo "WARNING: $STRAWBERRY_CONNECTOR not connected — Strawberry rule without position"
    rule_set "75ed2684-49b4-4641-b015-894da96da0c8" \
        "Description=Application settings for org.strawberrymusicplayer.strawberry" \
        "wmclass=strawberry org.strawberrymusicplayer.strawberry" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$STRAWBERRY_SIZE" "sizerule=3" \
        "maximizehoriz=false" "maximizehorizrule=3" \
        "maximizevert=false" "maximizevertrule=3"
else
    echo "window rules: Strawberry -> $STRAWBERRY_CONNECTOR origin $sx,$sy"
    rule_set "75ed2684-49b4-4641-b015-894da96da0c8" \
        "Description=Application settings for org.strawberrymusicplayer.strawberry" \
        "wmclass=strawberry org.strawberrymusicplayer.strawberry" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$sx,$sy" "positionrule=3" \
        "size=$STRAWBERRY_SIZE" "sizerule=3" \
        "maximizehoriz=false" "maximizehorizrule=3" \
        "maximizevert=false" "maximizevertrule=3"
fi

# qBittorrent: shares DP-2 with Strawberry, which takes the left half — so
# this one needs an OFFSET from the monitor's origin, not the origin itself.
# The offset is what stays true when screens are rearranged; the absolute
# coordinate ulu's GUI produced (1920,804) would not be.
# The window class has a LEADING SPACE (`\s` in kwinrulesrc): qBittorrent
# reports an empty instance name, so "instance class" collapses to
# " org.qbittorrent.qBittorrent". Reproduced verbatim — with wmclasscomplete
# the rule matches nothing without it.
qbt_geom="$(connector_geometry "${QBT_CONNECTOR:-}")"
IFS=, read -r qx qy _ _ <<< "$qbt_geom"
IFS=, read -r qdx qdy <<< "${QBT_OFFSET:-0,0}"
if [[ "$qx" == "-1" ]]; then
    echo "WARNING: ${QBT_CONNECTOR:-<none>} not connected — qBittorrent rule without position"
    rule_set "cec25307-a720-4a68-b92c-0e6c77592351" \
        "Description=Application settings for org.qbittorrent.qBittorrent" \
        "wmclass= org.qbittorrent.qBittorrent" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$QBT_SIZE" "sizerule=3"
else
    echo "window rules: qBittorrent -> $QBT_CONNECTOR origin $qx,$qy + offset $qdx,$qdy"
    rule_set "cec25307-a720-4a68-b92c-0e6c77592351" \
        "Description=Application settings for org.qbittorrent.qBittorrent" \
        "wmclass= org.qbittorrent.qBittorrent" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$((qx + qdx)),$((qy + qdy))" "positionrule=3" \
        "size=$QBT_SIZE" "sizerule=3"
fi

# Discord: the lower half of the portrait monitor, directly beneath Konsole.
# Offset again, for the same reason as qBittorrent — two windows sharing one
# screen means one of them is not at the origin, and the absolute coordinate
# would be a lie the moment the screens are rearranged.
discord_geom="$(connector_geometry "${DISCORD_CONNECTOR:-}")"
IFS=, read -r dcx dcy _ _ <<< "$discord_geom"
IFS=, read -r dcdx dcdy <<< "${DISCORD_OFFSET:-0,0}"
if [[ "$dcx" == "-1" ]]; then
    echo "WARNING: ${DISCORD_CONNECTOR:-<none>} not connected — Discord rule without position"
    rule_set "91ef720f-7168-401d-8652-1825045854e6" \
        "Description=Application settings for discord" \
        "wmclass=Discord discord" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$DISCORD_SIZE" "sizerule=3"
else
    echo "window rules: Discord -> $DISCORD_CONNECTOR origin $dcx,$dcy + offset $dcdx,$dcdy"
    rule_set "91ef720f-7168-401d-8652-1825045854e6" \
        "Description=Application settings for discord" \
        "wmclass=Discord discord" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$((dcx + dcdx)),$((dcy + dcdy))" "positionrule=3" \
        "size=$DISCORD_SIZE" "sizerule=3"
fi

# KeePassXC: the lower right quarter of DP-2, directly beneath qBittorrent.
# Offset again, same reason as the two above — three windows share that screen.
# The UUID is the one KDE generated when ulu created the rule in the GUI, kept
# deliberately: reusing it means this stage UPDATES his rule instead of adding
# a second one that says the same thing.
#
# Capturing it here is not optional bookkeeping. Stage 4 rewrites `count` and
# `rules` in [General] from its own list, so a rule that exists only in the GUI
# is dropped from the index the next time this stage runs — the rule group
# would still sit in the file, orphaned and inert.
keepassxc_geom="$(connector_geometry "${KEEPASSXC_CONNECTOR:-}")"
IFS=, read -r kpx kpy _ _ <<< "$keepassxc_geom"
IFS=, read -r kpdx kpdy <<< "${KEEPASSXC_OFFSET:-0,0}"
if [[ "$kpx" == "-1" ]]; then
    echo "WARNING: ${KEEPASSXC_CONNECTOR:-<none>} not connected — KeePassXC rule without position"
    rule_set "6eebfca2-624b-4576-89c4-434a806b1df1" \
        "Description=Application settings for KeePassXC" \
        "wmclass=keepassxc KeePassXC" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "size=$KEEPASSXC_SIZE" "sizerule=3"
else
    echo "window rules: KeePassXC -> $KEEPASSXC_CONNECTOR origin $kpx,$kpy + offset $kpdx,$kpdy"
    rule_set "6eebfca2-624b-4576-89c4-434a806b1df1" \
        "Description=Application settings for KeePassXC" \
        "wmclass=keepassxc KeePassXC" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "position=$((kpx + kpdx)),$((kpy + kpdy))" "positionrule=3" \
        "size=$KEEPASSXC_SIZE" "sizerule=3"
fi

# FFXIV: borderless windowed, filling its configured monitor. Three things
# about this rule are unlike every other one in this file.
#
# 1. The window class is not the game's. umu/Proton labels every non-Steam
#    title it launches `steam_app_default` — no Steam AppID is set, so they all
#    collapse onto one class, and DZGUI's DayZ would match it just as well.
#    The class alone is therefore a trap, and this rule discriminates on the
#    TITLE as well. That title is a string the game sets; if the rule ever
#    stops matching after a patch, look there first.
# 2. The size comes from the connector, not from a *_SIZE variable. Borderless
#    means "exactly this monitor", so the monitor's own resolution IS the
#    setting — hardcoding 3440x1440 would be a second place to forget.
# 3. It only works because XIVLauncher runs the game over XWayland
#    (`WaylandEnabled=false` in launcher.ini). A Wayland-native client cannot
#    be positioned by anything, itself included; if that toggle ever flips
#    back, this rule goes silent and the game lands wherever KWin likes.
ffxiv_geom="$(connector_geometry "${FFXIV_CONNECTOR:-}")"
IFS=, read -r fx fy fw fh <<< "$ffxiv_geom"
if [[ "$fx" == "-1" ]]; then
    echo "WARNING: ${FFXIV_CONNECTOR:-<none>} not connected — FFXIV rule skipped"
else
    echo "window rules: FFXIV -> $FFXIV_CONNECTOR ${fw}x${fh} at $fx,$fy"
    rule_set "eb5ce25d-79dc-4d01-920b-a7018c35c755" \
        "Description=Application settings for FINAL FANTASY XIV" \
        "wmclass=steam_app_default steam_app_default" \
        "wmclasscomplete=true" "wmclassmatch=1" \
        "title=FINAL FANTASY XIV" "titlematch=1" \
        "position=$fx,$fy" "positionrule=3" \
        "size=$fw,$fh" "sizerule=3"
fi

# Brave: adaptive sync (VRR) forced OFF for its windows, and nothing else —
# no size, no position, no monitor.
#
# The reason, because a bare `adaptivesync=false` reads like an accident two
# years from now: ulu gets a constant slight flicker watching video, YouTube
# being the case that drove him up the wall. It is NOT a Brave problem — mpc-qt
# shows exactly the same thing, and those two share nothing but playing video.
#
# The mechanism that fits (inferred, not measured): DP-1's VRR range is
# 48-170 Hz, while video runs at 24/25/30 fps. Below the range the display has
# to duplicate frames, the refresh rate oscillates between two states, and that
# is what the eye reads as flicker. Games stay inside the range, so they never
# show it.
#
# Which is why this is per-application rather than per-output. Turning VRR off
# on the monitor would fix the flicker and throw away the reason VRR is on a
# gaming machine at all. Expect this rule to recur for every video player —
# mpc-qt is already known to need it.
#
# NOT to be confused with the sporadic black FLASH on DP-1 (see STATUS.md):
# that one is a full blank lasting an instant, diagnosed as DP link retraining,
# and it happens with no video playing at all. Two different phenomena on the
# same output; conflating them would send the next investigation sideways.
#
# `adaptivesyncrule=2` is Force, not Apply Initially — the setting has to hold
# for the window's whole life, not just when it opens.
rule_set "e259a1ad-617f-4de3-b357-fbd289793312" \
    "Description=Application settings for brave-browser" \
    "wmclass=brave brave-browser" \
    "wmclasscomplete=true" "wmclassmatch=1" \
    "adaptivesync=false" "adaptivesyncrule=2"

# mpc-qt: the same rule, and its recurrence was predicted when Brave's was
# written. Two applications that share nothing but playing video, both needing
# VRR off — which is what moved the finding out of Brave and into the display.
# If a third video player ever joins, it wants this line too.
rule_set "87ef503c-e43d-41b8-b5c5-701cbe71f854" \
    "Description=Application settings for io.github.mpc_qt.mpc-qt" \
    "wmclass=mpc-qt io.github.mpc_qt.mpc-qt" \
    "wmclasscomplete=true" "wmclassmatch=1" \
    "adaptivesync=false" "adaptivesyncrule=2"

# ------------------------------------------------- 5b. desktop icon position
# Plasma stores Folder View icon positions keyed by SCREEN RESOLUTION, inside a
# containment whose number and activity UUID are generated per installation.
# So both are resolved here: the resolution from PANEL_MAIN_CONNECTOR, the
# containment by finding the folder plugin that sits on that resolution.
#
# plasmashell CACHES this file and writes it back when it exits, so writing
# underneath a running shell is discarded — the same trap the Kickoff
# favourites hit. Hence stop, write, start.
if [[ ${#DESKTOP_ICONS[@]} -gt 0 ]]; then
    main_geom="$(connector_geometry "$PANEL_MAIN_CONNECTOR")"
    IFS=, read -r mx my mw mh <<< "$main_geom"
    if [[ "$mw" == "-1" ]]; then
        echo "WARNING: $PANEL_MAIN_CONNECTOR not connected — desktop icon position skipped"
    else
        res="${mw}x${mh}"
        applets="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

        # Which containment is the Folder View on that screen?
        #
        # This used to match on `lastResolution`, and that could never work on
        # the one machine state it matters for. Plasma writes that key only
        # once icons have been arranged BY HAND, so a virgin install has none —
        # verified on the first real install: four folder containments, zero
        # lastResolution keys (LOG 2026-07-31). The stage warned and skipped,
        # and every future reinstall would have hit the same wall by
        # construction. It worked on the old system only because ulu had
        # arranged those icons years earlier.
        #
        # `lastScreen` is written from the start. It holds Plasma's own screen
        # NUMBER, assigned in detection order — precisely the kind of
        # discovered identifier this repo refuses to store — so it is resolved
        # at runtime instead: ask the running shell which of its screens has
        # the geometry of PANEL_MAIN_CONNECTOR. Same trick panels.js uses for
        # the panels, and the reason a connector name is all config.sh holds.
        screen_idx="$(plasma_script "
            var r = -1;
            for (var i = 0; i < screenCount; i++) {
                var g = screenGeometry(i);
                if (g.x == $mx && g.y == $my && g.width == $mw && g.height == $mh) { r = i; break; }
            }
            print(r);" | tr -dc '0-9-')"

        # The activity is part of the match because a second activity gets its
        # own folder containment on the SAME screen — same plugin, same
        # lastScreen, different desktop. Matching without it would be a coin
        # flip the day ulu adds one.
        cont=""
        if [[ "$screen_idx" =~ ^[0-9]+$ ]]; then
            cont="$(awk -v want="$screen_idx" -v act="${ACTIVITY:-}" '
                /^\[Containments\]\[[0-9]+\]$/ {
                    c = $0; gsub(/[^0-9]/, "", c); plugin = ""; scr = ""; a = ""; next
                }
                /^\[/ { c = ""; next }
                c == "" { next }
                /^plugin=/     { plugin = substr($0, 8) }
                /^lastScreen=/ { scr    = substr($0, 12) }
                /^activityId=/ { a      = substr($0, 12) }
                plugin == "org.kde.plasma.folder" && scr == want && (act == "" || a == act) {
                    print c; exit
                }' "$applets")"
        fi

        if [[ -z "$cont" ]]; then
            echo "WARNING: no folder containment for $PANEL_MAIN_CONNECTOR (screen ${screen_idx:-?}) — icon position skipped"
        else
            # `positions` is {res: [a, b, url, col, row, url, col, row, …]}.
            # What the two LEADING values mean is not understood: a scripted
            # one-icon desktop carried "2","31", ulu's hand-arranged two-icon
            # desktop carried "5","31". Since Plasma writes them itself, they
            # are carried over from whatever is already there for this
            # resolution, and only invented when there is nothing to carry.
            existing="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cont" --group General \
                --key positions 2>/dev/null || true)"
            lead_a="2"; lead_b="31"
            if [[ "$existing" == *"\"$res\""* ]]; then
                IFS='"' read -r _ _ _ ex_a _ ex_b _ <<< "$existing"
                [[ -n "${ex_a:-}" ]] && lead_a="$ex_a"
                [[ -n "${ex_b:-}" ]] && lead_b="$ex_b"
            fi

            pos_items=""; chg_items=""; placed=""
            for icon in "${DESKTOP_ICONS[@]}"; do
                icon_name="${icon%%:*}"
                IFS=, read -r cell_col cell_row <<< "${icon##*:}"
                icon_url="desktop:/$icon_name"
                pos_items+=",\"$icon_url\",\"$cell_col\",\"$cell_row\""
                if [[ -n "$chg_items" ]]; then chg_items+=","; fi
                chg_items+="\"$icon_url\":[\"$res\",\"$cell_col\",\"$cell_row\"]"
                placed+=" $icon_name@$cell_col,$cell_row"
            done

            systemctl --user stop plasma-plasmashell.service || true
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cont" --group General \
                --key sortMode -- -1   # `--` or kwriteconfig6 reads -1 as an option
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cont" --group General \
                --key positions "{\"$res\":[\"$lead_a\",\"$lead_b\"$pos_items]}"
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cont" --group General \
                --key changedPositions "{$chg_items}"
            systemctl --user start plasma-plasmashell.service || true
            echo "desktop icons on $res (containment $cont):$placed"
        fi
    fi
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

    # Names are compared with grep -Fx rather than an SQL WHERE clause, which
    # keeps the playlist name out of the query string entirely. The row id it
    # yields IS interpolated below — that one comes from the database and is a
    # number.
    sb_playlist_id() {
        [[ -f "$SB_DB" ]] || return 0
        sqlite3 "file:$SB_DB?mode=ro" "SELECT ROWID || '|' || name FROM playlists;" 2>/dev/null \
            | awk -F'|' -v want="$PLAYLIST_NAME" '$2 == want { print $1; exit }'
    }
    sb_track_count() {
        local id; id="$(sb_playlist_id)"
        [[ -n "$id" ]] || { echo 0; return 0; }
        sqlite3 "file:$SB_DB?mode=ro" \
            "SELECT count(*) FROM playlist_items WHERE playlist = $id;" 2>/dev/null || echo 0
    }

    # Guard against a second import: stage 4 is single-shot, but it gets re-run
    # by hand during development, and `--create` would happily build a second
    # playlist with the same name every time.
    if [[ -n "$(sb_playlist_id)" ]]; then
        echo "playlist: '$PLAYLIST_NAME' already exists ($(sb_track_count) tracks) — not importing again"
    else
        # Strawberry MUST BE RUNNING for this. `--create` is an IPC message to a
        # live instance; with none there it is silently dropped — and still
        # exits 0. That is not theory: on the first real install this stage
        # reported "imported … as 'Default'" at 22:44 and left a database with
        # no such playlist, because Strawberry had never been started (LOG
        # 2026-07-31). ulu found it, not the log.
        if ! pgrep -x strawberry >/dev/null; then
            # NOT a plain `strawberry &`. This stage is a Type=oneshot unit, so
            # whatever is left in its cgroup is killed the moment ExecStart
            # returns — the instance would die together with the stage, quite
            # possibly before it had written anything. A transient scope is a
            # unit of its own and outlives us.
            #
            # And this branch is the NORMAL case, not the exception: measured
            # 2026-08-01, stage 4 reached this point at 12:13:45 while the
            # autostart entry from stage 3 only fired at 12:14:06. Stage 4 wins
            # that race by 21 seconds, so it starts the instance it needs.
            systemd-run --user --scope --quiet strawberry >/dev/null 2>&1 &
            for _ in $(seq 30); do pgrep -x strawberry >/dev/null && break; sleep 1; done
        fi

        # Waiting for the PROCESS is not enough — wait for the single-instance
        # SOCKET. KDSingleApplication listens on /tmp/kdsingleapp-<user>-<app>,
        # and a `--create` fired before that socket exists does not reach the
        # running instance at all: the second invocation finds no server, takes
        # itself for the first instance and starts a whole second Strawberry.
        # Reproduced 2026-08-01; the window is only ~60 ms wide, which is
        # exactly why it is worth closing rather than hoping.
        # `id -un` rather than $USER: this runs as a systemd user unit, and the
        # manager's environment is whatever the session imported into it.
        SB_SOCK="kdsingleapp-$(id -un)-strawberry"
        for _ in $(seq 30); do
            grep -q "$SB_SOCK" /proc/net/unix 2>/dev/null && break
            sleep 1
        done

        # RETRY, because reachable is not the same as ready. On 2026-08-01 the
        # message was delivered to a one-second-old instance on a virgin
        # database and simply vanished — no error, exit 0, no playlist. There is
        # no readiness signal for "Strawberry will now accept a playlist", so
        # the import is attempted repeatedly and VERIFIED against the database
        # after each attempt.
        #
        # A resend only happens while the playlist is ABSENT. That is the
        # duplicate guard: `--create` does not merge by name, so a second one
        # landing after the first would leave two playlists called the same
        # thing. Once the row exists, this only waits for its items — those are
        # written asynchronously and lag the row by a second or two.
        tracks=0
        for attempt in 1 2 3 4; do
            if [[ -z "$(sb_playlist_id)" ]]; then
                # Output is logged, never discarded: the 2026-08-01 failure left
                # not one line to work with because this call was silenced.
                sb_out="$(strawberry --create "$PLAYLIST_NAME" "$PLAYLIST_FILE" 2>&1)" || true
                [[ -n "$sb_out" ]] && echo "playlist: attempt $attempt — ${sb_out//$'\n'/ | }"
            fi
            for _ in $(seq 10); do
                tracks="$(sb_track_count)"
                [[ "$tracks" =~ ^[0-9]+$ ]] || tracks=0
                (( tracks > 0 )) && break
                sleep 1
            done
            (( tracks > 0 )) && break
        done

        if (( tracks > 0 )); then
            echo "playlist: imported $PLAYLIST_FILE as '$PLAYLIST_NAME' ($tracks tracks)"
        else
            echo "WARNING: '$PLAYLIST_NAME' is empty or absent after the import —"
            echo "         start Strawberry by hand and re-run this stage."
        fi
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
