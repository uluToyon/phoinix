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
| `scripts/bootstrap.sh` | the one command — clones and drives the whole install |
| `base/` | stage 1–4 install scripts (Arch-specific) |
| `packages/` | grouped package lists, pacman and AUR separately |
| `system/` | `/etc` bits, systemd units, udev rules (Arch-specific) |
| `plasma/` | scripts fed to plasmashell's scripting interface (stage 4) |
| `dotfiles/` | shell config, installed as plain files by stage 3 |
| `hosts/` | per-machine config (`desktop/`, `laptop/`) |
| `config.sh` | shared defaults: user, locale, sizes |

Design notes and rationale: [docs/DESIGN.md](docs/DESIGN.md)
Decision log of the original build: [docs/LOG.md](docs/LOG.md)

## Stages

| Stage | Runs where | Started by | Does |
|---|---|---|---|
| `base/stage1.sh <host>` | Arch ISO, root | bootstrap | partition, mkfs, mount, pacstrap, genfstab |
| `base/stage2.sh <host>` | chroot, root | bootstrap | locale, hostname, user, bootloader, services |
| `base/stage3.sh <host>` | first boot, as user | login hook from stage 2 | AUR helper, packages, dotfiles, desktop config |
| `base/stage4.sh <host>` | first Plasma session | systemd user unit from stage 3 | panels, window rules, everything needing a live shell |

Each stage arms the next, so the whole install runs from one command. Stage 1
is destructive and one-shot; stages 2–4 are re-runnable.

## Usage

```sh
# on the Arch ISO — this is the whole thing
curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
```

That clones the repo, runs stages 1 and 2, and reboots. Log in as the user,
stage 3 runs itself and reboots into KDE, stage 4 fires at that login. Two
things are typed by a human and nothing else: the password for the new user
account, and later the sudo password.

For a reproducible run, pin to a tag: `… | bash -s desktop v1.0`.

**What keeps stage 1 from eating the wrong disk:** the target is a
`/dev/disk/by-id/` path in `hosts/<host>/config.sh`, so it simply does not
resolve on another machine and stage 1 aborts before touching anything. It
also refuses without UEFI, refuses a target with mounted partitions, refuses
the disk hosting the running ISO, and counts down before it starts.

Prefer to read before you run? Clone it and start the same script locally:

```sh
git clone https://github.com/uluToyon/phoinix && ./phoinix/scripts/bootstrap.sh desktop
```
