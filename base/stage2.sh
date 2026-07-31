#!/usr/bin/env bash
# stage2.sh — runs INSIDE the chroot (arch-chroot /mnt), as root.
#
#   usage: stage2.sh <host>        e.g. stage2.sh desktop
#
# Locale, time, hostname, pacman (multilib), zram, user (zsh login shell),
# sudo, SSH, NetworkManager, systemd-boot. Re-runnable by design — stage 1
# was the one-shot destructive part, iteration happens here.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: stage2.sh <host>   (e.g. stage2.sh desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

exec > >(tee -a /var/log/stage2.log) 2>&1

# ------------------------------------------------------------ time & locale
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# More than one: the UI language and the German format locale (see config.sh).
for loc in "${LOCALES[@]}"; do
    sed -i "s|^#\(${loc//./\\.} UTF-8\)|\1|" /etc/locale.gen
done
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# The GRAPHICAL session has its own layout — vconsole alone leaves KDE in
# English (bit us on first login). KWin/Wayland reads this X11 fallback file;
# localectl can't run in a chroot, so write it directly.
# The variant matters here too, not just in the user session: the login
# greeter has no user kxkbrc and falls back to THIS file. Without it ulu would
# type his password on a dead-key layout and land in a no-dead-key session.
install -d /etc/X11/xorg.conf.d
{
    cat << EOF
# Written by phoinix stage2
# (equivalent of: localectl set-x11-keymap $KEYMAP "" ${KEYMAP_VARIANT:-})
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$KEYMAP"
EOF
    if [[ -n "${KEYMAP_VARIANT:-}" ]]; then
        echo "        Option \"XkbVariant\" \"$KEYMAP_VARIANT\""
    fi
    echo 'EndSection'
} > /etc/X11/xorg.conf.d/00-keyboard.conf

# ----------------------------------------------------------------- identity
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME
EOF

# ------------------------------------------------------------------- pacman
# multilib: required for the lib32 gaming stack (packages/gaming.txt)
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
pacman -Sy

# --------------------------------------------------------------------- zram
install -m644 "$REPO_DIR/system/zram-generator.conf" /etc/systemd/zram-generator.conf

# --------------------------------------------------------------------- user
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -G wheel -s /usr/bin/zsh "$USERNAME"
fi
# Prompt (again) whenever the account still has no usable password — keeps
# the script re-runnable even after a mistyped confirmation aborted a run.
while passwd -S "$USERNAME" | awk '{exit !($2 == "L" || $2 == "NP")}'; do
    echo ">> Set password for $USERNAME:"
    passwd "$USERNAME" || echo ">> Mismatch — try again."
done

echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

# Minimal global zshrc so the shell is civilized before the dotfiles arrive.
cat > /etc/zsh/zshrc << 'EOF'
autoload -Uz compinit && compinit
HISTFILE=~/.histfile HISTSIZE=10000 SAVEHIST=10000
bindkey -e
EOF
# The zsh-newuser-install wizard checks for USER config files (a global zshrc
# does not suppress it — learned on first boot). An empty ~/.zshrc does;
# the real one arrives with the dotfiles in stage 3.
[[ -e "/home/$USERNAME/.zshrc" ]] || \
    install -m644 -o "$USERNAME" -g "$USERNAME" /dev/null "/home/$USERNAME/.zshrc"

# SSH access for the laptop (public key lives in the repo — it's public)
install -d -m700 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/.ssh"
install -m600 -o "$USERNAME" -g "$USERNAME" \
    "$REPO_DIR/hosts/$HOST/authorized_keys" "/home/$USERNAME/.ssh/authorized_keys"

# ------------------------------------------------------- hand off to stage 3
# Stage 1 put the repo in /root/phoinix, but stage 3 must run as the user
# (AUR builds refuse root) and would not be able to read it there. Nothing
# used to create the user's copy — the README promised ~/phoinix and every
# install bridged that gap by hand. It is created here.
# Created ONCE, never refreshed: stage 2 is re-runnable, and from the second
# run onwards the user's copy is a working repo with its own commits — this is
# where sessions happen. Overwriting it would eat exactly that work. If it
# needs updating, it is a git repo and knows how to pull.
USER_REPO="/home/$USERNAME/phoinix"
if [[ "$REPO_DIR" != "$USER_REPO" && ! -d "$USER_REPO/.git" ]]; then
    install -d -o "$USERNAME" -g "$USERNAME" "$USER_REPO"
    cp -a "$REPO_DIR/." "$USER_REPO/"
    chown -R "$USERNAME:$USERNAME" "$USER_REPO"
