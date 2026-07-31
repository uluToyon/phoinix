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
mapfile -t PKGS < <(read_list "$REPO_DIR"/packages/{kde,gaming,audio,cli,apps,dev}.txt)
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

# Whether a host HAS captured configs is DECLARED in hosts/<host>/config.sh —
# never inferred from whether the directory happens to be there. Inferring it
# would reopen the exact hole this hard error was written to close: a host
# whose captured configs are missing installs to a clean finish and then goes
# black at the first graphical login. An undeclared host is an error too, so
# adding one is a decision rather than an omission.
case "${CAPTURED_CONFIGS:-}" in
1)
    [[ -d "$CFG" ]] || { echo "ERROR: CAPTURED_CONFIGS=1 but nothing at $CFG"; exit 1; }

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
    ;;
0)
    echo ">> $HOST declares no captured configs — skipping monitor fix and audio state."
    ;;
*)
    echo "ERROR: hosts/$HOST/config.sh must set CAPTURED_CONFIGS to 1 or 0"
    exit 1
    ;;
esac

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

# --- KeePassXC autostart ---------------------------------------------------
# Same mechanism as Konsole and Strawberry, packaged file rather than the copy
# KDE writes. Deliberately NOT minimised to the tray (ulu's call): he wants the
# window visible at login, and stage 4 gives it the lower right quarter of DP-2.
install -Dm644 /usr/share/applications/org.keepassxc.KeePassXC.desktop \
               "$HOME/.config/autostart/org.keepassxc.KeePassXC.desktop"

# --- Discord ---------------------------------------------------------------
# Autostart, and that is the ONLY thing about Discord this repo can carry.
# Everything ulu configures in its UI — theme, notifications, audio devices,
# keybinds, privacy — lives server-side in his account and returns on login,
# exactly like Brave's sync chain. Its settings.json holds window bounds, a
# background colour and Discord's own experiment flags: not one decision.
# The entry KDE writes when you tick the box carries the same keys and values
# as the packaged file — only alphabetically reordered — so the packaged file
# is what gets installed and cannot go stale. "Start minimized" would be a
# flag appended to Exec here; ulu did not want it.
install -Dm644 /usr/share/applications/discord.desktop \
               "$HOME/.config/autostart/discord.desktop"

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

# --- LibreOffice -----------------------------------------------------------
# One decision came out of the settings round: the dark appearance, chosen
# explicitly rather than left on "System". Both keys are written because they
# corroborate each other — ApplicationAppearance is the setting, CurrentColorScheme
# is the document colour scheme that follows from it.
#
# LibreOffice keeps everything in a single registrymodifications.xcu, which
# also accumulates recently opened documents with full paths — so the file is
# never captured, only these two items are authored.
#
# SEEDED, not edited, and only when the file is absent. The profile does not
# exist until LibreOffice has run once, i.e. never at stage 3 time on a fresh
# install. Verified rather than assumed: a hand-written minimal file placed
# before the first start is read and kept — LibreOffice merges its own entries
# in around it (516 -> 767 bytes in the test, both values intact). The absence
# guard matters as much as the seeding: an existing profile is ulu's, and
# overwriting it would discard everything he has set since.
LO_PROFILE="$HOME/.config/libreoffice/4/user/registrymodifications.xcu"
if [[ ! -e "$LO_PROFILE" ]]; then
    install -d "$(dirname "$LO_PROFILE")"
    cat > "$LO_PROFILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<item oor:path="/org.openoffice.Office.Common/Appearance"><prop oor:name="ApplicationAppearance" oor:op="fuse"><value>2</value></prop></item>
<item oor:path="/org.openoffice.Office.UI/ColorScheme"><prop oor:name="CurrentColorScheme" oor:op="fuse"><value>COLOR_SCHEME_LIBREOFFICE_DARK</value></prop></item>
</oor:items>
EOF
    echo "libreoffice: profile seeded (dark appearance)"
else
    echo "libreoffice: profile exists — left alone"
fi

