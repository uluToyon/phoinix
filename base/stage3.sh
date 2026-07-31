#!/usr/bin/env bash
# stage3.sh — runs on the BOOTED system as the regular user (NOT root).
#
#   usage: stage3.sh <host>        e.g. stage3.sh desktop
#
# Installs the whole decided package set (official + AUR via paru), fetches
# DZGUI, restores captured configs (monitor fix BEFORE first graphical
# login!), sets defaults and services. Re-runnable by design.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: stage3.sh <host>   (e.g. stage3.sh desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

[[ $EUID -ne 0 ]] || { echo "ERROR: run stage 3 as your user, not root (AUR builds refuse root)"; exit 1; }

exec > >(tee -a "$HOME/stage3.log") 2>&1

# Keep sudo alive for the whole run (long pacman/AUR phases).
# The refresh is the while CONDITION, not a command in the body, and that is
# the whole point: this subshell inherits `set -e`, so as a body command a
# single failed `sudo -n true` killed the keepalive silently and every later
# sudo prompted again. Verified in QEMU (three password prompts in one run),
# then reduced locally. As a condition, a lost ticket ends the loop cleanly
# instead of aborting it, and nothing else changes.
sudo -v
( while sudo -n true 2>/dev/null; do sleep 50; done ) &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

read_list() { grep -hvE '^\s*(#|$)' "$@" | awk '{print $1}'; }

# ------------------------------------------------- 1. official packages
mapfile -t PKGS < <(read_list "$REPO_DIR"/packages/{kde,gaming,audio,cli,apps}.txt)
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

# ------------------------------------------------- 2. paru bootstrap
# Built from SOURCE on purpose: paru links libalpm, and the prebuilt paru-bin
# breaks whenever Arch bumps the libalpm soname (bit us on first run).
# The --version probe also catches an installed-but-broken helper.
if ! paru --version &>/dev/null; then
    pacman -Qq paru-bin &>/dev/null && \
        sudo pacman -Rns --noconfirm paru-bin paru-bin-debug 2>/dev/null || true
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && makepkg -si --noconfirm )
    rm -rf "$tmp"
fi

# ------------------------------------------------- 3. AUR packages
mapfile -t AUR_PKGS < <(read_list "$REPO_DIR/packages/aur.txt")
# --sudoloop: paru refreshes sudo itself for the whole build run. Our keepalive
# above cannot cover this phase — makepkg's sudo calls do not necessarily share
# stage 3's terminal, and sudo's tickets are per-tty by default, so a ticket
# refreshed here is not the ticket makepkg is asked for.
paru -S --needed --noconfirm --sudoloop "${AUR_PKGS[@]}"

# ------------------------------------------------- 4. DZGUI (turnkey upstream)
# v7+ ships its own runtime; jq parses the GitHub releases API (see cli.txt).
if [[ ! -e "$HOME/Applications/dzgui/dzgui" ]]; then
    mkdir -p "$HOME/Applications/dzgui"
    url="$(curl -s https://api.github.com/repos/aclist/dztui/releases/latest \
          | jq -r '.assets[] | select(.name | test("tar")) | .browser_download_url' | head -1)"
    if [[ -n "$url" ]]; then
        curl -L "$url" | tar -xz -C "$HOME/Applications/dzgui" --strip-components=1
        echo ">> DZGUI installed to ~/Applications/dzgui (first run opens its setup wizard)"
    else
        echo ">> WARNING: could not resolve DZGUI release asset — install manually later"
    fi
fi

# ------------------------------------------------- 5. captured configs
# Source is the REPO, not the old system's backup on the Downloads disk.
# That backup made this entire block depend on a data disk, and the guard
# around it (`if [[ -d $BACKUP ]]`) skipped everything IN SILENCE when the
# disk was absent — monitor fix included, i.e. a clean stage-3 run followed by
# a black first login. The failure mode phoinix exists to prevent.
# See docs/LOG.md 2026-07-31. A missing source is a hard error now.
#
# hosts/<host>/home/ mirrors the destination paths 1:1, so where a file lands
# is readable from where it sits. Host-specific by nature: kwinoutputconfig
# is keyed to these four monitors' EDID hashes.
CFG="$REPO_DIR/hosts/$HOST/home"
[[ -d "$CFG" ]] || { echo "ERROR: no captured configs at $CFG"; exit 1; }