fi

# Start stage 3 at the first login. A login shell, deliberately, not a systemd
# unit: stage 3 needs a terminal for the sudo password, and its long pacman/AUR
# phases are the part of the install that actually breaks (a paru/libalpm bump
# did, once) — in a unit that output would vanish into the journal while the
# screen sits blank. A unit would also need passwordless sudo, i.e. a hole that
# has to be closed again afterwards.
# .zprofile is free: the dotfiles restored in stage 3 bring only .zshrc and
# .p10k.zsh, and .zprofile is read by login shells only, not by every terminal.
# Disarmed by the marker stage 3 writes at its end — same mechanism as stage 4,
# so deleting the marker re-arms it.
cat > "/home/$USERNAME/.zprofile" << EOF
# --- phoinix: run stage 3 once, at the first login -------------------------
# Written by stage 2. Delete ~/.local/state/phoinix/stage3.done to re-arm.
if [[ ! -e "\$HOME/.local/state/phoinix/stage3.done" ]]; then
    mkdir -p "\$HOME/.local/state/phoinix"
    # flock, in case a second login (or an ssh session) arrives mid-run.
    if flock -n "\$HOME/.local/state/phoinix/stage3.lock" \\
             "$USER_REPO/base/stage3.sh" "$HOST"; then
        echo
        echo "Stage 3 done. Rebooting into KDE — stage 4 runs at that login."
        for i in 10 9 8 7 6 5 4 3 2 1; do
            printf '\\r  reboot in %2ds  (Ctrl-C to stay here) ' "\$i"
            sleep 1
        done
        printf '\\r%*s\\r' 45 ''
        sudo systemctl reboot
    else
        echo
        echo ">> Stage 3 failed. Log: ~/stage3.log"
        echo ">> Fix, then re-run: $USER_REPO/base/stage3.sh $HOST"
    fi
fi
EOF
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.zprofile"

# ----------------------------------------------------------------- services
systemctl enable NetworkManager sshd

# --------------------------------------------------------------- bootloader
bootctl install

ROOT_UUID="$(awk '$2 == "/" {sub("UUID=", "", $1); print $1}' /etc/fstab)"
[[ -n "$ROOT_UUID" ]] || { echo "ERROR: root UUID not found in fstab"; exit 1; }

cat > /boot/loader/loader.conf << 'EOF'
default arch-zen.conf
timeout 3
console-mode keep
EOF

# Two refresh-rate caps, same mechanism, two different reasons:
#   DP-2 @144 — monitor-bug fix: the TCL 27" 4K must never init at native
#     180Hz (DP bandwidth/DSC → black screen with all 4 displays).
#     See docs/LOG.md 2026-07-30.
#   DP-1 @144 — the ultrawide's link runs 4 lanes at HBR3 with no DSC and no
#     FEC; at 170Hz it sits at ~82% utilisation, where a single bit error
#     costs a retrain (= the sporadic black flash). See docs/LOG.md 2026-07-31.
#     PROVISIONAL: this is a running experiment, not a settled decision.
cat > /boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rw video=DP-2:3840x2160@144 video=DP-1:3440x1440@144
EOF

# ---------------------------------------------------------------- etckeeper
if [[ ! -d /etc/.git ]]; then
    etckeeper init
fi
# Persistent identity — without it every etckeeper auto-commit on pacman
# transactions dies with "empty ident name" (learned on first boot).
git -C /etc config user.name "etckeeper"
git -C /etc config user.email "root@$HOSTNAME"
git -C /etc log -1 &>/dev/null || git -C /etc commit -qm "Initial commit after stage 2" || true

echo
echo "stage 2 done. bootstrap.sh unmounts and reboots by itself;"
echo "stage 3 then starts at the first login of $USERNAME."
echo "Started by hand instead? Next: exit the chroot, then:"
echo "  umount -R /mnt && reboot"
