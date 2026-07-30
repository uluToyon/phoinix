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
GREETER_HOME="$(getent passwd plasmalogin sddm 2>/dev/null | head -1 | cut -d: -f6)"
if [[ -n "$GREETER_HOME" && -f "$HOME/.config/kwinoutputconfig.json" ]]; then
    sudo install -Dm644 "$HOME/.config/kwinoutputconfig.json" \
        "$GREETER_HOME/.config/kwinoutputconfig.json"
fi

# ------------------------------------------------- 6. shell aliases (idempotent)
if ! grep -q "phoinix aliases" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'EOF'

# --- phoinix aliases (muscle memory maps to the decided tools) ---
alias nano='micro'
alias yay='paru'
EOF
fi

# ------------------------------------------------- 7. defaults & services
xdg-mime default brave-browser.desktop application/pdf || true

sudo systemctl enable bluetooth cups power-profiles-daemon

# Graphical login LAST — everything above (esp. the monitor fix) must exist
# before PLM ever starts. Unit name from the plasma-login-manager package.
PLM_UNIT="$(pacman -Qlq plasma-login-manager | grep -oE '[^/]+\.service$' | sort -u | head -1)"
[[ -n "$PLM_UNIT" ]] || { echo "ERROR: no service unit in plasma-login-manager"; exit 1; }
sudo systemctl enable "$PLM_UNIT"
sudo systemctl set-default graphical.target

echo
echo "stage 3 done. Reboot (or 'sudo systemctl start $PLM_UNIT') to reach KDE."
echo "Manual checklist afterwards: docs/STATUS.md → 'Post-install manual steps'."