# --- mpc-qt ----------------------------------------------------------------
# First, a repair. mpc-qt 26.07 segfaults in QScreen::availableGeometry() out
# of main when settings.json exists and geometry_v2.json does not — and the
# crashing run leaves exactly that state behind, so it never starts again. Any
# interrupted first launch is enough to create it. Removing settings.json ends
# the loop; a clean run then writes all six profile files.
MPC_DIR="$HOME/.config/mpc-qt"
if [[ -f "$MPC_DIR/settings.json" && ! -f "$MPC_DIR/geometry_v2.json" ]]; then
    rm -f "$MPC_DIR/settings.json"
    echo "mpc-qt: removed a half-written profile that would have segfaulted on start"
fi

# The settings themselves are written INTO an existing profile, never seeded.
# Seeding was tested three ways and is unsafe: a two-key settings.json alone
# crashes, and so does one paired with an empty geometry_v2.json — the crash
# needs a real geometry entry, which would mean writing this desk's window
# coordinates into the repo. The contrast with LibreOffice, where seeding was
# verified to work, is worth keeping in mind: same question, opposite answer,
# and only the measurement told them apart.
if [[ -f "$MPC_DIR/settings.json" ]]; then
    mpc_tmp="$(mktemp)"
    jq '.playbackAudioTracks = "eng,en" | .playbackSubtitleTracks = "none,no"' \
        "$MPC_DIR/settings.json" > "$mpc_tmp" && mv "$mpc_tmp" "$MPC_DIR/settings.json"
    echo "mpc-qt: track preferences written (English audio, no subtitles)"
else
    echo "mpc-qt: no profile yet — start it once, then re-run stage 3."
fi

