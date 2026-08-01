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

# Writer for Qt/QSettings .conf files — NEVER use kwriteconfig6 on one.
#
# kwriteconfig6 suits KConfig files only. On a QSettings file it parses the
# whole thing as KConfig and writes it back, which does three things at once:
# it reorders the groups, it re-escapes every `@ByteArray(…)`/`@Variant(…)`
# value into garbage, and it doubles the backslash that QSettings uses as a
# group separator — turning `presets\1\name` into `presets\\1\\name`, a key
# the application never reads again.
#
# Learned first on qBittorrent (LOG 2026-07-31) and then AGAIN on Strawberry
# (LOG 2026-08-01), where it destroyed 19 equalizer presets and the saved
# window geometry in one call. The Strawberry case is the reason this lives
# here instead of inside one application's block: the same mistake was made
# twice because the fix was local to the first one.
#
# Fresh installs hide it — a file that does not exist yet has nothing to
# corrupt — so the damage only ever shows on a RE-RUN. No post-install step
# requires one any more (both reasons went on 2026-08-01), but this script is
# re-runnable by design and gets re-run during development constantly.
#
# Line-oriented on purpose: it touches exactly the one line it owns and leaves
# every byte it does not understand alone.
qs_set() {   # $1 = file, $2 = section, $3 = key, $4 = value
    local file="$1" tmp
    [[ -f "$file" ]] || install -Dm600 /dev/null "$file"
    tmp="$(mktemp)"
    QS_SEC="$2" QS_KEY="$3" QS_VAL="$4" awk '
        BEGIN { want = "[" ENVIRON["QS_SEC"] "]"; key = ENVIRON["QS_KEY"];
                val = ENVIRON["QS_VAL"]; done = 0; incur = 0 }
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
    ' "$file" > "$tmp"
    # `cat >` rather than `mv`: it keeps the destination's inode, mode and
    # owner, so a config that is user-readable only stays that way.
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

# ------------------------------------------------- 0. commit identity
# Early, before anything can fail: this is the one setting whose absence is a
# privacy incident rather than an inconvenience.
#
# Nothing used to set it. bootstrap clones fresh, stage 2 copies the tree to
# ~/phoinix, and `.git/config` is not versioned — so the repo-local identity
# was hand-made on the old install and simply absent after the reinstall.
# Found on 2026-07-31 with `git var GIT_AUTHOR_IDENT` answering "Author
# identity unknown", i.e. the guard that CLAUDE.md calls the defence against
# the name leak was not there at all.
if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" config user.name  "$GIT_IDENTITY_NAME"
    git -C "$REPO_DIR" config user.email "$GIT_IDENTITY_EMAIL"
    echo "git: repo-local identity set to $GIT_IDENTITY_NAME <$GIT_IDENTITY_EMAIL>"

    # Both leaks this repo has actually suffered, each with its own warning.
    # Warn rather than abort: either state can be legitimate on a machine that
    # is not only used for phoinix — but neither may pass unnoticed, because
    # both silently OVERRIDE or PRE-EMPT the line above.
    if git config --global user.email >/dev/null 2>&1 \
       || git config --global user.name >/dev/null 2>&1; then
        echo "WARNING: a GLOBAL git identity exists —"
        echo "         $(git config --global user.name 2>/dev/null) <$(git config --global user.email 2>/dev/null)>"
        echo "         Repo-local wins for THIS repo, but that is how 35 commits"
        echo "         once acquired ulu's real name. Check other clones."
    fi
    if [[ -n "${GIT_AUTHOR_NAME:-}${GIT_AUTHOR_EMAIL:-}${GIT_COMMITTER_NAME:-}${GIT_COMMITTER_EMAIL:-}" ]]; then
        echo "WARNING: GIT_AUTHOR_*/GIT_COMMITTER_* are set in the environment."
        echo "         These OVERRIDE the repo-local identity — the laptop case"
        echo "         from 2026-07-31. Unset them before committing."
    fi

    # Push credentials. The token itself is a secret and lives on a data disk;
    # only its path is versioned, exactly like VPN_CONFIG_DIR. The helper is
    # set REPO-LOCALLY on purpose — a global one would offer ulu's token to
    # every clone on the machine.
    if [[ -n "${GIT_CREDENTIALS_FILE:-}" ]]; then
        git -C "$REPO_DIR" config credential.helper "store --file=$GIT_CREDENTIALS_FILE"
        if [[ -s "$GIT_CREDENTIALS_FILE" ]]; then
            echo "git: push credentials from $GIT_CREDENTIALS_FILE"
        else
            # Loud, not fatal: an install must not stop over this, but a silent
            # skip would only be discovered at the first push — which is
            # typically the commit that records the install itself.
            echo "WARNING: $GIT_CREDENTIALS_FILE is missing or empty — push will ask for"
            echo "         credentials. One line, mode 0600:"
            echo "         https://$GIT_IDENTITY_NAME:<token>@github.com"
        fi
    fi

    # Claude Code's local settings for this checkout. Gitignored on purpose, so
    # it cannot ride along in the clone — which is precisely why it is restored
    # from a data disk instead, like every other file in that class.
    #
    # It carries `defaultMode: bypassPermissions`. Stating that plainly because
    # the file name does not: this line brings a fresh machine up with
    # permission prompts disabled for this directory. ulu's decision, taken
    # explicitly (config.sh has the reasoning). It is one variable to remove.
    # SEEDED ONLY WHEN ABSENT, like the DZGUI config and the KeePassXC recent
    # database. An existing file is ulu's and is NEWER by construction: Claude
    # Code appends every permission rule he grants during a session, while the
    # copy on the data disk is a snapshot taken by hand. Overwriting it was the
    # first implementation and it destroyed four freshly granted rules within a
    # minute of being tested — the restore is for an EMPTY checkout, not for
    # keeping two copies in step.
    #
    # Consequence, and it is deliberate: the data-disk copy goes stale unless
    # it is refreshed, same as XLCORE_BACKUP_DIR. Refresh it with
    #   cp -a "$REPO_DIR/.claude/settings.local.json" "$CLAUDE_SETTINGS_FILE"
    CLAUDE_SETTINGS_DEST="$REPO_DIR/.claude/settings.local.json"
    if [[ -n "${CLAUDE_SETTINGS_FILE:-}" ]]; then
        if [[ -e "$CLAUDE_SETTINGS_DEST" ]]; then
            echo "claude: local settings exist — left alone (they are newer than the backup)"
        elif [[ -f "$CLAUDE_SETTINGS_FILE" ]]; then
            install -Dm644 "$CLAUDE_SETTINGS_FILE" "$CLAUDE_SETTINGS_DEST"
            echo "claude: local settings restored from $CLAUDE_SETTINGS_FILE" \
                 "(mode: $(jq -r '.permissions.defaultMode // "default"' "$CLAUDE_SETTINGS_FILE" 2>/dev/null))"
        else
            # Loud, not fatal: without it Claude Code simply falls back to its
            # normal prompting, which breaks nothing.
            echo "WARNING: $CLAUDE_SETTINGS_FILE missing — Claude Code keeps its default"
            echo "         permission behaviour in this checkout."
        fi
    fi
fi

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

    # Own the directory explicitly. `install -D` below would create it too, but
    # as root:root — and the kwriteconfig6 line further down writes as the
    # greeter user, which then could not.
    sudo install -d -o "$greeter_user" -g "$greeter_user" -m 700 \
        "$greeter_home/.config"

    if [[ -f "$HOME/.config/kwinoutputconfig.json" ]]; then
        sudo install -Dm644 -o "$greeter_user" -g "$greeter_user" \
            "$HOME/.config/kwinoutputconfig.json" \
            "$greeter_home/.config/kwinoutputconfig.json"
    fi

    # NumLock on at the LOGIN SCREEN as well — the session setting in section 6
    # writes ulu's own kcminputrc, which the greeter never reads.
    # The instance that actually flips the LED is KWin, not the login manager:
    # `KWin::Xkb::setNumLockConfig()` reads `kcminputrc` [Keyboard]NumLock, and
    # the greeter runs its own kwin_wayland as this user. So the same key in
    # this home does it — plasmalogin itself has no such option.
    # Written with kwriteconfig6 rather than dropped in as a file: KDE writes to
    # kcminputrc by itself (keyboard layout persistence), so this must merge.
    sudo -u "$greeter_user" env \
        HOME="$greeter_home" XDG_CONFIG_HOME="$greeter_home/.config" \
        kwriteconfig6 --file kcminputrc --group Keyboard --key NumLock 0
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

# strawberry.conf is a QSettings file, so qs_set — NOT kwriteconfig6. It holds
# @ByteArray window geometry and nineteen equalizer presets keyed
# `presets\N\name`, and kwriteconfig6 destroys both in a single call: measured
# 2026-08-01 on the live system, where it left 38 lines of doubled-backslash
# junk the application never reads again (LOG 2026-08-01).
#
# Whole-file capture is out for a second, independent reason: this file also
# holds a plain-text OAuth access token for a streaming service, which has no
# business in a public repo. Individual keys keep it away from one.
SB_CONF="$HOME/.config/strawberry/strawberry.conf"

# A running Strawberry writes the whole file on exit, so anything written
# underneath it is discarded without a word — the same trap qBittorrent taught
# us. On a fresh install it is not running; on a re-run it very well may be.
if pgrep -x strawberry >/dev/null; then
    echo "WARNING: Strawberry is running — it will overwrite these settings on exit."
    echo "         Quit it and re-run stage 3."
fi

# The stereo -> 5.1 upmix, and the reason Strawberry is in the package set at
# all: it happens INSIDE the player and must never be done system-wide (ulu's
# hard requirement, docs/LOG.md 2026-07-30). Strawberry's own default is
# channels_enabled=false, so both keys together are the whole setting.
qs_set "$SB_CONF" Backend channels_enabled true
qs_set "$SB_CONF" Backend channels 6

# Playback mode: shuffle everything, repeat the whole playlist. Both are enums
# compiled into Strawberry; the values are confirmed against what ulu selected
# in the GUI, not guessed — shuffle_mode 1 = "Shuffle all",
# repeat_mode 3 = "Repeat playlist".
qs_set "$SB_CONF" PlaylistSequence shuffle_mode 1
qs_set "$SB_CONF" PlaylistSequence repeat_mode 3

# The sponsoring message, off before it is ever seen. Strawberry shows it on
# EVERY start until the checkbox in it is ticked, so on a fresh install it
# greets the first login and keeps coming back. The key name is in the binary
# (`do_not_show_sponsor_message`) but its group is not — the value is only
# written once the box is ticked, so a pristine run does not reveal it. Found
# by experiment against a throwaway config, with a counter-test: only
# [MainWindow] suppresses the dialog; [General], [Settings] and [Sponsor] leave
# it standing (LOG 2026-08-01).
qs_set "$SB_CONF" MainWindow do_not_show_sponsor_message true

# Strawberry keeps its config user-readable only. qs_set preserves the mode of
# an existing file and creates a missing one as 600, so this only matters for
# a file some earlier run left more permissive.
chmod 600 "$SB_CONF"

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

# --- mpc-qt: REMOVED 2026-08-01 (ulu) ---------------------------------------
# Stage 3 used to repair a half-written mpc-qt profile and then write two
# track preferences into it. Both are gone, and the reason is the shape of
# the step rather than the settings: mpc-qt cannot be SEEDED (it segfaults on
# a settings.json without a real geometry entry, LOG 2026-07-31), so the
# settings could only be written into a profile that already existed — which
# meant "start mpc-qt once, then run stage 3 AGAIN". ulu is not willing to
# run stage 3 twice for it and configures the player himself.
#
# With this out, nothing in stage 3 needs a second run any more. The other
# reason vanished the same day when DZGUI's Steam shortcut was dropped.
#
# NOT removed: the mpc-qt window rule in stage 4 (adaptive sync off). It is a
# different kind of setting — applied at first login, needing no profile and
# no re-run, and it fixes the video flicker documented next to it there.

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
            # DNS, and this is the second thing the first version got wrong —
            # in the same shape as the routing above, one layer up. Proton's
            # config carries `DNS = 10.2.0.1`, and the import turns that into a
            # `~` search domain, i.e. the DNS DEFAULT ROUTE. resolved then sent
            # EVERY name on the machine through the tunnel while it was up, and
            # `enp8s0` could not resolve a global name at all. Measured
            # 2026-08-01: the browser's packets left via Vodafone (correct) but
            # its lookups exited in Zurich, so CDNs handed the whole desktop
            # Swiss edges — ulu's "some sites think I am in Switzerland".
            # Dropping the servers, not just the domain: a link with servers and
            # no domain is still a candidate for the default route.
            # The tunnel therefore carries packets only. What resolves ulu's
            # names is decided on the wired link, in section 7c.
            sudo nmcli connection modify "$VPN_INTERFACE" \
                connection.id "$name" \
                connection.autoconnect no \
                wireguard.ip4-auto-default-route no \
                wireguard.ip6-auto-default-route no \
                wireguard.fwmark "$VPN_MARK_WG" \
                ipv4.never-default no \
                ipv6.never-default no \
                ipv4.dns "" ipv4.dns-search "" \
                ipv6.dns "" ipv6.dns-search "" \
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
    # NOT kwriteconfig6, hence qs_set (defined at the top of this script).
    # qBittorrent.conf is Qt's QSettings format, where the backslash in
    # `Session\Interface` is a group separator written as ONE character.
    # KConfig treats a backslash as an escape and doubles it on save — and
    # because it rewrites the whole file, it doubled qBittorrent's OWN keys
    # too. The result looked plausible and was inert: qBittorrent never saw a
    # single setting we wrote, the WebUI was never enabled, and the interface
    # was never bound. Discovered only when qBittorrent rewrote the file itself
    # and every backslash came back single.
    #
    # This file also holds @ByteArray blobs of window geometry, which any
    # full-file rewriter would re-encode.
    QBT_CONF="$HOME/.config/qBittorrent/qBittorrent.conf"

    # A running qBittorrent holds its settings in memory and writes the whole
    # file when it exits, so anything written underneath it is discarded
    # without a word. On a fresh install it is not running; on a re-run it very
    # well might be — and silently losing the edit is exactly the class of
    # failure this repo keeps tripping over.
    if pgrep -x qbittorrent >/dev/null; then
        echo "WARNING: qBittorrent is running — it will overwrite these settings on exit."
        echo "         Quit it (File > Exit, not just the window) and re-run stage 3."
    fi

    # A thin wrapper, so the call sites below stay readable and the writer
    # itself has exactly one definition in this script.
    qbt_set() { qs_set "$QBT_CONF" "$1" "$2" "$3"; }

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

# --- DZGUI desktop link -----------------------------------------------------
# DZGUI ships no .desktop of its own, so one is generated from the template,
# same mechanism as the monitor switch. Its POSITION is Plasma state and lives
# in DESKTOP_ICONS (stage 4), which places it beside XIVLauncher.
#
# This REPLACES the non-Steam shortcut phoinix used to restore into Steam's
# shortcuts.vdf (ulu's call, 2026-08-01). That mechanism needed Steam to have
# been logged into once and quit again before it could do anything, which is
# what made "re-run stage 3 after setting up Steam" a manual step. A desktop
# file depends on nothing but the binary, so the step is gone with it.
if [[ -x "$HOME/Applications/dzgui/dzgui" ]]; then
    apps_dir="$HOME/.local/share/applications"
    install -d "$apps_dir" "$HOME/Desktop"

    # The artwork is DayZ's own icon, kept on the games disk because it is
    # Bohemia's and this repo is public. Installed into the hicolor theme under
    # our own name, so the .desktop can reference an icon NAME: a name degrades
    # to a generic icon if anything went wrong, a path degrades to nothing.
    dzgui_icon="applications-games"
    if [[ -n "${DZGUI_ICON:-}" && -f "$DZGUI_ICON" ]]; then
        install -Dm644 "$DZGUI_ICON" \
            "$HOME/.local/share/icons/hicolor/128x128/apps/phoinix-dzgui.png"
        dzgui_icon="phoinix-dzgui"
    elif [[ -n "${DZGUI_ICON:-}" ]]; then
        echo "WARNING: $DZGUI_ICON missing — DZGUI keeps a generic theme icon"
    fi

    sed -e "s|@HOME@|$HOME|g" -e "s|@ICON@|$dzgui_icon|g" \
        "$REPO_DIR/system/applications/phoinix-dzgui.desktop" \
        > "$apps_dir/phoinix-dzgui.desktop"
    chmod 644 "$apps_dir/phoinix-dzgui.desktop"
    ln -sf "$apps_dir/phoinix-dzgui.desktop" "$HOME/Desktop/phoinix-dzgui.desktop"
    echo "desktop: DZGUI link placed (icon: $dzgui_icon)"
else
    echo "WARNING: ~/Applications/dzgui/dzgui not present — no DZGUI desktop link"
fi

# --- Steam non-Steam shortcuts: REMOVED 2026-08-01 --------------------------
# phoinix used to restore a shortcuts.vdf holding one entry, DZGUI, so that
# DayZ could be launched from inside Steam. ulu dropped the idea; DZGUI gets a
# desktop icon instead (see "DZGUI desktop link" above).
#
# Worth keeping the reason, because the removal takes a manual step with it:
# shortcuts.vdf can only be written into `userdata/<id>/config`, which does not
# exist until Steam has been logged into — and Steam rewrites the file when it
# exits, so it also had to be quit. That is what forced "set up Steam, then
# re-run stage 3" onto the post-install list. A desktop file depends on nothing
# but the DZGUI binary, so the ordering requirement is gone.
#
# `/mnt/Games/phoinix/shortcuts.vdf` is left on the data disk untouched. It is
# not ours to delete, and it costs nothing where it is.

# ------------------------------------------------- 7c. DNS (Quad9 over TLS)
# The other half of the split tunnel, and it was missing for a month without
# anyone noticing — because it fails in a direction nothing tests: the packets
# were separated correctly while every NAME was resolved through the tunnel.
# See section 7b for the cause. What that left behind was a desktop resolving
# via the LAN router in plain text, i.e. the ISP reading every name including
# qBittorrent's trackers, which is what this section replaces.
#
# The arrangement, and the reason it looks inverted:
#
#   wired link   Quad9, DNS-over-TLS, strict — catches everything
#   global scope the LAN router, restricted to the DHCP domain (`~fritz.box`)
#
# The obvious layout is the other way round (router on the link, Quad9 global),
# and it does not work. NetworkManager marks the wired link as resolved's DNS
# DEFAULT ROUTE whatever domains it is given — measured: with `~fritz.box` as
# the only domain the link still reported `Default Route: yes` — and a link
# holding the default route claims every name, so the global servers would
# never be asked. Turning it around uses that instead of fighting it: the more
# SPECIFIC scope wins in resolved, so `~fritz.box` beats the link's catch-all
# and LAN names still reach the router.
#
# Strict (`2`) rather than opportunistic: a silent fallback to port 53 would
# hand the ISP exactly what this section exists to withhold, and would do it
# invisibly. Quad9 answers on four addresses, so a single unreachable one is
# not an outage.
#
# Why the LAN half is not optional. Without it `fritz.box` does not fail — it
# RESOLVES, to a stranger's host on the public internet (measured:
# 212.42.244.122). A wrong answer that works is worse than an error.
#
# Nothing here is stored in the repo but the resolver itself: the router's
# address and the LAN domain both come out of the DHCP lease at runtime, which
# is also why this cannot live in stage 2 — there is no lease yet in the chroot.
if [[ -n "${DNS_TLS_NAME:-}" ]]; then
    # The ethernet profile is auto-generated by NetworkManager ("Wired
    # connection 1"), so it is found by TYPE, never by name: the name is
    # NM's to choose and a fresh install may pick another one.
    mapfile -t eth_conns < <(
        nmcli -t -g NAME,TYPE connection show \
            | awk -F: '$2 == "802-3-ethernet" { print $1 }'
    )

    if (( ! ${#eth_conns[@]} )); then
        echo "WARNING: no ethernet connection — DNS left as NetworkManager set it."
    else
        # Read the lease BEFORE the link is changed. `ignore-auto-dns` only
        # stops NM from USING these values, it does not discard them, but
        # reading first keeps that independent of NM's behaviour.
        lan_resolver="" lan_domain=""
        for dev in $(nmcli -t -g DEVICE,TYPE device status | awk -F: '$2 == "ethernet" { print $1 }'); do
            opts="$(nmcli -g DHCP4.OPTION device show "$dev" 2>/dev/null || true)"
            [[ -n "$opts" ]] || continue
            lan_resolver="$(printf '%s' "$opts" | tr ',' '\n' | sed -n 's/.*domain_name_servers = \([^ |]*\).*/\1/p' | head -1)"
            lan_domain="$(printf '%s' "$opts" | tr ',' '\n' | sed -n 's/.*domain_name = \([^ |]*\).*/\1/p' | head -1)"
            [[ -n "$lan_resolver" ]] && break
        done

        dns4="" dns6=""
        for s in "${DNS_SERVERS_V4[@]}"; do dns4+="${dns4:+,}$s#$DNS_TLS_NAME"; done
        for s in "${DNS_SERVERS_V6[@]}"; do dns6+="${dns6:+,}$s#$DNS_TLS_NAME"; done

        for c in "${eth_conns[@]}"; do
            sudo nmcli connection modify "$c" \
                ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
                ipv4.dns "$dns4" ipv6.dns "$dns6" \
                ipv4.dns-search "" ipv6.dns-search "" \
                connection.dns-over-tls 2
            echo "dns: $c -> $DNS_TLS_NAME (DoT, strict)"
        done

        # The LAN half. Written even when the lease carried nothing, in which
        # case it is left empty rather than guessed — a wrong resolver here
        # would be answered wrongly rather than not at all.
        if [[ -n "$lan_resolver" && -n "$lan_domain" ]]; then
            sudo install -d -m755 /etc/systemd/resolved.conf.d
            sudo tee /etc/systemd/resolved.conf.d/10-phoinix-lan.conf >/dev/null <<EOF
# Written by phoinix stage 3 — do not edit, it is regenerated.
#
# The LAN router, restricted to the domain its own DHCP lease announced. The
# wired link runs Quad9 over TLS and holds resolved's DNS default route, so
# without this stanza a LAN name would be asked of Quad9 — which answers for
# the public $lan_domain and hands back a host that is not the router.
# Plain port 53 on purpose: this server is one hop away on ulu's own cable and
# does not speak DNS-over-TLS. It is reached ONLY for the domain below.
[Resolve]
DNS=$lan_resolver
Domains=~$lan_domain
EOF
            sudo systemctl restart systemd-resolved.service
            echo "dns: $lan_domain -> $lan_resolver (LAN scope)"
        else
            echo "WARNING: no domain/resolver in the DHCP lease — LAN names are not resolvable."
        fi

        for dev in $(nmcli -t -g DEVICE,TYPE device status | awk -F: '$2 == "ethernet" { print $1 }'); do
            sudo nmcli device reapply "$dev" >/dev/null || true
        done
    fi
fi

# ------------------------------------------------- 7d. printer
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
