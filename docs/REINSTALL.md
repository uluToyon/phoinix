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
| `PLAYLIST_FILE` | present |
| `KEEPASS_DB` | present |
| `hosts/desktop/authorized_keys` | key material identical to the live file, so SSH survives — only the comment is sanitised, deliberately |

**`PHOINIX_DATA` replaces four of the old rows.** Since 2026-08-01 everything
the scripts read but the repo may not carry lives in one directory,
`/mnt/FilesMusic/phoinix/`, so one check covers the lot:

```
ls -lR /mnt/FilesMusic/phoinix
```

Expect `ssh/github_ed25519` (0600) with its `.pub`, `dzgui-private.json`
(0600), `dzgui-icon.png`, `claude-settings.local.json`, `vpn/` with both
`.conf` files at 0600 (CH and NL), `xlcore-backup/` at ~80 MB, and `rescue/`
(see below). No `git-credentials` — the token was retired 2026-08-04.

Two of those go stale unless refreshed by hand, because both are snapshots of
something that keeps changing — `xlcore-backup/` (run
`scripts/xlcore-backup.sh desktop`) and `claude-settings.local.json` (`cp -a`
from `.claude/settings.local.json`, which grows a line every time a permission
is granted). Anything missing there becomes a warning during stage 3, never a silent
skip — but finding it here is cheaper than finding it afterwards.

Two paths stay outside that directory on purpose, and both are listed above:
`PLAYLIST_FILE` because the playlist stores RELATIVE paths and only resolves
next to the music, and `KEEPASS_DB` because it is ulu's live database rather
than an asset of this repo.

**Two things are irreplaceable and covered by none of the above.** Copy them to a
data disk first — both are tiny:

```
install -d $PHOINIX_DATA/rescue
cp -a ~/.ssh         $PHOINIX_DATA/rescue/ssh
cp -a ~/.claude      $PHOINIX_DATA/rescue/claude
cp -a ~/.claude.json $PHOINIX_DATA/rescue/claude.json
```

(`PHOINIX_DATA` is `/mnt/FilesMusic/phoinix` — see `hosts/desktop/config.sh`.
The rescue copy lives there with everything else the repo cannot carry, ulu's
call 2026-08-01. It used to sit on the Downloads disk, which was one more place
to remember.)

- ~~`~/.ssh/id_ed25519` — the private key.~~ **No longer part of the rescue
  (2026-08-04).** That key was retired and deleted on both sides. GitHub is now
  reached with `$PHOINIX_DATA/ssh/github_ed25519`, which stage 3 installs by
  itself — it is not a rescue item but a first-class one, like the VPN configs,
  and it is still NOT in the repo and never may be (DESIGN.md "Never in the
  repo"). What the `cp -a ~/.ssh` above now saves is `authorized_keys` and
  `known_hosts`, neither of which is irreplaceable.
- `~/.claude` — the session transcripts. There is no other copy: every
  transcript older than 2026-08-01 was deleted that day. They had already
  proved their worth once — the soundbar's `−26 dB` and its reason were
  recovered out of them after the knowledge had been lost — and that fallback
  is gone, which is exactly why this copy matters.
- `~/.claude.json` — on the list since 2026-08-01. It was never part of the
  rescue before, sat only in the old backup, and went when that was deleted.

Made fresh on 2026-08-01 before the second reinstall, in
`/mnt/FilesMusic/phoinix/rescue/` (`ssh/`, `claude/`, `claude.json`). The
2026-07-31 copy on the Downloads disk was deleted earlier that day once the key
had been restored from it — and that near-miss is why this list exists at all:
a private key that lives in exactly one place is one wipe away from gone.

Since 2026-08-04 that no longer applies to the GitHub key, which has a
first-class home of its own and a stage that installs it. It still applies
word for word to `~/.claude`: there is no second copy anywhere.

### Putting the key back — stage 3 does it now

~~Nothing restores `~/.ssh`.~~ **Superseded 2026-08-04.** That was true for a
whole reinstall and cost the machine its own identity until someone noticed. It
is now stage 3's job: the GitHub key lives at `$PHOINIX_DATA/ssh/github_ed25519`
(`SSH_GITHUB_KEY` in `hosts/desktop/config.sh`), and the stage installs it with
the modes ssh insists on, writes `~/.ssh/config`, and adds github.com to
`known_hosts` only after checking the host key against `GITHUB_HOST_KEY_FP`.
Nothing to type.

The old key `~/.ssh/id_ed25519` and its copy in `rescue/ssh/` were **deleted on
2026-08-04**, together with its entry at GitHub. Do not go looking for them; the
commands that used to stand here would now fail.

What still has no automatic restore, and belongs in the run:

```
cp -a /mnt/FilesMusic/phoinix/rescue/claude.json ~/.claude.json
```

**Not `authorized_keys`.** The live one comes from the repo with a sanitised
comment; the rescued one carries the original. Copying it back would undo that
deliberately, and the key material is identical either way.

**Verify afterwards** — one line, and it proves key, permissions, host pin and
the identity rules at once:

```
ssh -o BatchMode=yes -T git@github.com     # must answer "Hi uluToyon!"
```

If it does not, the key is missing or unreadable on the data disk and pushing is
not possible until it is back. There is no second credential any more: the token
that used to serve as one lived on the same disk, so it fell with the key rather
than catching it. Cloning is unaffected — the repository is public.

~~Deliberately not scripted into stage 3: a private key is exactly the file that
must not be moved around by an installer that also runs unattended in a VM.~~
**Reversed 2026-08-04.** The objection was aimed at the *rescue* directory — a
hand-made snapshot whose absence must be noticed rather than skipped over. The
GitHub key is not that: it has a declared home in `config.sh`, like the VPN
configs the same installer has always placed, and a run in a VM finds no key
there and says so instead of copying anything. What must not be scripted is
restoring a key from a snapshot; placing a key the repo knows about is the same
class of work as the rest of stage 3.

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