install -Dm644 "$CFG/.config/kwinoutputconfig.json" "$HOME/.config/kwinoutputconfig.json"
install -Dm644 "$CFG/.config/kwinrc"                "$HOME/.config/kwinrc"
install -Dm644 "$CFG/.config/kdeglobals"            "$HOME/.config/kdeglobals"

# Only the drop-in, never a copy of pipewire.conf itself: a file in
# ~/.config/pipewire/ shadows the packaged one completely, so a stale copy
# silently freezes out every future update to it (found exactly that on the
# live system — a verbatim 1.6.7 copy still shadowing 1.6.8).
install -Dm644 "$CFG/.config/pipewire/pipewire.conf.d/10-clock.conf" \
               "$HOME/.config/pipewire/pipewire.conf.d/10-clock.conf"

# wireplumber state: the analog-surround-51 pin and the -26dB route fix.
for f in default-profile default-routes default-nodes stream-properties; do
    install -Dm644 "$CFG/.local/state/wireplumber/$f" "$HOME/.local/state/wireplumber/$f"
done

# Distro-agnostic shell config (see DESIGN.md's dotfiles/ vs system/ split).
# The phoinix alias block is deliberately NOT in this file — section 6 owns it,
# so there is exactly one place where those aliases are defined.
install -Dm644 "$REPO_DIR/dotfiles/zshrc"    "$HOME/.zshrc"
install -Dm644 "$REPO_DIR/dotfiles/p10k.zsh" "$HOME/.p10k.zsh"

# The login greeter runs its own mini-Plasma with its own config — the
# monitor fix must land there too, or the FIRST login screen goes black.
# NOTE: never `getent passwd a b` under pipefail — it exits 2 if ANY key is
# missing, even with usable output (aborted a run once). One lookup per user.
for greeter_user in plasmalogin sddm; do
    greeter_home="$(getent passwd "$greeter_user" | cut -d: -f6)" || continue
    if [[ -f "$HOME/.config/kwinoutputconfig.json" ]]; then
        sudo install -Dm644 -o "$greeter_user" -g "$greeter_user" \
            "$HOME/.config/kwinoutputconfig.json" \
            "$greeter_home/.config/kwinoutputconfig.json"
    fi
done

# ------------------------------------------------- 6. Plasma settings (explicit)
# Written key by key rather than captured as whole files: each of these is a
# deliberate decision, and a kwriteconfig line can carry the reason next to it
# in a way a file snapshot never can. Also idempotent, and it merges instead of
# clobbering whatever else KDE stores in the same file.
# All of them are read at session start, so pre-first-login is early enough —
# unlike the panel work, none of this needs a running shell (that's stage 4).

# No screen locking at all: home desktop, the lock screen was only ever in the
# way. Autolock alone does not do it — the timeout has to go too, or the KCM
# keeps displaying a value that is not in effect.
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout 0

# German WITHOUT dead keys. `Use=true` is the switch that makes Plasma apply
# its own layout at all instead of deferring to the X11 system config from
# stage 2 — both carry the variant, so greeter and session agree.
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "$KEYMAP"
kwriteconfig6 --file kxkbrc --group Layout --key VariantList "$KEYMAP_VARIANT"

# NumLock on at session start (0 = on; enum confirmed against the GUI).
kwriteconfig6 --file kcminputrc --group Keyboard --key NumLock 0

# A desktop that never dims, never blanks, never suspends. The -1 timeouts are
# not decoration: leaving them at their defaults makes the KCM show idle times
# that no longer apply. Values are passed with `--` because they start with a
# dash and would otherwise be parsed as options.
kwriteconfig6 --file powerdevilrc --group AC --group Display --key DimDisplayWhenIdle false
kwriteconfig6 --file powerdevilrc --group AC --group Display --key DimDisplayIdleTimeoutSec -- -1
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutSec -- -1
kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
# 8 = shut down (enum confirmed against the GUI; KDE compiles it in).
kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key PowerButtonAction 8

