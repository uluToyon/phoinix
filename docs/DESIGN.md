# Arch install script — design notes

Started 2026-07-28. Goal: a git-hosted, reusable installer that rebuilds "my Arch"
from scratch in minutes, so distro-hopping away and back is cheap.

Deliberate choice: **hand-rolled manual install** (Arch wiki installation guide),
NOT the `archinstall` tool. Full control over partitioning, mkinitcpio, bootloader.

---

## Repo layout

```
base/        stage1/2/3 install scripts      <- Arch-specific
packages/    grouped .txt lists, pacman + AUR separately
system/      /etc bits, systemd units, udev rules   <- Arch-specific
dotfiles/    chezmoi                                <- distro-agnostic
hosts/       per-machine config (desktop/, laptop/)
scripts/     thin glue
```

The `dotfiles/` + `system/` split is the point: when hopping to another distro,
dotfiles apply unchanged and most of `system/` is just a package-manager rename.
Only `base/` and `packages/` are truly Arch-bound.

---

## Three stages (the chroot is a hard boundary)

| Stage | Runs where | Does |
|-------|-----------|------|
| `stage1.sh` | on the ISO | partition, mkfs, mount, pacstrap, genfstab |
| `stage2.sh` | in the chroot | locale, hostname, mkinitcpio, users, bootloader, services |
| `stage3.sh` | first boot, as user | AUR helper, user packages, dotfiles, desktop config |

Stage 1 hands off:

```bash
install -m755 stage2.sh /mnt/root/
arch-chroot /mnt /root/stage2.sh
```

Sequencing gotcha: an AUR helper refuses to build as root, so the order is
user must exist -> reboot -> build AUR -> install user packages. That is why
stage 3 exists separately and runs unprivileged.

**Idempotency:** don't chase it in stage 1 — partitioning is destructive and
one-shot. Stages 2 and 3 must be re-runnable; that's where the iteration happens.

---

## Config separate from logic

Single `config.sh`: `DISK`, `HOSTNAME`, `USERNAME`, `TIMEZONE`, `LOCALE`,
filesystem choice, package lists. Stage scripts contain no machine-specific
values. Machine specifics (4-monitor layout, audio) live in `hosts/desktop/`.

---

## Guard rails on the destructive step

- Never default `DISK` — require it explicitly, abort if unset.
- Target `/dev/disk/by-id/`, never `/dev/nvme0n1` or `/dev/sda`. Enumeration
  order is not stable across boots.
- Print the partition table, require typing the disk's **serial** to confirm,
  not `y/N`.
- Refuse to run if the target is mounted or is the ISO's own device.

---

## Decisions to encode deliberately

- **ESP 1 GB**, not 512 MB — multiple kernels + fallback initramfs outgrow it.
- **btrfs subvolumes** (if chosen): `@`, `@home`, `@snapshots`, `@var_log`.
  Get it right up front or snapper rollback doesn't work properly.
- **`amd-ucode`** in the boot entry (AMD machine). Silently omitted more often
  than you'd think.
- **`mkinitcpio` HOOKS order** — most common cause of an unbootable result.
  Comment *why* the order is what it is.
- **Enable the network unit before reboot.** A working ISO session says nothing
  about whether the installed system comes up on the network.
- **Separate `/home`** (partition or subvolume) — this plus the dotfiles repo is
  what makes "hop away and come back" cheap instead of a rebuild.

---

## Capture tooling (recording, not scripting)

Most of "record all the settings" is capture, not authorship:

- **`etckeeper`** — puts `/etc` under git, auto-commits on every pacman
  transaction. Install *before* configuring anything.
- **`pacman -Qqe`** (explicit) and **`pacman -Qqm`** (AUR/foreign) to seed
  package lists. Curate into groups; ungrouped dumps rot and you stop trusting them.
- **`chezmoi`** for dotfiles — chosen over stow for templating, which handles
  the differing usernames across machines (`ulutoyon` on desktop,
  a different username on the Fedora laptop).

**Method:** the repo is the source of truth, written as we go. Do NOT plan to
mine a Claude Code transcript into a script afterwards — that yields
exploratory dead-ends, wrong ordering, and steps that only worked due to prior
state. The transcript is a safety net, not the input.

---

## Testing loop — the thing that makes hand-rolling viable

QEMU with OVMF (real UEFI firmware; behavior differs enough from BIOS to matter):

```bash
qemu-system-x86_64 -enable-kvm -m 4G \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive file=test.qcow2,format=qcow2 -cdrom archlinux.iso
```

Full cycle in minutes, disposable image, zero risk. Iterate here until stage 1+2
reliably produce a bootable minimal system *before* touching packages or desktop
config. Hand-rolling without this loop is how people end up with a script that
worked exactly once.

---

## Caveats for the SSH-driven install

- **Run the installer inside `tmux` on the target.** A dropped connection
  mid-`pacstrap` kills the install and leaves a half-populated `/mnt`.
- Log each stage: `exec > >(tee -a /var/log/install.log) 2>&1` — this doubles as
  the "recording".
- Expect the SSH session to die at reboot with changed host keys. Normal.
- `curl | bash` is the wrong pattern for the disk stage: runs as root, partitions
  drives, no chance to review changes. Clone, read the diff, run. If you want a
  one-liner, pin to a tag — never a moving branch.

---

## Never in the repo

SSH private keys, wifi PSKs, plaintext passwords. Use `openssl passwd -6` hashes
with `chpasswd -e`, or prompt interactively. Encrypt with `age`/`sops` if stored.

---

## Don't encode discovered identifiers

Learned the hard way on this machine: the Teufel soundbar was `hw:5` on
2026-07-26 and `hw:3` on 2026-07-28. Card indices, `/dev/sd*`, PCI paths all
drift. Use stable IDs — `alsa_card.usb-NXP_SEMICONDUCTORS_Teufel_CONCEPT_12-00`,
PARTUUIDs, `/dev/disk/by-id/`.

---

## Worth capturing from the current desktop before reinstalling

These encode hours of debugging and are easy to forget:

```
~/.local/state/wireplumber/default-profile      # analog-surround-51 pin
~/.local/state/wireplumber/default-routes        # the -26dB fix (bar must NOT run at max)
~/.config/pipewire/pipewire.conf.d/10-clock.conf
~/.config/kwinrc
~/.local/share/kscreen/                          # 4-monitor layout, VRR, HDR
~/.xlcore/launcher.ini                           # FFXIV runner + DXVK settings
/mnt/nvme0n1/FFXIV/ffxivConfig/FFXIV.cfg         # CRLF! preserve line endings when editing
```

Run the capture side while the current install still works — it gives a baseline
to diff the fresh install against, so the new system can be *verified*, not hoped at.

---

## Open decisions (blocking stage 1/2 drafting)

1. Filesystem — btrfs + subvolumes, or ext4?
2. Encryption — LUKS or not?
3. Bootloader — systemd-boot (simplest, UEFI single-OS) or GRUB?

These three pin down most of stage 1 and 2.

## Next step

Write stage 1 and 2 against the QEMU loop until a bootable minimal system comes
out reliably. Leave packages and desktop config alone until then — stage 3 is
where all the churn is, and it wants a solid base under it.
