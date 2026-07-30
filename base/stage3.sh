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
sudo -v
( while true; do sudo -n true; sleep 50; done ) &
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
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

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
# Restores live only where a capture source exists; the monitor fix MUST be
# in place before the first graphical login (black-screen bug, docs/LOG.md).
BACKUP="/mnt/Downloads/backup-nvme1n1-20260730/home/ulutoyon"
if [[ -d "$BACKUP" ]]; then
    install -Dm644 "$BACKUP/.config/kwinoutputconfig.json" "$HOME/.config/kwinoutputconfig.json"
    install -Dm644 "$BACKUP/.config/kwinrc"                "$HOME/.config/kwinrc"
    install -Dm644 "$BACKUP/.config/kdeglobals"            "$HOME/.config/kdeglobals"
    mkdir -p "$HOME/.local/state" "$HOME/.config"
    cp -r "$BACKUP/.local/state/wireplumber" "$HOME/.local/state/" 2>/dev/null || true
    cp -r "$BACKUP/.config/pipewire"         "$HOME/.config/"      2>/dev/null || true
    install -m644 "$BACKUP/.zshrc"   "$HOME/.zshrc"
    install -m644 "$BACKUP/.p10k.zsh" "$HOME/.p10k.zsh"
fi

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

# ------------------------------------------------- 6. shell aliases (idempotent)
if ! grep -q "phoinix aliases" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'EOF'

# --- phoinix aliases (muscle memory maps to the decided tools) ---
alias nano='micro'
alias yay='paru'
EOF
fi

# ------------------------------------------------- 7. regional formats
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

# ------------------------------------------------- 8. defaults & services
xdg-mime default brave-browser.desktop application/pdf || true

sudo systemctl enable bluetooth cups power-profiles-daemon

# ------------------------------------------------- 9. arm stage 4 (post-login)
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

echo
echo "stage 3 done. Reboot (or 'sudo systemctl start $PLM_UNIT') to reach KDE."
echo "Manual checklist afterwards: docs/STATUS.md → 'Post-install manual steps'."