# --- global shortcuts ------------------------------------------------------
# Only the deviations from the defaults, never the whole file. kglobalshortcutsrc
# is ~275 lines of mostly untouched defaults, and it contains
# `switch-to-activity-<UUID>` — an activity id regenerated on every install,
# which a wholesale capture would carry into the repo as a dead reference.
#
# The file conveniently states its own defaults: entries are
# `key=active,default,friendly`, so "what did ulu actually change" is
# computable at any time, no before/after snapshot needed. Two groups came out
# of that comparison.
#
# 1. Media keys belong to Strawberry. Plasma's own media controller claims the
#    same four keys and competes with it, so Plasma's are cleared. Note the
#    ones deliberately LEFT alone: pausemedia and the two seek shortcuts do not
#    collide. The default is written along in field 2 — that is the file's
#    format, not us hard-coding a value.
kwriteconfig6 --file kglobalshortcutsrc --group mediacontrol --key nextmedia      "none,Media Next,Media playback next"
kwriteconfig6 --file kglobalshortcutsrc --group mediacontrol --key playpausemedia "none,Media Play,Play/Pause media playback"
kwriteconfig6 --file kglobalshortcutsrc --group mediacontrol --key previousmedia  "none,Media Previous,Media playback previous"
kwriteconfig6 --file kglobalshortcutsrc --group mediacontrol --key stopmedia      "none,Media Stop,Stop media playback"

# 2. Spectacle: Meta+Shift+S moves from "open Spectacle" to "capture a region",
#    so the Windows key combination does what it does on Windows — drag the
#    region straight away instead of opening a window first. Spectacle ships
#    `Print,Meta+Shift+S` on _launch and `Meta+Shift+Print` on the region
#    action; this takes the combination off the first and adds it to the second.
#    Service-type entries use a different format from the rest of the file:
#    just `key=shortcut`, no default and no friendly name. Multiple shortcuts
#    for one action are TAB-separated (KConfig stores the tab escaped as \t).
#    The two `none` lines match Spectacle's own defaults — KDE writes the whole
#    group, and keeping them makes the group explicit rather than partial.
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key _launch                     "Print"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key RectangularRegionScreenShot "Meta+Shift+S"$'\t'"Meta+Shift+Print"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key CurrentMonitorScreenShot    "none"
kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key OpenWithoutScreenshot       "none"

# ------------------------------------------------- 7. application settings
# Per-application configuration that is plain KConfig and needs no running
# session. Applications whose config is not KConfig, or that only write on
# exit, are handled where they belong — see docs/SETTINGS.md.

# --- Dolphin ---------------------------------------------------------------
# Show hidden files. Finding where this lives took a while and is worth the
# comment: it is NOT in dolphinrc and NOT in kdeglobals (the
# `Show hidden files` there belongs to [KFileDialog Settings], i.e. the
# open/save dialogs). It is a *view property*, and with GlobalViewProps the
# view properties for every folder live in one file:
#
#   ~/.local/share/dolphin/view_properties/global/.directory
#   [Settings]
#   HiddenFilesShown=true
#
# Group [Settings], not [Dolphin] where the other view properties sit — taken
# from KDE's own schema, /usr/share/config.kcfg/dolphin_directoryviewpropertysettings.kcfg.
# Dolphin creates that directory but had never written the file, so the setting
# existed only inside the running process. Proven by counter-test: set to
# false, hidden files gone; back to true, hidden files there.
install -d "$HOME/.local/share/dolphin/view_properties/global"
kwriteconfig6 --file "$HOME/.local/share/dolphin/view_properties/global/.directory" \
    --group Settings --key HiddenFilesShown true

# One shared view configuration for all folders instead of per-folder files.
# The schema says this already defaults to true — written anyway, because the
# alternative scatters view settings across a tree of per-folder files that is
# bound to absolute paths and cannot be carried to a fresh install.
kwriteconfig6 --file dolphinrc --group General --key GlobalViewProps true

# Dolphin's window rule lives in stage 4, together with every other one — see
# the window-rules section there for why they cannot be split across stages.

# --- Konsole ---------------------------------------------------------------
# Start Konsole at login. This is not a Konsole setting at all: KDE's autostart
# is a directory of .desktop files, so the entry sits outside anything the
# application itself knows about. Copying the packaged .desktop rather than
# carrying our own copy in the repo keeps it correct across Konsole updates —
# KDE writes a normalised copy when you add it through the GUI, but the plain
# packaged file works identically and never goes stale.
install -Dm644 /usr/share/applications/org.kde.konsole.desktop \
               "$HOME/.config/autostart/org.kde.konsole.desktop"

# --- Strawberry ------------------------------------------------------------
# Also autostarted.
install -Dm644 /usr/share/applications/org.strawberrymusicplayer.strawberry.desktop \
               "$HOME/.config/autostart/org.strawberrymusicplayer.strawberry.desktop"

