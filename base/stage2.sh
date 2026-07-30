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

sed -i "s|^#\(${LOCALE//./\\.} UTF-8\)|\1|" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

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

# video=DP-2:...@144 — monitor-bug fix: the TCL 27" 4K must never init at
# native 180Hz (DP bandwidth/DSC → black screen with all 4 displays).
# See docs/LOG.md 2026-07-30.
cat > /boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rw video=DP-2:3840x2160@144
EOF

# ---------------------------------------------------------------- etckeeper
if [[ ! -d /etc/.git ]]; then
    etckeeper init
    git -C /etc -c user.name="etckeeper" -c user.email="root@$HOSTNAME" \
        commit -qm "Initial commit after stage 2" || true
fi

echo
echo "stage 2 done. Next: exit the chroot, then:"
echo "  umount -R /mnt && reboot"
