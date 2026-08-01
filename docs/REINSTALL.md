# Reinstall — running phoinix on the real desktop

The procedure for actually doing it, written 2026-07-31 for the first supervised
run.

**ulu types everything at the desktop itself.** The laptop is connected over SSH
for ONE purpose: looking at logs when something goes wrong. It never drives the
install. That split is deliberate — a dropped SSH connection must never be able
to interrupt a stage mid-run.

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

Done for the 2026-07-31 run: both sit in `/mnt/Downloads/rescue/` (`ssh/` with
the private key still at 0600, `claude/` with 46 MB including that day's seven
transcripts). The 2026-07-30 backup is still beside it, untouched.

### Putting the key back — the step this file used to be missing

Rescuing is only half of it, and the missing half went unnoticed for a whole
reinstall: **nothing restores `~/.ssh`.** Stage 3 writes `authorized_keys` from
the repo, so incoming SSH works and the gap is invisible — the machine simply
has no identity of its own until someone notices. Found on 2026-08-01, hours
after the run, and only because ulu asked what those folders on the Downloads
disk were for.

Run this once the new system is up:

```
install -m 700 -d ~/.ssh
install -m 600 /mnt/Downloads/rescue/ssh/id_ed25519     ~/.ssh/id_ed25519
install -m 644 /mnt/Downloads/rescue/ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
install -m 600 /mnt/Downloads/rescue/ssh/known_hosts    ~/.ssh/known_hosts
ssh-keygen -lf ~/.ssh/id_ed25519      # fingerprint must match the rescue copy
```

**Not `authorized_keys`.** The live one comes from the repo with a sanitised
comment; the rescued one carries the original. Copying it back would undo that
deliberately, and the key material is identical either way.

Deliberately not scripted into stage 3: a private key is exactly the file that
must not be moved around by an installer that also runs unattended in a VM, and
the rescue directory is a hand-made thing whose absence must be noticed rather
than skipped over. It is a checklist item here, next to the rescue that
produces it.

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

## 2. Open the diagnostic channel (optional, before starting)

Only needed if you want the laptop able to look at stage 1 and 2 logs while they
run. The ISO runs `sshd` already, but **root has no password and sshd refuses an
empty one**, so at the desktop keyboard:

```
passwd
ip -brief addr
```

The first sets a throwaway root password for this boot, the second gives the
address. From the laptop then `ssh root@<address>` — to READ, not to drive.

## 3. Run the one command — at the desktop

Typed at the machine itself, not over SSH:

```
curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
```

What it does, and where it stops for you:

- **Stage 1** sorts the mirrorlist, then partitions and formats the target. It
  gives a **10-second countdown** first — `Ctrl-C` there is the last exit.
  `PHOINIX_YES=1` in the environment skips the countdown; do not use it here.
- **Stage 2** runs in the chroot and **asks for `ulutoyon`'s password**. The one
  input that cannot be automated away.
- Then it reboots into the installed system.

## 4. Stage 3 — log in at the desktop

At the console, log in as `ulutoyon`. **That login starts stage 3 by itself**:
`~/.zprofile` fires it on the first login shell, and there is nothing to type.

Stage 3 is the long one — packages, then `paru` built from source, then the AUR
tree. Who reboots depends on how it ran: started by the login hook (the normal
path), the HOOK ends with a 10-second countdown and `sudo systemctl reboot` —
the script itself never reboots, so a by-hand run (`base/stage3.sh desktop`)
ends with a message telling you to. If the console shows the "stage 3 done"
line but no countdown, stage 3 did NOT finish — check `~/stage3.log` against
the script's tail before believing it.

**Opening a diagnostic SSH session while it runs is safe.** The hook takes a
`flock`, and an ssh login arriving mid-run says so instead of starting a second
one:

```
>> Stage 3 is already running in another session — not starting a second.
>> Watch it with: tail -f ~/stage3.log
```

That distinction was added on 2026-07-31, when this handoff was corrected to the
manual workflow. Before it, `flock -n` returned non-zero for BOTH "someone else
holds the lock" and "stage 3 failed", so a diagnostic login during a perfectly
healthy run printed `>> Stage 3 failed`. `flock -n -E 99` separates them: 99 is
a lock conflict, anything else is a real failure.

## 5. Stage 4, at the machine

Stage 4 needs a running Plasma session — it is a systemd user unit wanted by
`plasma-workspace.target`, so it fires when you log in graphically. Same place
as everything else in this procedure: at the machine.

## Logs

| Stage | Path |
|---|---|
| 1 | `/var/log/stage1.log` — copied into the target as `/var/log/stage1.log` |
| 2 | `/var/log/stage2.log` |
| 3 | `~/stage3.log` |
| 4 | `~/stage4.log` |

All four are written with `tee`, so they exist even when a stage dies. **This is
what the laptop's SSH session is for**: `ssh ulutoyon@<address> 'cat ~/stage3.log'`
hands one over without touching the run.

**Read with `cat`, do not hold with `tail -f` — at least not under `/mnt`.** A
`tail -F` on `/mnt/var/log/stage2.log` keeps a file open on the target
filesystem, and bootstrap's `umount -R /mnt` then fails "target is busy": read
access alone stopped an otherwise perfect run on 2026-07-31. bootstrap now
retries and names the holder, but the rule stands — a watcher must never hold
an open handle below `/mnt`. `~/stage3.log` and `~/stage4.log` live on the
booted system, where no unmount follows; tailing those is fine. For stages 1 and 2 the same works as
`root@<address>` against the ISO, provided `passwd` was set in step 2.

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