# The stereo -> 5.1 upmix, and the reason Strawberry is in the package set at
# all: it happens INSIDE the player and must never be done system-wide (ulu's
# hard requirement, docs/LOG.md 2026-07-30). Strawberry's own default is
# channels_enabled=false, so both keys together are the whole setting.
# Written key by key rather than by capturing strawberry.conf, which also
# happens to hold an OAuth access token for a streaming service — that file
# has no business in a public repo, and this way it never gets near one.
kwriteconfig6 --file "$HOME/.config/strawberry/strawberry.conf" \
    --group Backend --key channels_enabled true
kwriteconfig6 --file "$HOME/.config/strawberry/strawberry.conf" \
    --group Backend --key channels 6

# Playback mode: shuffle everything, repeat the whole playlist. Both are enums
# compiled into Strawberry; the values are confirmed against what ulu selected
# in the GUI, not guessed — shuffle_mode 1 = "Shuffle all",
# repeat_mode 3 = "Repeat playlist". Unlike the rest of strawberry.conf this
# section is written immediately rather than on exit.
kwriteconfig6 --file "$HOME/.config/strawberry/strawberry.conf" \
    --group PlaylistSequence --key shuffle_mode 1
kwriteconfig6 --file "$HOME/.config/strawberry/strawberry.conf" \
    --group PlaylistSequence --key repeat_mode 3
# Strawberry keeps its config user-readable only; kwriteconfig6 creates a fresh
# file with default permissions when none exists yet.
chmod 600 "$HOME/.config/strawberry/strawberry.conf"

# --- KeePassXC -------------------------------------------------------------
# NEVER capture keepassxc.ini as a whole: KeePassXC generates a KeeShare RSA
# PRIVATE KEY into it the first time that settings page is opened, together
# with a signer name. It sits there in plain text whether KeeShare is used or
# not — and here it is not, the share list is empty. Individual keys only, and
# the [KeeShare] section is never written or read by us.
kwriteconfig6 --file "$HOME/.config/keepassxc/keepassxc.ini" --group Browser --key Enabled true
kwriteconfig6 --file "$HOME/.config/keepassxc/keepassxc.ini" --group GUI --key ApplicationTheme dark
kwriteconfig6 --file "$HOME/.config/keepassxc/keepassxc.ini" --group GUI --key TrayIconAppearance monochrome-light

# Idle locking OFF — deliberate (ulu, 2026-07-31): single-user machine, and the
# screen lock and session lock are switched off for the same reason. Written
# explicitly because a fresh install would otherwise silently re-enable it, and
# an unexpectedly locking password manager is the kind of change that gets
# blamed on everything except the reinstall.
kwriteconfig6 --file "$HOME/.config/keepassxc/keepassxc.ini" --group Security --key LockDatabaseIdle false

# Preselect the database. This one deliberately writes STATE, not settings:
# KeePassXC keeps the recent-database list in ~/.cache, and on a fresh install
# there is nothing to preselect no matter which options are set. Seeded only
# when absent, so a database opened later is never overwritten by a re-run.
if [[ -n "${KEEPASS_DB:-}" ]] \
   && ! grep -q '^LastDatabases=' "$HOME/.cache/keepassxc/keepassxc.ini" 2>/dev/null; then
    install -d "$HOME/.cache/keepassxc"
    for k in LastDatabases LastOpenedDatabases LastActiveDatabase; do
        kwriteconfig6 --file "$HOME/.cache/keepassxc/keepassxc.ini" \
            --group General --key "$k" "$KEEPASS_DB"
    done
    echo ">> KeePassXC preselects $KEEPASS_DB"
fi

# NOTE: the music collection itself is NOT scriptable here. Strawberry stores
# collection directories in its database (~/.local/share/strawberry/), not in
# the config, and that database is state — absolute paths, rebuilt by a rescan.
# Adding the collection folder stays a manual post-install step (STATUS.md).

# ------------------------------------------------- 8. shell aliases (idempotent)
if ! grep -q "phoinix aliases" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'EOF'

# --- phoinix aliases (muscle memory maps to the decided tools) ---
alias nano='micro'
alias yay='paru'
EOF
fi