# ------------------------------------------------- 7b. ProtonVPN split tunnel
# Stage 2 built the system side (group, nftables rule, resolved). This is the
# user side: import the connections, teach them not to take over the machine,
# and point qBittorrent through them.
#
# The whole design in one sentence: the tunnel is NOT the default route, so
# nothing uses it by accident, and qBittorrent is forced into it by a kernel
# rule rather than asked politely by a checkbox.
if [[ -n "${VPN_CONFIG_DIR:-}" ]]; then
    if [[ ! -d "$VPN_CONFIG_DIR" ]]; then
        # Loud, not fatal. The disk holding the configs may simply not be
        # mounted yet, and that must not abort an install — but it must also
        # never pass unnoticed, or the machine comes up with qBittorrent
        # blocked and no visible reason (the nftables rule fails CLOSED).
        echo "WARNING: $VPN_CONFIG_DIR is not there — no VPN connection imported."
        echo "         qBittorrent will be unable to reach the network until it is."
    else
        shopt -s nullglob
        vpn_configs=("$VPN_CONFIG_DIR"/*.conf)
        shopt -u nullglob
        (( ${#vpn_configs[@]} )) || echo "WARNING: no *.conf in $VPN_CONFIG_DIR"

        # NetworkManager derives the interface name from the FILE NAME and
        # rejects anything that is not a valid one — at most 15 characters.
        # Proton's downloads are longer than that ("The name of the WireGuard
        # config must be a valid interface name followed by .conf"), so the
        # import cannot read them where they lie. Renaming ulu's files would be
        # the wrong fix: they are his, and the next download would bring the
        # problem straight back. Each is therefore imported through a copy
        # named after VPN_INTERFACE — which also hands us the interface name we
        # wanted anyway, instead of having to correct it afterwards.
        # The copy carries a private key, so it lives in a 0700 directory and
        # is deleted immediately after the loop.
        vpn_tmp="$(mktemp -d)"
        chmod 700 "$vpn_tmp"

        for cfg in "${vpn_configs[@]}"; do
            name="$(basename "$cfg" .conf)"
            install -m600 "$cfg" "$vpn_tmp/$VPN_INTERFACE.conf"

            # Re-runnable: drop both the final name and the transient one, or a
            # second run would collect "<name> 1" duplicates.
            for stale in "$name" "$VPN_INTERFACE"; do
                if nmcli -g NAME connection show | grep -Fxq "$stale"; then
                    sudo nmcli connection delete "$stale" >/dev/null
                fi
            done

            sudo nmcli connection import type wireguard file "$vpn_tmp/$VPN_INTERFACE.conf" >/dev/null

            # The import named it after the file; give it back the name of the
            # server it actually is, so the applet shows CH and NL rather than
            # two identical entries. BOTH keep the same interface name — only
            # one can be up at a time, and that is what lets qBittorrent's
            # binding and the nftables rule stay valid whichever is active.
            # Routing, and this is where the first version was simply wrong.
            # `never-default` alone does NOT keep a WireGuard connection out of
            # the way: NetworkManager sees AllowedIPs 0.0.0.0/0 and turns on its
            # own "auto default route", which installs a private table plus
            # `suppress_prefixlength 0` rules that capture EVERYTHING. Measured
            # on the live desktop: the whole machine was running through the
            # tunnel while `ipv4.never-default` read `yes`.
            # So auto-default-route is switched off, and the tunnel's default
            # route is confined to its own table, reachable only by packets the
            # nftables chain has marked. Nothing reaches it by accident, and
            # qBittorrent is routed there rather than trusted to bind itself.
            sudo nmcli connection modify "$VPN_INTERFACE" \
                connection.id "$name" \
                connection.autoconnect no \
                wireguard.ip4-auto-default-route no \
                wireguard.ip6-auto-default-route no \
                wireguard.fwmark "$VPN_MARK_WG" \
                ipv4.never-default no \
                ipv6.never-default no \
                ipv4.route-table "$VPN_ROUTE_TABLE" \
                ipv6.route-table "$VPN_ROUTE_TABLE" \
                ipv4.routing-rules "priority 100 fwmark $VPN_MARK_APP table $VPN_ROUTE_TABLE" \
                ipv6.routing-rules "priority 100 fwmark $VPN_MARK_APP table $VPN_ROUTE_TABLE"
            echo "vpn: imported $name -> $VPN_INTERFACE"
        done

        rm -rf "$vpn_tmp"

        # Exactly one connection autoconnects, otherwise both would race for
        # the same interface name at boot. The first file alphabetically is an
        # arbitrary but STABLE choice; switching country is one click in the
        # applet and does not need the repo's permission.
        if (( ${#vpn_configs[@]} )); then
            first="$(basename "${vpn_configs[0]}" .conf)"
            sudo nmcli connection modify "$first" connection.autoconnect yes
            echo "vpn: $first autoconnects"
        fi
    fi

    # --- qBittorrent -------------------------------------------------------
    # NOT kwriteconfig6. qBittorrent.conf is Qt's QSettings format, where the
    # backslash in `Session\Interface` is a group separator written as ONE
    # character. KConfig treats a backslash as an escape and doubles it on
    # save — and because it rewrites the whole file, it doubled qBittorrent's
    # OWN keys too. The result looked plausible and was inert: qBittorrent
    # never saw a single setting we wrote, the WebUI was never enabled, and
    # the interface was never bound. Discovered only when qBittorrent rewrote
    # the file itself and every backslash came back single.
    #
    # So the writer below edits the file line by line and touches nothing
    # else. That matters beyond the escaping: this file also holds @ByteArray
    # blobs of window geometry, which any full-file rewriter would re-encode.
    QBT_CONF="$HOME/.config/qBittorrent/qBittorrent.conf"
    [[ -f "$QBT_CONF" ]] || install -Dm600 /dev/null "$QBT_CONF"

    # A running qBittorrent holds its settings in memory and writes the whole
    # file when it exits, so anything written underneath it is discarded
    # without a word. On a fresh install it is not running; on a re-run it very
    # well might be — and silently losing the edit is exactly the class of
    # failure this repo keeps tripping over.
    if pgrep -x qbittorrent >/dev/null; then
        echo "WARNING: qBittorrent is running — it will overwrite these settings on exit."
        echo "         Quit it (File > Exit, not just the window) and re-run stage 3."
    fi

    qbt_set() {   # $1 = section, $2 = key, $3 = value
        local tmp; tmp="$(mktemp)"
        QBT_SEC="$1" QBT_KEY="$2" QBT_VAL="$3" awk '
            BEGIN { want = "[" ENVIRON["QBT_SEC"] "]"; key = ENVIRON["QBT_KEY"];
                    val = ENVIRON["QBT_VAL"]; done = 0; incur = 0 }
            /^\[/ {
                if (incur && !done) { print key "=" val; done = 1 }
                incur = ($0 == want)
            }
            incur && index($0, key "=") == 1 { if (!done) { print key "=" val; done = 1 } next }
            { print }
            END {
                if (incur && !done) { print key "=" val; done = 1 }
                if (!done) { print ""; print want; print key "=" val }
            }
        ' "$QBT_CONF" > "$tmp"
        mv "$tmp" "$QBT_CONF"
        chmod 600 "$QBT_CONF"
    }

    # Bind to the tunnel. The FIRST of two lines, never the guarantee: it makes
    # qBittorrent behave correctly, while the nftables rule makes it unable to
    # misbehave. Both key spellings, because qBittorrent has used both across
    # versions and writing only one leaves the setting half-applied.
    qbt_set BitTorrent 'Session\Interface'     "$VPN_INTERFACE"
    qbt_set BitTorrent 'Session\InterfaceName' "$VPN_INTERFACE"

    # Paths: ulu's, on a data disk. Default would be ~/Downloads, i.e. on the
    # system disk that every reinstall wipes.
    qbt_set BitTorrent 'Session\DefaultSavePath' "$QBT_SAVE_PATH"
    qbt_set BitTorrent 'Session\TempPath'        "$QBT_TEMP_PATH"
    qbt_set BitTorrent 'Session\TempPathEnabled' 'true'

    # Two notifications off (both default to true), and the legal notice
    # accepted — that last one is pure phoinix: it removes a dialog that would
    # otherwise greet every fresh install before qBittorrent will start.
    qbt_set GUI         'DownloadTrackerFavicon'    'false'
    qbt_set Application 'GUI\Notifications\TorrentAdded' 'false'
    qbt_set LegalNotice 'Accepted'                  'true'

    # No WebUI, deliberately (ulu's call, 2026-07-31). It only ever existed to
    # let a port-forwarding service hand qBittorrent a new port, since
    # qBittorrent does not re-read its config while running. Both of the
    # servers in use refuse NAT-PMP anyway, so the whole chain was dead weight
    # — and dropping it removes a permanently running service and an
    # unauthenticated API on localhost along with it. Note for a future
    # revival: qBittorrent will not enable the WebUI at all until credentials
    # exist ("WebUI: Credentials are not set"), even with LocalHostAuth off, so
    # it would need a random password generated at install time whose PBKDF2
    # hash is written here — never a password in the repo.

    # Launcher override: the packaged entry starts qBittorrent with ulu's
    # normal groups, and the nftables rule would never match it. Copied from
    # the packaged file and only the Exec line rewritten, so icon, categories
    # and MIME associations stay whatever the package says.
    pkg_desktop="/usr/share/applications/org.qbittorrent.qBittorrent.desktop"
    if [[ -f "$pkg_desktop" ]]; then
        install -d "$HOME/.local/share/applications"
        sed -E "s|^Exec=.*|Exec=$REPO_DIR/scripts/qbittorrent-vpn.sh $HOST %U|" \
            "$pkg_desktop" > "$HOME/.local/share/applications/org.qbittorrent.qBittorrent.desktop"
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        echo "vpn: qBittorrent launcher runs under group $VPN_GROUP"

        # Autostart, from OUR entry rather than the packaged one — this is the
        # one place where the difference is load-bearing. KDE's autostart is a
        # directory of .desktop files, so an entry copied from the package
        # would start qBittorrent outside the group at every login, with the
        # kernel rule matching nothing and the tunnel silently unused.
        install -Dm644 "$HOME/.local/share/applications/org.qbittorrent.qBittorrent.desktop" \
            "$HOME/.config/autostart/org.qbittorrent.qBittorrent.desktop"
        echo "qbittorrent: autostart entry installed (wrapped)"
    else
        echo "WARNING: $pkg_desktop missing — qBittorrent launcher NOT wrapped"
    fi

    # Clean up the port-forwarding service if an earlier run installed it.
    # Removed 2026-07-31 — see the WebUI note above. A stage that drops a
    # feature has to take its leftovers with it, or a re-run leaves a unit
    # nobody maintains running on every login.
    rm -f "$HOME/.config/systemd/user/phoinix-portforward.service" \
          "$HOME/.config/systemd/user/default.target.wants/phoinix-portforward.service"
fi

# --- XIVLauncher / Dalamud --------------------------------------------------
# Restored from the games disk (scripts/xlcore-backup.sh writes it). Roughly
# 80 MB: launcher settings, the Dalamud plugin profile with its third-party
# repos, per-plugin settings, and the plugin binaries. The other 2.6 GB of
# ~/.xlcore — Proton prefix, Dalamud, runtime, assets, Browsingway's embedded
# browser — re-downloads itself and is deliberately not carried.
#
# Per-file and per-tree, never wholesale: anything already present belongs to a
# launcher that has run since, and overwriting it would discard exactly what
# the backup exists to protect. On a fresh install nothing is present and the
# whole set lands.
if [[ -n "${XLCORE_BACKUP_DIR:-}" ]]; then
    # The XDG path, NOT ~/.xlcore — that is only a compatibility symlink
    # XIVLauncher-RB creates. Restoring into a real ~/.xlcore directory would
    # shadow the link with files the launcher never reads. Found by testing a
    # seeded restore, which is the only way it could have been found.
    XL="$HOME/.local/share/dev.goats.xivlauncher"
    if [[ ! -d "$XLCORE_BACKUP_DIR" ]]; then
        echo "WARNING: $XLCORE_BACKUP_DIR missing — XIVLauncher starts unconfigured."
        echo "         Not fatal: it will simply ask for the account again."
    else
        install -d "$XL"
        for f in launcher.ini launcherUI.ini dalamudConfig.json dalamudUI.ini; do
            [[ -f "$XLCORE_BACKUP_DIR/$f" && ! -e "$XL/$f" ]] && \
                install -m644 "$XLCORE_BACKUP_DIR/$f" "$XL/$f"
        done
        # The credential keeps its restrictive mode across the copy.
        [[ -f "$XLCORE_BACKUP_DIR/accounts.json" && ! -e "$XL/accounts.json" ]] && \
            install -m600 "$XLCORE_BACKUP_DIR/accounts.json" "$XL/accounts.json"

        for d in pluginConfigs installedPlugins; do
            if [[ -d "$XLCORE_BACKUP_DIR/$d" && ! -d "$XL/$d" ]]; then
                cp -a "$XLCORE_BACKUP_DIR/$d" "$XL/$d"
            fi
        done
        echo "xlcore: restored from $XLCORE_BACKUP_DIR (existing files left alone)"
    fi
fi

# --- XIVLauncher desktop link ----------------------------------------------
# A SYMLINK, not a copy — that is what KDE creates when an entry is dragged
# from the menu onto the desktop, and it means the launcher's own .desktop
# stays the single source (icon, categories, StartupWMClass all follow updates).
# Its POSITION is Plasma state and belongs to stage 4, which can resolve the
# containment at runtime.
if [[ -n "${XIVLAUNCHER_DESKTOP:-}" && -f "$XIVLAUNCHER_DESKTOP" ]]; then
    install -d "$HOME/Desktop"
    ln -sf "$XIVLAUNCHER_DESKTOP" "$HOME/Desktop/$(basename "$XIVLAUNCHER_DESKTOP")"
    echo "desktop: XIVLauncher link placed"
elif [[ -n "${XIVLAUNCHER_DESKTOP:-}" ]]; then
    echo "WARNING: $XIVLAUNCHER_DESKTOP missing — no desktop link created"
fi

# --- Monitor switch icon ----------------------------------------------------
# Unlike XIVLauncher's, this .desktop does not exist until we make one: it has
# to name the repo path and the host, so it is generated from the template with
# the same substitution the user services use. It points INTO the repo on
# purpose — that is the live working copy on this machine, so editing the
# script takes effect on the next click with no reinstall step to forget.
if [[ ${#MONITOR_SWITCH[@]} -gt 0 ]]; then
    apps_dir="$HOME/.local/share/applications"
    install -d "$apps_dir" "$HOME/Desktop"
    sed -e "s|@REPO_DIR@|$REPO_DIR|g" -e "s|@HOST@|$HOST|g" \
        "$REPO_DIR/system/applications/phoinix-monitor-switch.desktop" \
        > "$apps_dir/phoinix-monitor-switch.desktop"
    chmod 644 "$apps_dir/phoinix-monitor-switch.desktop"
    ln -sf "$apps_dir/phoinix-monitor-switch.desktop" \
        "$HOME/Desktop/phoinix-monitor-switch.desktop"
    echo "desktop: monitor switch link placed"
fi

# --- DZGUI -----------------------------------------------------------------
# Seeded, and seeding here is worth more than usual: without it the first run
# opens a wizard that asks for a Steam Web API key, which means fetching it
# from steamcommunity.com and typing 32 characters after every reinstall.
# With the config in place the wizard does not run at all — verified by
# seeding it on the live machine, where DZGUI accepted the file unchanged and
# added not a single field of its own.
#
# The secret and the server list come from a data disk (DZGUI_PRIVATE_FILE),
# never from the repo. Everything else is authored here.
#
# Seeded ONLY when absent: an existing config is ulu's, and DZGUI writes his
# server list into it as he plays. Overwriting that would discard exactly the
# thing the private file exists to preserve.
if [[ -n "${DZGUI_PRIVATE_FILE:-}" ]]; then
    DZGUI_CONF="$HOME/.config/dzgui/config.json"
    if [[ -e "$DZGUI_CONF" ]]; then
        echo "dzgui: config exists — left alone"
    elif [[ ! -f "$DZGUI_PRIVATE_FILE" ]]; then
        # Loud, not fatal: the data disk may simply not be mounted. Without it
        # DZGUI still works, it just asks for the API key again.
        echo "WARNING: $DZGUI_PRIVATE_FILE missing — DZGUI will run its wizard and ask"
        echo "         for a Steam API key. Nothing else breaks."
    else
        install -d "$(dirname "$DZGUI_CONF")"
        jq -n --slurpfile priv "$DZGUI_PRIVATE_FILE" \
              --arg name "$DZGUI_NAME" --arg steam "$HOME/.local/share/Steam" \
              '{fav_server:"", fav_label:"", name:$name, fullscreen:false,
                default_steam_path:$steam, client:"steam", use_miles:false,
                start_tab:1} + $priv[0]' > "$DZGUI_CONF"
        chmod 600 "$DZGUI_CONF"
        echo "dzgui: config seeded from $DZGUI_PRIVATE_FILE (no wizard, no API key retyping)"
    fi
fi

# --- Steam non-Steam shortcuts ---------------------------------------------
# Restored, but only when Steam has a place to put it. `userdata/<id>/config`
# exists solely after a Steam login, which is a manual post-install step — so
# on a fresh install this finds nothing and says so, and the SECOND stage 3 run
# (after logging in) does the work. No separate command to remember.
#
# Never overwrites: an existing shortcuts.vdf is Steam's, and it holds every
# non-Steam game ulu has added since. Losing those to restore one is the wrong
# trade — and Steam rewrites this file when it exits, so a restore underneath a
# running Steam would be discarded anyway.
if [[ -n "${STEAM_SHORTCUTS_FILE:-}" && -f "$STEAM_SHORTCUTS_FILE" ]]; then
    steam_cfg=""
    for d in "$HOME/.local/share/Steam/userdata"/*/config; do
        [[ -d "$d" ]] && { steam_cfg="$d"; break; }
    done
    if [[ -z "$steam_cfg" ]]; then
        echo "steam: no userdata yet — log in once, then re-run stage 3 to restore shortcuts"
    elif [[ -e "$steam_cfg/shortcuts.vdf" ]]; then
        echo "steam: shortcuts.vdf exists — left alone"
    elif pgrep -x steam >/dev/null; then
        echo "WARNING: Steam is running — it rewrites shortcuts.vdf on exit."
        echo "         Quit Steam and re-run stage 3 to restore the shortcuts."
    else
        install -Dm644 "$STEAM_SHORTCUTS_FILE" "$steam_cfg/shortcuts.vdf"
        echo "steam: non-Steam shortcuts restored"
    fi
fi

# ------------------------------------------------- 7c. printer
# CUPS is enabled in section 10; this creates the queue.
#
# The device URI is resolved HERE, not stored: CUPS builds it from the
# printer's serial number, which is a discovered identifier and has no place in
# a public repo. The driver, by contrast, comes from the splix package and is
# the same string on every machine, so that one is configuration.
#
# No sudo: CUPS accepts administration from the `wheel` group on Arch, which
# ulu is in. Verified rather than assumed — `lpadmin` ran unprivileged.
if [[ -n "${PRINTER_NAME:-}" ]]; then
    # Section 10 only ENABLES cups — on a fresh install nothing has started it
    # yet, and lpinfo against a dead scheduler exits non-zero. Under pipefail
    # that killed the whole stage, silently, because lpinfo's stderr is
    # discarded. Found on the first real run 2026-07-31; never seen before
    # because the old system had CUPS running and QEMU declares no printer.
    systemctl is-active --quiet cups.service || sudo systemctl start cups.service
    if lpstat -p "$PRINTER_NAME" &>/dev/null; then
        echo "printer: $PRINTER_NAME already exists"
    else
        # `|| true`: this block promises "loud, not fatal" — a failing probe
        # must land in the warning below, not abort the install.
        printer_uri="$(lpinfo -v 2>/dev/null | awk -v m="$PRINTER_MATCH" '$0 ~ m && /usb:/ {print $2; exit}' || true)"
        if [[ -z "$printer_uri" ]]; then
            # Loud, not fatal: a printer that is switched off or unplugged must
            # not abort an install, but it must not pass unnoticed either.
            echo "WARNING: no USB device matching '$PRINTER_MATCH' — printer not created."
            echo "         Switch it on and re-run stage 3."
        else
            lpadmin -p "$PRINTER_NAME" -v "$printer_uri" -m "$PRINTER_DRIVER" -E
            echo "printer: $PRINTER_NAME created"
        fi
    fi

    # Options and default destination are applied every run: they are the
    # decisions, and re-applying them is how a hand-change gets corrected.
    if lpstat -p "$PRINTER_NAME" &>/dev/null; then
        for opt in "${PRINTER_OPTIONS[@]}"; do
            lpadmin -p "$PRINTER_NAME" -o "$opt"
        done
        lpadmin -d "$PRINTER_NAME"
        echo "printer: options set (${PRINTER_OPTIONS[*]}), default destination"
    fi
fi

# ------------------------------------------------- 8. shell aliases (idempotent)
# Own file, sourced from .zshrc — NOT a block appended into it. The block was
# guarded by `grep -q "phoinix aliases"`, so it was written once and never
# again: adding an alias later reached fresh installs only, and every machine
# that already had the block silently kept the old list. A file phoinix owns
# outright is rewritten on every run, and .zshrc gains exactly one line, once.
ALIAS_FILE="$HOME/.config/phoinix/aliases.zsh"
install -d "$(dirname "$ALIAS_FILE")"
cat > "$ALIAS_FILE" << EOF
# Written by phoinix stage 3 — do not edit, it is overwritten on every run.

# Muscle memory maps to the decided tools.
alias nano='micro'
alias yay='paru'

# qBittorrent must run inside the VPN group or the kernel rule matches nothing
# and it talks to the internet directly. The panel launcher and the autostart
# entry both go through the wrapper; this closes the remaining everyday path,
# the one where it is simply typed. It does NOT cover \`/usr/bin/qbittorrent\`
# or a .desktop file from somewhere else — an alias is a convenience, and the
# guarantee still lives in nftables, not here.
alias qbittorrent='$REPO_DIR/scripts/qbittorrent-vpn.sh $HOST'
EOF

# Retire the legacy inline block, so the two cannot disagree.
if grep -q "^# --- phoinix aliases" "$HOME/.zshrc" 2>/dev/null; then
    tmp="$(mktemp)"
    awk '/^# --- phoinix aliases/ { skip = 1 }
         skip && /^alias /        { next }
         skip && /^# --- phoinix aliases/ { next }
         skip && !/^alias / && !/^# --- phoinix aliases/ { skip = 0 }
         { print }' "$HOME/.zshrc" > "$tmp"
    mv "$tmp" "$HOME/.zshrc"
    echo "aliases: retired the inline block in .zshrc"
fi

if ! grep -q 'phoinix/aliases.zsh' "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# phoinix aliases (the file is generated; see stage 3)\n[[ -f %s ]] && source %s\n' \
        "$ALIAS_FILE" "$ALIAS_FILE" >> "$HOME/.zshrc"
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

# Back up XIVLauncher's settings and plugins on session exit, same mechanism.
# This one closes a loop stage 3 itself opens: it RESTORES launcher.ini from
# XLCORE_BACKUP_DIR above, so without this unit a live change to the launcher
# is reverted by the next reinstall (rationale in the unit file).
sed -e "s|@REPO_DIR@|$REPO_DIR|g" -e "s|@HOST@|$HOST|g" \
    "$REPO_DIR/system/user/phoinix-xlcore-backup.service" \
    > "$USER_UNIT_DIR/phoinix-xlcore-backup.service"
ln -sf ../phoinix-xlcore-backup.service \
    "$USER_UNIT_DIR/graphical-session.target.wants/phoinix-xlcore-backup.service"

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
