# Reinstall — running phoinix on the real desktop

The procedure for actually doing it, written 2026-07-31 for the first supervised
run. ulu drives it from the laptop over SSH; the desktop is the machine being
rebuilt.

Read `STATUS.md` first for what is currently unproven. Nothing here repeats it.

---

## 0. Before rebooting — on the running desktop

**Stage 1 partitions `/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NX0T343303X`
(= `nvme1n1`), which holds `/`, `/boot` AND `/home`.** Everything in the home
directory that is not in the repo or on a data disk is gone afterwards.

Verified 2026-07-31, before the first supervised run:

| Check | Result |
|---|---|
| Target vs. data disks | separate devices — target `nvme1n1`; `Games` on `nvme0n1p1`, `Video` `sda1`, `Downloads` `sdb1`, `FilesMusic` `sdc1` |
| `scripts/check-drift.sh desktop` | 10 in sync, 0 drifted |
| `XLCORE_BACKUP_DIR` | 80 MB, same day |
| `STEAM_SHORTCUTS_FILE` | present, same day |
| `DZGUI_PRIVATE_FILE` | present, same day |
| `VPN_CONFIG_DIR` | both `.conf` files, CH and NL |
| `PLAYLIST_FILE` | present |
| `KEEPASS_DB` | present |
| `hosts/desktop/authorized_keys` | key material identical to the live file, so SSH survives — only the comment is sanitised, deliberately |

**Two things are irreplaceable and covered by none of the above.** Copy them to a
data disk first — both are tiny:

```
install -d /mnt/Downloads/rescue
cp -a ~/.ssh    /mnt/Downloads/rescue/ssh
cp -a ~/.claude /mnt/Downloads/rescue/claude
```

- `~/.ssh/id_ed25519` — the private key. It is NOT in the repo and must never be
  (see DESIGN.md "Never in the repo"). Losing it means re-registering a new key
  everywhere it is authorised.
- `~/.claude` — the session transcripts. The existing backup on the Downloads
  disk is from 2026-07-30 and predates the last two sessions. These have already
  proved their worth once: the soundbar's `−26 dB` and its reason were recovered
  out of older transcripts after the knowledge had been lost.

Everything else in the home directory is either rebuilt or restored: Steam
re-attaches its library from `/mnt/Games`, XIVLauncher restores from the 80 MB
backup, Brave comes back through Brave Sync, and Discord, unity3d, baloo, NuGet,
umu and the caches regenerate.

Finally: **commit and push**. Stage 1 clones from GitHub, so anything only on
the local disk does not exist as far as the installer is concerned.

---

## 1. Boot the ISO

Boot the Arch ISO on the desktop. It lands at `root@archiso ~ #` with no
password set.

## 2. Make SSH reachable

The ISO runs `sshd` already, but **root has no password, and sshd refuses an
empty one** — so SSH is closed until this is typed on the desktop's own
keyboard:

```
passwd
ip -brief addr
```

The first sets a throwaway root password for this session; the second gives the
address to connect to. Then, from the laptop:

```
ssh root@<address>
```

## 3. Run the one command

In that SSH session:

```
curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
```

What it does, and where it stops for you:

- **Stage 1** sorts the mirrorlist, then partitions and formats the target. It
  gives a **10-second countdown** first — `Ctrl-C` there is the last exit.
  `PHOINIX_YES=1` in the environment skips the countdown; do not use it here.
- **Stage 2** runs in the chroot and **asks for `ulutoyon`'s password**. This is
  the one thing that cannot be automated away and the one thing you must be at
  the keyboard — or the SSH session — for.
- Then it reboots into the installed system.

## 4. Stage 3, over SSH

After the reboot the machine has `sshd` enabled and `hosts/desktop/authorized_keys`
in place, so from the laptop:

```
ssh ulutoyon@<address>
```

**That login starts stage 3 by itself.** `~/.zprofile` fires it on the first
login shell, and an SSH session is a login shell — there is nothing to type. It
is guarded by `flock`, so a second session joining midway does not start a
second run.

Stage 3 is the long one: packages, then `paru` built from source, then the AUR
tree. It ends with a 10-second countdown and reboots into KDE.

## 5. Stage 4, at the machine

Stage 4 needs a running Plasma session — it is a systemd user unit wanted by
`plasma-workspace.target`, so it fires when you log in graphically **on the
desktop itself**. It cannot be driven over SSH.

## Logs

| Stage | Path |
|---|---|
| 1 | `/var/log/stage1.log` — copied into the target as `/var/log/stage1.log` |
| 2 | `/var/log/stage2.log` |
| 3 | `~/stage3.log` |
| 4 | `~/stage4.log` |

All four are written with `tee`, so they exist even when a stage dies. From the
laptop, `ssh ulutoyon@<address> 'cat ~/stage3.log'` is enough to hand one over.

## If something goes wrong

- **The data disks are never formatted by anything in this repo** — a failed run
  costs the system disk, not `Games`, `Video`, `Downloads` or `FilesMusic`.
- Stages are re-runnable. Stage 3 disarms itself with
  `~/.local/state/phoinix/stage3.done`; deleting that marker re-arms it, and the
  same holds for stage 4's.
- The repo lands in `/root/phoinix` during the install and is copied to
  `/home/ulutoyon/phoinix` by stage 2. Both are full clones — you can edit a
  stage script in place and run it again.
- Known unproven, per STATUS: stage 4's multi-icon `positions` JSON has never
  been written by the script, only computed. If the desktop icons come back in
  the wrong cells, that is the place to look, and `~/stage4.log` will say which
  containment it picked.

## Afterwards

`STATUS.md` has the post-install manual steps that cannot be scripted — Steam's
login and library re-attach in that order, Strawberry's collection folder,
Brave's sync chain, the printer test page, KDE Connect pairing. Then run
`./scripts/check-drift.sh desktop` once the dust settles: it should report
everything in sync, and anything it flags is something the install did not
actually restore.
