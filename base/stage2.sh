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

# --------------------------------------------------------------------- udev
# Keychron: 51-* gives the launcher raw HID access to the running devices,
# 50-* covers the bootloader ids a board takes on while being flashed. Both
# grant via uaccess, so nothing here depends on a group existing. No reload is
# needed in the chroot — these are read at the next boot, which is the one
# after this script.
for r in "$REPO_DIR"/system/udev/*.rules; do
    install -Dm644 "$r" "/etc/udev/rules.d/$(basename "$r")"
done

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
    # -E 99 separates the two ways this can fail: 99 means ANOTHER session
    # holds the lock and stage 3 was never started here, anything else means
    # stage 3 ran and failed. Without it a diagnostic ssh login opened while
    # the console run is working would print "Stage 3 failed" at a perfectly
    # healthy install — which is exactly the supervision setup ulu uses.
    flock -n -E 99 "\$HOME/.local/state/phoinix/stage3.lock" \\
          "$USER_REPO/base/stage3.sh" "$HOST"
    rc=\$?
    if [[ \$rc -eq 99 ]]; then
        echo
        echo ">> Stage 3 is already running in another session — not starting a second."
        echo ">> Watch it with: tail -f ~/stage3.log"
    elif [[ \$rc -eq 0 ]]; then
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

# --------------------------------------------------- ProtonVPN split tunnel
# Only for a host that declares a VPN. Everything here is system-level and
# therefore stage 2's job; stage 3 imports the actual connections.
if [[ -n "${VPN_CONFIG_DIR:-}" ]]; then
    # The group is the handle the kernel rule matches on. A GROUP rather than a
    # separate user: qBittorrent is a GUI application in ulu's session, and a
    # second user would mean a second home, second permissions on the download
    # directory, and Wayland socket gymnastics — all to express one bit.
    getent group "$VPN_GROUP" >/dev/null || groupadd -r "$VPN_GROUP"
    # ulu must be a MEMBER, or `sg` would ask for a group password at every
    # launch. Membership grants nothing by itself — the group owns no files and
    # has no sudo rights; it exists purely to be matched in the output chain.
    gpasswd -a "$USERNAME" "$VPN_GROUP" >/dev/null

    sed -e "s|@VPN_INTERFACE@|$VPN_INTERFACE|g" \
        -e "s|@VPN_GROUP@|$VPN_GROUP|g" \
        -e "s|@VPN_MARK_APP@|$VPN_MARK_APP|g" \
        -e "s|@VPN_MARK_WG@|$VPN_MARK_WG|g" \
        -e "s|@VPN_DNS@|$VPN_DNS|g" \
        -e "s|@VPN_DNS_STUB@|$VPN_DNS_STUB|g" \
        "$REPO_DIR/system/nftables.conf" > /etc/nftables.conf
    chmod 644 /etc/nftables.conf
    # The drop-in is what makes the unit's state honest — without it the
    # launcher's safety check refuses on a healthy system. Reason in the file.
    install -Dm644 "$REPO_DIR/system/nftables.service.d/phoinix-remain.conf" \
        /etc/systemd/system/nftables.service.d/phoinix-remain.conf
    systemctl enable nftables.service

    # DNS per link instead of one global resolv.conf — the rationale is in the
    # file itself, and it is the reason this whole setup does not leak.
    install -Dm644 "$REPO_DIR/system/NetworkManager/10-phoinix-dns.conf" \
        /etc/NetworkManager/conf.d/10-phoinix-dns.conf
    systemctl enable systemd-resolved.service
    # Under arch-chroot a plain `ln -sf` here fails: the chroot bind-mounts
    # the ISO's /run and its resolv.conf over this path, so link target and
    # destination are the same file (ln refuses) — and a mountpoint cannot be
    # unlinked anyway. Drop the bind first, then link. Chroot DNS is gone
    # from here on; nothing below needs the network. arch-chroot's teardown
    # tolerates the missing mount (prints "not mounted", still exits 0 —
    # verified on the real ISO 2026-07-31). QEMU never hit any of this: the
    # test host declares no VPN, so this block never ran there.
    if mountpoint -q /etc/resolv.conf; then
        umount /etc/resolv.conf
    fi
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

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

# Kernel parameters are a property of the MACHINE, so they live in
# hosts/<host>/config.sh — this used to hardcode the desktop's two video= caps
# right here, which meant every other host silently inherited monitor fixes for
# hardware it does not have (the QEMU test host got them, which is how this was
# noticed).
cat > /boot/loader/entries/arch-zen.conf << EOF
title   Arch Linux (zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rw ${KERNEL_PARAMS:-}
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
