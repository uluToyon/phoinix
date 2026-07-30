# phoinix

Personal, git-tracked Arch Linux installer: burns my desktop down and raises
it from the ashes — system *and* settings — so distro-hopping away and coming
back is cheap.

## Why "phoinix"?

Named after [the Phoinix](https://finalfantasy.fandom.com/wiki/Asphodelos:_The_Third_Circle),
third boss of FFXIV's Pandæmonium: Asphodelos raid — a recreation of the
immortal firebird whose entire existence is the cycle of burning down and
rising anew from its own ashes. Which is precisely what this repo does to my
machine: stage 1 burns it down, stages 2 and 3 raise it from the ashes.

Lore says the Phoinix is a *"violent, failed iteration"* of the true Phoenix.
Fitting — so is every distro hop that ends right back at Arch.

## Layout

| Path | Purpose |
|---|---|
| `base/` | stage 1/2/3 install scripts (Arch-specific) |
| `packages/` | grouped package lists, pacman and AUR separately |
| `system/` | `/etc` bits, systemd units, udev rules (Arch-specific) |
| `dotfiles/` | chezmoi-managed, distro-agnostic |
| `hosts/` | per-machine config (`desktop/`, `laptop/`) |
| `config.sh` | shared defaults: user, locale, sizes |

Design notes and rationale: [docs/DESIGN.md](docs/DESIGN.md)
Decision log of the original build: [docs/LOG.md](docs/LOG.md)

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
git clone https://github.com/uluToyon/phoinix && cd phoinix
./base/stage1.sh desktop
arch-chroot /mnt /root/phoinix/base/stage2.sh desktop
reboot
# after first login
~/phoinix/base/stage3.sh
```

Don't `curl | bash` the disk stage — clone, read, then run. Pin to a tag if
you want a one-liner.