# ------------------------------------------------- 9. regional formats
# English UI, German formats. Two files on purpose, with different jobs:
#
#   environment.d — the one that ACTS. systemd's user manager reads it and
#     exports the variables into the session, so every process Plasma starts
#     inherits them. This mechanism is documented and verifiable.
#   plasma-localerc — the one that DISPLAYS. It is what the Region & Language
#     module reads back; without it the GUI would claim "American English"
#     while the session runs on German formats.
#
# LC_MESSAGES is deliberately absent — that would translate the interface.
# LC_COLLATE too: German sort order changes shell globs and `sort` output,
# which is a poor trade for a subtly different file listing.
install -d "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/10-phoinix-locale.conf" << EOF
# Written by phoinix stage3 — regional formats (UI language stays $LOCALE)
LANG=$LOCALE
LC_TIME=$FORMAT_LOCALE
LC_NUMERIC=$FORMAT_LOCALE
LC_MONETARY=$FORMAT_LOCALE
LC_MEASUREMENT=$FORMAT_LOCALE
LC_PAPER=$FORMAT_LOCALE
LC_ADDRESS=$FORMAT_LOCALE
LC_NAME=$FORMAT_LOCALE
LC_TELEPHONE=$FORMAT_LOCALE
EOF

cat > "$HOME/.config/plasma-localerc" << EOF
[Formats]
LANG=$LOCALE
LC_TIME=$FORMAT_LOCALE
LC_NUMERIC=$FORMAT_LOCALE
LC_MONETARY=$FORMAT_LOCALE
LC_MEASUREMENT=$FORMAT_LOCALE
useDetailed=true
EOF

# ------------------------------------------------- 10. defaults & services
xdg-mime default brave-browser.desktop application/pdf || true

sudo systemctl enable bluetooth cups power-profiles-daemon

# ------------------------------------------------- 11. arm stage 4 (post-login)
# Plasma settings that can only be made while its shell runs — see stage4.sh.
# Enabled by symlink instead of `systemctl --user enable`: stage 3 runs from a
# TTY where a user bus is not guaranteed, and the symlink is what enable does.
USER_UNIT_DIR="$HOME/.config/systemd/user"
install -d "$USER_UNIT_DIR/plasma-workspace.target.wants"
sed -e "s|@REPO_DIR@|$REPO_DIR|g" -e "s|@HOST@|$HOST|g" \
    "$REPO_DIR/system/user/phoinix-stage4.service" \
    > "$USER_UNIT_DIR/phoinix-stage4.service"
ln -sf ../phoinix-stage4.service \
    "$USER_UNIT_DIR/plasma-workspace.target.wants/phoinix-stage4.service"

# Export the Strawberry playlist on session exit — same symlink reasoning as
# above. Wanted by graphical-session.target so it is stopped (and therefore
# runs its ExecStop) when the session ends.
sed -e "s|@REPO_DIR@|$REPO_DIR|g" -e "s|@HOST@|$HOST|g" \
    "$REPO_DIR/system/user/phoinix-playlist-export.service" \
    > "$USER_UNIT_DIR/phoinix-playlist-export.service"
install -d "$USER_UNIT_DIR/graphical-session.target.wants"
ln -sf ../phoinix-playlist-export.service \
    "$USER_UNIT_DIR/graphical-session.target.wants/phoinix-playlist-export.service"

# Drop-in against the 40s shutdown hang (plasmashell outlives its compositor
# and never processes SIGTERM) — rationale in the file itself.
install -d "$USER_UNIT_DIR/plasma-plasmashell.service.d"
install -m644 "$REPO_DIR/system/user/plasma-plasmashell.service.d/phoinix-shutdown.conf" \
    "$USER_UNIT_DIR/plasma-plasmashell.service.d/phoinix-shutdown.conf"

# Graphical login LAST — everything above (esp. the monitor fix) must exist
# before PLM ever starts. Look only in systemd/system/ — the package also
# ships a D-Bus .service file that a naive grep matches first (bit us once).
PLM_UNIT="$(pacman -Qlq plasma-login-manager | grep 'systemd/system/.*\.service$' | xargs -r -n1 basename | head -1)"
[[ -n "$PLM_UNIT" ]] || { echo "ERROR: no systemd unit in plasma-login-manager"; exit 1; }
sudo systemctl enable "$PLM_UNIT"
sudo systemctl set-default graphical.target

# ------------------------------------------------- 12. disarm the login hook
# The ~/.zprofile block stage 2 wrote checks for this marker, so stage 3 runs
# exactly once out of a login. Written LAST, so a stage 3 that died halfway is
# retried at the next login instead of being skipped. Deleting the marker
# re-arms it — same contract as stage 4's.
install -d "$HOME/.local/state/phoinix"
: > "$HOME/.local/state/phoinix/stage3.done"

echo
echo "stage 3 done. Reboot (or 'sudo systemctl start $PLM_UNIT') to reach KDE."
echo "Manual checklist afterwards: docs/STATUS.md → 'Post-install manual steps'."
