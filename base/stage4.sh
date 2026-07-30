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
# Panel launchers, in display order. Setting this key explicitly is the whole
# point: while it is unset, the icons-only task manager shows its built-in
# default, which includes a Discover entry we deliberately do not install —
# it renders as a broken generic icon. The default lives compressed inside
# the applet's Qt resource, so there is nothing to grep and nothing to patch.
PANEL_LAUNCHERS='["applications:systemsettings.desktop","applications:org.kde.dolphin.desktop","applications:brave-browser.desktop"]'

# Kickoff favourites. Same story: Plasma's default list ships Discover AND
# Kontact, neither of which is installed here.
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

# ------------------------------------------------- 2. panel launchers
plasma_script '
panels().forEach(function(p) {
    p.widgets().forEach(function(w) {
        if (w.type.indexOf("icontasks") !== -1 || w.type === "org.kde.plasma.taskmanager") {
            w.currentConfigGroup = ["General"];
            w.writeConfig("launchers", '"$PANEL_LAUNCHERS"');
            w.reloadConfig();
            print("launchers set on " + w.type);
        }
    });
});'

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

# ------------------------------------------------- done
install -d "$STATE_DIR"
date -Is > "$MARKER"
echo "=== stage 4 done — marker: $MARKER ==="
echo "The systemd unit skips itself from now on; delete the marker to re-arm it."
