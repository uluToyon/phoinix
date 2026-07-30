# archinstall

Personal, git-tracked Arch Linux installer: rebuilds "my Arch" — system *and*
settings — from scratch, so distro-hopping away and coming back is cheap.

Design notes and rationale: [docs/DESIGN.md](docs/DESIGN.md)
Installation log of the original run: [docs/PROTOKOLL.md](docs/PROTOKOLL.md)

## Layout

| Path | Purpose |
|---|---|
| `base/` | stage 1/2/3 install scripts (Arch-specific) |
| `packages/` | grouped package lists, pacman and AUR separately |
| `system/` | `/etc` bits, systemd units, udev rules (Arch-specific) |
| `dotfiles/` | chezmoi-managed, distro-agnostic |
| `hosts/` | per-machine config (`desktop/`, `laptop/`) |
| `config.sh` | shared defaults: user, locale, sizes |

## Stages

| Stage | Runs where | Does |
|---|---|---|
| `base/stage1.sh <host>` | Arch ISO | partition, mkfs, mount, pacstrap, genfstab |
| `base/stage2.sh <host>` | chroot | locale, hostname, mkinitcpio, user, bootloader, services |
| `base/stage3.sh` | first boot, as user | AUR helper, packages, dotfiles, desktop config |

Stage 1 is destructive and one-shot; it demands the target disk's serial
number before touching anything. Stages 2 and 3 are re-runnable.

## Usage

```sh
# on the Arch ISO
git clone https://github.com/<me>/archinstall && cd archinstall
./base/stage1.sh desktop
arch-chroot /mnt /root/archinstall/base/stage2.sh desktop
reboot
# after first login
~/archinstall/base/stage3.sh
```

Don't `curl | bash` the disk stage — clone, read, then run. Pin to a tag if
you want a one-liner.
