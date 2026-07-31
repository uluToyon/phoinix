#!/usr/bin/env bash
# xlcore-backup.sh — copy the parts of ~/.xlcore that cannot be re-downloaded.
#
#   usage: xlcore-backup.sh <host>
#
# XIVLauncher's directory is ~2.7 GB, of which almost everything rebuilds
# itself: the Proton prefix, Dalamud, the .NET runtime, Dalamud's assets, and
# Browsingway's embedded browser. That last one is 623 MB under
# pluginConfigs/Browsingway/ — `cef-cache` really is cache, but `dependencies`
# is the CEF runtime Browsingway downloads and RUNS FROM (its helper processes
# were seen executing out of there). It is excluded because it re-downloads,
# not because it is disposable; the distinction matters if that download ever
# stops working. Browsingway's actual settings are the 2.8 KB
# Browsingway.json beside the directory, and that one IS carried. What does NOT
# come back on its own is roughly 80 MB:
#
#   launcher.ini        launcher settings — Proton/DXVK/Dalamud, and the paths
#   accounts.json       account identity — SECRET, hence 0600 and never the repo
#   dalamudConfig.json  the plugin PROFILE and the third-party repo list
#   dalamudUI.ini       Dalamud window layout
#   pluginConfigs/      per-plugin settings, minus Browsingway's cache directory
#   installedPlugins/   the plugin binaries themselves
#
# The binaries are carried deliberately (ulu's call): the profile alone would
# rely on Dalamud reinstalling from three third-party repos still being online
# in two years, and on reinstall behaviour that was never verified. 80 MB on a
# disk this repo never formats is the cheaper insurance.
#
# Target comes from hosts/<host>/config.sh (XLCORE_BACKUP_DIR) and lives next
# to the game, on the games disk — same anchor pattern as the WireGuard configs
# and the Strawberry playlist. Re-run this whenever plugins change.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: xlcore-backup.sh <host>   (e.g. desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

# The real directory is the XDG one; ~/.xlcore is only a compatibility symlink
# XIVLauncher-RB creates beside it. Reading through the link happens to work,
# but naming the truth here is what keeps the RESTORE from writing into a plain
# directory that shadows the link and that the launcher never reads — which is
# exactly what an early version of this did (found by testing, not by reading).
XL="$HOME/.local/share/dev.goats.xivlauncher"
[[ -n "${XLCORE_BACKUP_DIR:-}" ]] || { echo "ERROR: XLCORE_BACKUP_DIR not set for host $HOST"; exit 1; }
[[ -d "$XL" ]] || { echo "ERROR: no $XL — start XIVLauncher once first"; exit 1; }

# Never write into a missing mount: the games disk may be gone at the moment
# this runs, and creating the directory on the root filesystem would shadow the
# real one at the next boot. Same guard as the playlist export.
parent="$(dirname "$XLCORE_BACKUP_DIR")"
[[ -d "$parent" ]] || { echo "ERROR: $parent is not mounted — refusing to write"; exit 1; }

install -d "$XLCORE_BACKUP_DIR"

for f in launcher.ini launcherUI.ini dalamudConfig.json dalamudUI.ini; do
    [[ -f "$XL/$f" ]] && install -m644 "$XL/$f" "$XLCORE_BACKUP_DIR/$f"
done
# The one file that is a credential rather than a setting.
[[ -f "$XL/accounts.json" ]] && install -m600 "$XL/accounts.json" "$XLCORE_BACKUP_DIR/accounts.json"

# --delete so a plugin removed in Dalamud disappears here too; without it the
# backup would only ever grow and would reinstate things ulu deliberately got
# rid of.
rsync -a --delete --exclude='Browsingway/' \
      "$XL/pluginConfigs/" "$XLCORE_BACKUP_DIR/pluginConfigs/"
rsync -a --delete "$XL/installedPlugins/" "$XLCORE_BACKUP_DIR/installedPlugins/"

echo "xlcore backup -> $XLCORE_BACKUP_DIR ($(du -sh "$XLCORE_BACKUP_DIR" | cut -f1))"
echo "  plugins: $(ls "$XLCORE_BACKUP_DIR/installedPlugins" | wc -l)"
