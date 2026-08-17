#!/usr/bin/env bash
# xlcore-backup.sh — copy the parts of ~/.xlcore that cannot be re-downloaded.
#
#   usage: xlcore-backup.sh <host>
#
# XIVLauncher's directory is ~2.7 GB, of which almost everything rebuilds
# itself: the Proton prefix, Dalamud, the .NET runtime, Dalamud's assets, and
# Browsingway's embedded browser. That last one is 797 MB under
# pluginConfigs/Browsingway/ — `dependencies` (363 MB) is the CEF runtime
# Browsingway downloads and RUNS FROM (its helper processes were seen executing
# out of there), and `cef-cache` (434 MB) is the browser profile. Both are
# excluded because they re-download, not because they are disposable; the
# distinction matters if that download ever stops working.
#
# ONE EXCEPTION inside cef-cache, and it is not an optimisation but a
# correction. This header used to claim "cef-cache really is cache". It is not.
# Browsingway gives every overlay its own Chromium profile, named after the
# overlay, and each profile's `Local Storage` holds THAT OVERLAY'S SETTINGS —
# MopiMopi's configuration, cactbot's UI options, Horizoverlay's layout. Found
# on 2026-08-17 while reading MopiMopi's stored language out of that very
# database. Excluding it would have cost every overlay setting at the next
# reinstall, silently, with the browser looking freshly installed rather than
# broken. Carrying it costs 316 KB against 797 MB, so the ratio never made the
# old decision worth defending.
#
# Caveat on those files: they are LevelDB databases, and this script runs at
# session exit, normally with the game already closed. If FFXIV is somehow
# still running, a database can be copied mid-write. The overlay then falls
# back to its defaults on restore — the same outcome as not carrying it at all,
# so the risk is worth taking rather than guarding against.
#
# What does NOT come back on its own is roughly 80 MB:
#
#   launcher.ini        launcher settings — Proton/DXVK/Dalamud, and the paths
#   accounts.json       account identity — SECRET, hence 0600 and never the repo
#   dalamudConfig.json  the plugin PROFILE and the third-party repo list
#   dalamudUI.ini       Dalamud window layout
#   pluginConfigs/      per-plugin settings, minus Browsingway's bulk
#   .../Browsingway/cef-cache/*/Local Storage/   the overlays' own settings
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

# The exclude above protects the backup's own Browsingway tree from --delete,
# which is what lets this second pass fill it in. Only `Local Storage` is
# carried — the overlays' settings, see the header. --prune-empty-dirs is not
# cosmetic: without it the backup would mirror every one of the ~40 profile
# and cache directories just to reach the handful that hold anything.
CEF="$XL/pluginConfigs/Browsingway/cef-cache"
if [[ -d "$CEF" ]]; then
    # rsync creates only the LAST component of a destination path. The
    # Browsingway level above it never exists on the first run — the pass above
    # excludes exactly that directory — so rsync would abort with ENOENT
    # instead of creating it. Measured, not guessed.
    install -d "$XLCORE_BACKUP_DIR/pluginConfigs/Browsingway/cef-cache"
    rsync -a --delete --prune-empty-dirs \
          --include='*/' --include='Local Storage/***' --exclude='*' \
          "$CEF/" "$XLCORE_BACKUP_DIR/pluginConfigs/Browsingway/cef-cache/"
fi

rsync -a --delete "$XL/installedPlugins/" "$XLCORE_BACKUP_DIR/installedPlugins/"

echo "xlcore backup -> $XLCORE_BACKUP_DIR ($(du -sh "$XLCORE_BACKUP_DIR" | cut -f1))"
echo "  plugins: $(ls "$XLCORE_BACKUP_DIR/installedPlugins" | wc -l)"
