# STATUS

_Last updated: 2026-08-03 (session 12 — crackling fixed, distortion measured for the first time)_

## Session 12 — the crackling is gone, the distortion is now measurable

**Two fixes are live and in stage 3.** Realtime priority via a `LimitRTPRIO`
drop-in on `user@.service` (not `limits.d` — PID 1 starts the user manager
outside PAM, so it never reaches `pipewire.service`; and not `rtkit`, which
killed WirePlumber yesterday): FFXIV went from ~1.7 xruns per minute to 2 in
eleven minutes. And `api.alsa.headroom = 2048` with `disable-tsched` and a 4096-
frame buffer for USB devices, which had been draining to within six frames of
empty. `api.alsa.period-size` must stay 256 — raising it makes the crackling
instant, twice reproduced.

**The crackling was the AMD USB controller** (`xhci_hcd 0000:0c:00.0`, 120
`Frame ID … beyond range` entries during it). The Concept 12 hangs off the
ASMedia controller, which logged nothing, and since the output went back there
ulu reports no crackling at all. **Audio devices belong on the ASMedia
controller.**

**The distortion is the remaining fault, and it is not** electrical pickup (
silence is silent), not a speaker (a sine through each of the six is clean), not
PipeWire scheduling, not the game's stream, and not visible on a test tone — it
needs real material. It is load-dependent.

**It has now been measured**, with `scripts/audio-distortion-probe.py`: over 372
seconds, ten blocks where the microphone carries 23–35 dB more high-frequency
energy than the digital signal accounts for, **all inside one 73-second
window**, matching ulu's "3 oder 4 Vorkommnisse". Not proof yet — repeat it, and
if the excess keeps landing in bounded windows the bar is convicted by its own
output.

**Read the tooling section of the `LOG.md` entry before recording anything.**
`pw-record --target` silently falls back to the default source and produced
three worthless "paired" recordings in one evening. Use `parec -d` and verify
with `pw-link -l`.

_Previously: 2026-08-02 (session 11 — the glitching is two faults, not one)_

## Session 11 — audio only, and it finally split in two

Nothing was installed, nothing in the scripts changed except `packages/audio.txt`
(see below). This session was measurement, and it ended the two theories that
had been running since 2026-07-31.

**The glitching is two separate faults.** Playing an evening through the Scarlett
Solo instead of the Concept 12 — the one test never run in days of work — showed
the crackling is present on both devices, but "quieter and shorter, and not so
electrically distorted". The kernel log then separated them cleanly: the AMD
chipset controller (Scarlett, Bluetooth, input devices) logs bursts of
`xhci_hcd … Frame ID … beyond range`, isochronous audio packets the host
controller could no longer schedule — lost *below* PipeWire, which is why no
xrun is counted and the digital capture is clean. The ASMedia controller, where
the Concept 12 hangs, logged nothing at all evening. Full evidence in `LOG.md`.

**The xrun theory is dead.** `clock.force-quantum 1024` made the crackling
almost continuous while the xrun counters did not move at all — reverted, and
the state is back to the default. The realtime deficit is real and measured, but
it is not the sound ulu hears.

**The Concept 12's fault is invisible from this computer.** Clean digital
stream, no xrun at the moment of the report, no kernel message. Every observable
has been checked. The next instrument is the microphone on the Scarlett:
recording the room while the bar plays is the first measurement that looks at
the artefact itself rather than at its absence everywhere else.

**`rtkit` is rejected**, see the session-10 note below and `packages/audio.txt`.
That is the only repo change of this session.

**ulu's own observation is the best lead, and it may undo that split:** the
faults only appear while a game is open — both of them. During play the GPU sits
at 100 %, `gamemoded` is active, and PipeWire runs `nice 0` / `SCHED_OTHER`
against it. One cause, two layers: a late audio thread is an xrun, a late USB
packet is a frame-ID error.

**Next, and it is ulu's to run:** music alone through the bar for ten minutes,
then the same with the game running at in-game volume zero. Crackling in the
second case means system load; a clean second case means Wine/Proton's audio
path. Only after that is the `limits.d` realtime question worth reopening.

**Live machine state at the end:** output back on the Concept 12 at 37 %,
default quantum, `rtkit` uninstalled, no phoinix processes left running.

## Session 10 — what changed and what is still open

Started from one observation of ulu's: with the VPN up, some sites believed he
was in Switzerland.

**DNS: fixed, live and in the scripts.** The split tunnel separated packets but
not names — every lookup on the machine left through Proton, so CDNs placed the
whole desktop in Zurich. Stage 3 now strips the resolver from the Proton
profiles (7b) and puts Quad9 over strict DoT on the wired link with the LAN
router scoped to its own DHCP domain (new section 7c; printer moved to 7d).
`config.sh` carries the resolver as a decision. Details in `LOG.md`.

**One manual step is outstanding**, and until it is done `fritz.box` resolves to
a stranger's host on the public internet (the router answers on
`192.168.178.1`): the generated `/etc/systemd/resolved.conf.d/10-phoinix-lan.conf`
needs root. On a fresh install stage 3 writes it itself — this is only the live
machine catching up.

**Audio: the −26 dB theory is dead, and a real defect turned up next to it.**
ulu still hears glitches in FFXIV and DayZ, so the level was never the cause
(this was the condition STATUS named for reopening). Found instead: **PipeWire
never gets realtime priority** because `rtkit` is not installed. It produces
measurable xruns, but reported glitches keep falling on moments with none at
all, and ulu describes the sound as "distortion, very electronic", which is not
what a missed buffer sounds like. The digital output has now been recorded and
analysed twice, in two sessions: clean both times. So the cause sits downstream
of the computer — USB transport, the Concept 12's electronics, or the analog
chain.

**`rtkit` was tried on 2026-08-02 and is rejected** (`packages/audio.txt`,
`LOG.md`). It did grant PipeWire the priority — and WirePlumber was then killed
with SIGKILL within seconds of every start, 23 times running, until every ALSA
device had disappeared. Uninstalling it restored the machine. The realtime
question is therefore still open, and the desktop is back to `SCHED_OTHER`.

**Steam and DZGUI: unblocked, nothing to change in the repo.** Every Steam game
failed with "compatibility tool failed" until the client was restarted with its
`appinfo` cache moved aside, and DZGUI then hung half an hour on mods Steam
never downloaded — the Web-API subscriptions are accepted but the running
client only syncs them at logon. Both are client-state problems, both are in
`LOG.md` with the exact log lines, because neither is diagnosable from the
symptom.

## Pick up here

**ulu reinstalls again, right after this session.** The first run (2026-08-01,
morning) closed its whole nine-point list; everything it turned up was fixed the
same day, applied live AND written into the scripts. But the live proof is worth
little for the same reason as last time — these fixes exist for the fresh-install
case, and this machine is no longer one. That is what the next run measures.

Pre-flight was done at the end of the session: repo pushed, `check-drift.sh`
clean (10 in sync, 0 drifted), `PHOINIX_DATA` complete, boot stick `ARCH_202607`
plugged in, xlcore backup refreshed after today's FFXIV session, and the rescue
copy remade — see `REINSTALL.md`, which is the file to follow.

### What the SECOND run must verify

1. **Strawberry opens unmaximized**, `1920x2105` at DP-2's origin, and the
   sponsoring dialog does not appear at all. Both are new since the last run.
2. **The playlist import reports a track count** — `playlist: imported …
   (160 tracks)`. It now waits for `/tmp/kdsingleapp-<user>-strawberry` and
   retries up to four times. A bare warning still means it genuinely failed.
   **The retry path has never fired in anger**; this run is its first real test.
3. **`strawberry.conf` comes out intact.** Written by `qs_set` now, not
   `kwriteconfig6`. A fresh install cannot expose the bug that motivated it, so
   what this run proves is only that the new writer works at all — the
   corruption case needs a RE-RUN to show, and no post-install step demands one
   any more.
4. **Three desktop icons, in a row that means something**: XIVLauncher at
   `2,2`, DZGUI at `2,3` (directly right of it), monitor switch at `4,4` — and
   DZGUI must carry the DayZ artwork, not a generic theme icon. Cells are
   **ROW,COLUMN**; the first number moves an icon down.
5. **The Places order is applied, not skipped.** The step now waits up to 30 s
   for `user-places.xbel` and its closing tag. Last time it lost that race by
   under a second.
6. **Everything resolves out of `PHOINIX_DATA`** — VPN configs imported, DZGUI
   config seeded without its wizard, the DayZ icon installed, the xlcore backup
   restored, `git push` working without a prompt. Five paths that all moved
   today, so a typo in any of them shows up here first.
7. **No step asks for a second stage 3 run.** Both reasons were removed today.
   If any output still says "re-run stage 3", something was missed.
8. **`~/.ssh` must be restored BY HAND** — `REINSTALL.md`, "Putting the key
   back". Nothing scripts this, and its absence is invisible because incoming
   SSH keeps working. This is the one that got missed last time.

### The first run — all nine points resolved



1. **Desktop icons get positioned.** The stopper. Stage 4 now finds the Folder
   View containment by `lastScreen` + activity instead of `lastResolution`
   (which Plasma writes only after icons were arranged by hand, so a virgin
   install never had it). Expect the log line `desktop icons on 3440x1440
   (containment N)` and the two icons on cells 2,2 and 4,4. A `WARNING: no
   folder containment for DP-1 (screen ?)` means the screen lookup failed, not
   the matcher.
2. **qBittorrent starts at all.** It could not, because `sg` no longer exists
   on Arch; the wrapper uses `newgrp` now and VERIFIES the resulting gid.
   Launcher and autostart both go through it, so both of ulu's reports hang on
   this one line.
3. ~~**The playlist import reports a track count.**~~ **FAILED on the run, and
   the honesty is the good news** — it warned instead of lying, which is what
   the session-7 rewrite was for. Three causes, all fixed 2026-08-01: stage 4
   beats the autostart entry by 21 s (so it always starts Strawberry itself),
   it waited for the *process* rather than the single-instance socket, and a
   one-second-old Strawberry silently drops the message anyway. Now: wait for
   `/tmp/kdsingleapp-<user>-strawberry`, retry up to four times, verify against
   the database, and log the output instead of discarding it. ulu's playlist is
   imported (160 tracks). See `LOG.md` 2026-08-01.
4. **Stage 3 sets the commit identity.** `git: repo-local identity set to
   uluToyon <…>` must appear, and afterwards `git var GIT_AUTHOR_IDENT` in
   `~/phoinix` must answer. On the run just made it did NOT exist at all.
5. **KeePassXC autostarts and lands bottom-right on DP-2**, below qBittorrent.
6. ~~**FFXIV opens borderless on DP-1**~~ **PASS 2026-08-01** — ulu played and
   reported everything correct. The preconditions were checked in the config
   afterwards: the rule carries `position=3840,1120 size=3440,1440` with the
   class **and** title match, and `launcher.ini` has `WaylandEnabled=false`
   (plus `GameModeEnabled=true` and both game paths on the games disk). That
   `WaylandEnabled=false` is what makes the rule possible at all — a
   Wayland-native client cannot be positioned by anyone — and it survived the
   reinstall because it travels in the xlcore backup.
7. ~~**Places order: expect this one to be SKIPPED again, and watch it.**~~
   **SKIPPED as predicted, cause measured, FIXED 2026-08-01.** The observation
   the decision was waiting for: stage 4 warned at 12:13:44 and the file was
   created at 12:13:44.871 — the same second. A race, not an ordering problem.
   Fixed by a bounded wait (30 s, for the file AND its closing `</xbel>`)
   rather than by moving the step, which would have been the same bet with
   better odds. Order applied live: six labels resolved, 22 bookmarks intact.
   See `LOG.md` 2026-08-01.
8. ~~**NumLock is on at the GREETER**~~ **PASS 2026-08-01** — ulu confirmed the
   keypad was live at the login screen. The diagnosis behind it holds: KWin
   reads `Keyboard/NumLock` from the greeter's own `kcminputrc`, the login
   manager has no such option (LOG 2026-08-01). This one could only ever be
   verified by a real login, which is why it went on this list unverified.
9. ~~**Watch Strawberry's first start.**~~ **DONE 2026-08-01, and the cause was
   one step deeper than the parked diagnosis.** The main window was not
   oversized, it was **maximized** — 3840x2105 is exactly DP-2's maximize area
   — because Strawberry starts maximized without a saved geometry. The rule
   fired correctly on both windows; the maximizing simply came after it. Fixed
   declaratively (ulu's call): `maximizehoriz`/`maximizevert=false`, Apply
   Initially, in stage 4's Strawberry rule. Verified against a saved
   `maximized=true`, i.e. the harder case. **The parked KWin script was NOT
   built** and is now more expensive than it looked, because it would have had
   to demaximize as well. The dialog case reproduced exactly as session 7
   described it (`transient=true` is still the only discriminator) and stays
   parked. See `LOG.md` 2026-08-01.

### After the run — manual steps

Steam: log in → Settings → Storage → add `/mnt/Games/SteamLibrary` → quit
Steam → delete `~/Desktop/steam.desktop`. **No stage 3 re-run needed** — the
DZGUI entry is a desktop icon now, placed on the first run. Then the
Strawberry music folder, Brave sync, KDE Connect pairing, pCloud login,
printer switched on before stage 3.

### Was NOT reproduced by a script and must not be forgotten

The live desktop currently carries hand-made state that this session captured
into the repo — KWin rules for KeePassXC, its autostart, the icon cells, the
Places order. If any of it is missing after the reinstall, the capture was
incomplete, and that is a finding worth logging rather than repairing by hand.

**Identity leak on the laptop, contained, follow-ups open** (LOG
2026-07-31): the laptop's shell profile exports `GIT_AUTHOR_NAME` etc. with
the real name, which OVERRIDES the repo-local identity. One commit was public
with it for ~2 minutes before amend + force-push. Open: whether GitHub's
retention of the orphaned commit warrants the same response as last time
(repo re-created), and a durable guard for laptop commits — until then every
commit from the laptop needs the env override by hand.
**Session 7 narrowed this, but not for the laptop.** Stage 3 now sets the
repo-local identity itself and warns when a global identity or `GIT_AUTHOR_*`
in the environment would override it (LOG 2026-08-01) — which closes the hole
on any machine the installer touches. The laptop is deliberately not one of
them, so there the manual override still stands.

Also still queued: **`fixes/`** — the curlable collection, parked by ulu on
2026-07-31 and described under "Later, with ulu".

**chezmoi is decided: rejected (2026-07-31).** Its one remaining rationale was
templating across machines, and ulu settled that — the laptop will never run
this installer. What it would really have bought us is drift detection, and that
is now `scripts/check-drift.sh`. Run it with `./scripts/check-drift.sh desktop`;
it exits non-zero when a captured file and the live one disagree. Full reasoning
in `DESIGN.md`.

**The soundbar is set back and captured (2026-07-31).** ulu chose the first
option: exactly −26 dB, not a hunt for where the glitching starts. Live sink and
the repo copy of `default-routes` both carry `channelVolumes 0.050120`, which is
the value the recovered transcripts document as tested glitch-free — an exact
match, not an approximation. ulu confirmed the level right afterwards ("passt
so, lass es auf -26"), so the 2.77 dB drop is fine in daily use and the
"probe upward" option is **closed, not deferred** — do not reopen it.

~~**What is not settled is whether the glitching is gone**; that needs hours of
FFXIV or DayZ, and only ulu can report it. If it still glitches at −26 dB, the
level was never the cause and the investigation reopens somewhere else entirely.~~
**ANSWERED 2026-08-01, session 10: it still glitches, at −26 dB, in both games.**
The level was never the cause, exactly as this paragraph anticipated. Where the
investigation went instead is under "Session 10" at the top and in `LOG.md`.
One correction that follows from it: the −26 dB is the *device's* hardware
volume, not a digital attenuation — it never touched what the machine sends.

Deferred by ulu, not forgotten: **`kdeconnect` is in `packages/kde.txt` but not
installed on this desktop** (`sudo pacman -S --needed kdeconnect`, then pair the
phone by hand). It costs a fresh install nothing — the package list is what a
reinstall reads, and that is already correct.

### Dropped on purpose, 2026-07-31 (ulu's call)

**The QEMU run for session 5's changes, and the work to make the harness
runnable unattended — both discarded.** Recorded rather than deleted, because
the consequence outlives the decision:

Stage 2 (udev rules), stage 3 (the monitor-switch `.desktop`) and stage 4
(multi-icon `positions`) changed and never went through the VM. Two of the three
are verified on the real desktop — the udev rules by the launcher working, the
switch by ulu watching all three monitors flip. **Stage 4's icon JSON is not.**
It exists only as arithmetic checked against ulu's running Plasma; the script
has never written it. If desktop icons land in the wrong place after the next
reinstall, that is where to look first.

Why the harness could not simply be automated, so nobody re-derives it:
`qemu-test.sh` puts the serial console on stdio via `-nographic`, and QEMU does
not read a stdin that is not a terminal — checked three ways (direct, via a log
file, via a FIFO with a persistent writer; `/proc/<pid>/fd/0` pointed at the
FIFO every time and neither LF nor CR reached the guest). `qemu-mon.sh type` is
no way round it: `[a-z0-9]` only, deliberately, and the bootstrap line needs
`:` `/` `|`. A pseudo-terminal instead of stdio would fix it. That is the work
item that was dropped, not a mystery.

Driving it by hand still works and is documented in `qemu-test.sh` — it just
takes two terminals, a `pkill qemu-system` between stage 2's reboot and
`--installed`, and a password of `[a-z0-9]` only so the KDE greeter can be typed
into afterwards.

The fixtures stay: `hosts/qemu/config.sh` sets `MONITOR_SWITCH` and
`DESKTOP_ICONS`, so if anyone ever does run it, it exercises those paths instead
of skipping them and passing for nothing.

Both items that stood here at the start of session 5 are closed:

- **keychron-launcher** — done. The launcher was failing because
  `/etc/udev/rules.d/` was empty, not because of anything on the keyboards.
  `system/udev/50-qmk.rules` (flashing) and `system/udev/51-keychron-launcher.rules`
  (raw HID) are in the repo and installed by stage 2; verified working on the
  running machine, ulu confirmed the launcher sees both devices. See SETTINGS
  under stage 2 and LOG 2026-07-31.
- **The complicated question** — GitLab-style superprojects on GitHub. Answered
  and closed (they are git submodules; phoinix stays one repo). It produced one
  parked idea, `fixes/`, listed under "Later, with ulu" below.

Closed with it: **no device configuration is carried in this repo, and none is
needed.** ulu has remapped nothing on either device, so there is no layout to
export — and key mapping lives on the hardware anyway, which a distro-hop does
not touch.

The M6 already appears once elsewhere, indirectly: stage 4 turns pointer
acceleration off for *every* pointer precisely so no mouse has to be named.

## Done in session 4

**The one command.** The whole install runs from one line on the ISO:

```
curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
```

Each stage arms the next: bootstrap → 1 → 2 (chroot) → reboot → login hook → 3
→ reboot → systemd user unit → 4. Two human inputs remain, both ulu's explicit
choice: the password for the new user, later the sudo password.

**Tested end to end in QEMU: PASS**, and the run found six real defects, five of
which would have hit the next reinstall — the worst being that `bootstrap.sh`
did nothing at all under `curl | bash`. None was visible by reading the scripts.
`scripts/qemu-test.sh` is the harness, `hosts/qemu/` the throwaway machine.
Not covered there: captured configs (`CAPTURED_CONFIGS=0`), so the monitor fix
and the audio state are exercised on the desktop only.

**ProtonVPN as a split tunnel, live and measured.** Only qBittorrent uses the
VPN; only through the VPN can it reach anything. Ordinary traffic leaves via
`enp8s0`, group traffic via `proton0` with an exit inside Proton's network, drop
counter 0 in normal use, and with the tunnel down the group is blocked by name
and by raw IP while everything else keeps working. Getting there refuted the
first design three times (`LOG.md`).

**The application phase is finished** — all thirteen: Dolphin, Konsole,
Strawberry, KeePassXC, ProtonVPN, qBittorrent, Discord, Brave, Steam,
LibreOffice, mpc-qt, DZGUI, XIVLauncher. haruna was evaluated and rejected.
`SETTINGS.md` is the inventory; the rounds and their findings are in `LOG.md`.

### Resolved: the old AirVPN files are gone

`/mnt/FilesMusic/OpenVPNConfigs` held four **AirVPN** `.ovpn` files (2022 and
2024) with inline private keys. The repo used to describe them as ulu's
ProtonVPN profiles, which they never were. He deleted the directory himself
during the 2026-07-31 clean-up, along with `/mnt/FilesMusic/Linux/`.

## Where we are

- **The system is installed and in daily use.** All four stages exist, all
  have run, and stage 4 has now fired from a real login. Sessions run locally
  on the desktop in `~/phoinix`.
- **Post-install verification is complete** — every test point below passes.
- **The repo is self-contained** (since 2026-07-31): captured config lives in
  `hosts/<host>/home/` and `dotfiles/`, not in an external backup. A missing
  source is a hard error rather than a silent skip.
- **All session transcripts before 2026-08-01 are gone** (ulu deleted the
  Downloads-disk copies that day: `backup-nvme1n1-20260730/`, `rescue/`,
  `keepassxc-pre-merge-2026-07-31/`). They had proven useful beyond restoring —
  the soundbar's −26 dB and its reason were recovered out of them after the
  knowledge had been lost. That fallback no longer exists, which raises the
  stakes on `LOG.md`: a rationale that is not written down here is not
  recoverable anywhere else.
- Repo is live: https://github.com/uluToyon/phoinix (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## Working mode (session 2 onwards)

ulu names an app or a setting; it gets applied on the live system and written
into the scripts in the same step — no big capture at the end. Plasma settings
that need a running shell go into `base/stage4.sh` (see DESIGN.md).

**How a setting is recorded (decided 2026-07-31):** deliberate decisions are
written key by key with `kwriteconfig6` in stage 3, each with its reason in a
comment. **Exception, learned on qBittorrent and then AGAIN on Strawberry:**
`kwriteconfig6` only suits KConfig files. On a Qt/QSettings file it escapes the
backslash that acts as a group separator, rewrites the whole file, and produces
settings the application never reads — plus it re-encodes every `@ByteArray`
value into garbage. Such files go through **`qs_set`**, the shared
line-oriented writer at the top of `stage3.sh` (2026-08-01; it used to be
`qbt_set`, local to the qBittorrent block, which is exactly why the mistake got
made a second time). **A fresh install cannot expose this bug** — there is no
file yet to corrupt — so it only ever appears on a re-run. Whole-file capture into `hosts/<host>/home/` is reserved for what
cannot sensibly be authored by hand — `kwinoutputconfig.json`, the wireplumber
state, `p10k.zsh`. For a click-through round: snapshot `~/.config`, let ulu
change things, then diff.

## In discussion (not yet decided) — one topic at a time, per ulu

- ~~Stage 3 notes: aliases, zsh config, KDE shortcuts.~~ **All done.** The
  aliases now live in `~/.config/phoinix/aliases.zsh`, a file phoinix owns and
  rewrites every run — the old inline block in `.zshrc` was written once and
  could never gain an entry. Shortcuts are written as deviations, not captured.
- ~~**chezmoi: still undecided.**~~ **REJECTED 2026-07-31** — see `DESIGN.md`.
  The shell config stays in `dotfiles/` as plain files stage 3 installs
  directly; `scripts/check-drift.sh` covers the one thing chezmoi was still
  wanted for.
- **Mount-path legacy: DECIDED — clean re-wiring, no compat symlinks.**
  Restored configs get new `/mnt/<Label>` paths. Checklist status:
  Steam library **done**, XIVLauncher game path **done**
  (`GamePath=/mnt/Games/FFXIV/`, and `GameConfigPath` now points at the games
  disk so the character config survives by construction).
  **Still open: re-run MateriaForge for 7th Heaven** — never touched, and the
  only item of this decision left.

## Decided so far

- Kernel: `linux-zen` only. Editor: `micro` only (vim banned, nano not
  installed). Login shell: zsh (in pacstrap so stage 2 can set it at useradd).
- **KWallet: `kwallet-pam`** — no creation dialog, no password prompt, and
  the secret store stays intact. See `LOG.md` for the rationale and the two
  rejected alternatives.

## Stage-2 requirements collected so far

- Enable `[multilib]` in pacman.conf (lib32 gaming packages).
- Set zsh as ulu's login shell at useradd (zsh is in pacstrap).
- Ship a minimal global zsh config so first login has no setup wizard.
- Boot entry: `video=DP-2:3840x2160@144` (monitor-bug fix, console phase).

## The monitor bug and its baked-in fix (decided)

4-monitor setup exceeds DP bandwidth when amdgpu inits all displays at max
modes (TCL 27" 4K wants native 180Hz w/ DSC) → black screen at first login
manager start on every fresh distro. Proven fix: cap that monitor at 144Hz.
phoinix bakes it in BEFORE first graphical start:
1. stage 3 restores the backed-up `kwinoutputconfig.json` (contains the
   144Hz cap + HDR/VRR/layout, keyed by monitor EDID) to ulu's ~/.config
   AND to the PLM greeter's config dir, before enabling graphical login.
2. stage 2 adds the video= kernel arg for the console phase.
Wishlist: once running, test whether newer kernels handle 4K@180 w/ DSC on
this topology — until proven, the cap stays.

## Later, with ulu (wishlist)

- **jdownloader2 and pcloud-drive: configure them.** Requested by ulu
  2026-07-31 during the first real run. Both packages come in via stage 3
  (AUR), but nothing about either is captured or decided yet — for jdownloader2
  the download directory and clipboard watching, for pcloud-drive whatever goes
  beyond the manual login that is already listed under "Post-install manual
  steps". Same working mode as every app: apply on the live system, write into
  the scripts in the same step.
- ~~mpc-qt: switch to the binary package (`mpc-qt-bin`) if possible.~~ **DONE
  2026-07-31, same evening.** Both checks passed (same version 26.07-1; the
  only path dependency is stage 4's KWin rule, which already matches both
  wmclass spellings). `packages/aur.txt` carries the switch and the caveat
  (the -bin package renames the desktop file). Rationale in `LOG.md`.
- ~~**gamemode for FFXIV.**~~ **DONE 2026-07-31, later the same evening.** The
  entry was half stale when it was written: `gamemode` and `lib32-gamemode`
  were already installed and already in `packages/gaming.txt`. The missing
  half — XIVLauncher actually invoking it — was not a wrapper question at all;
  the launcher has its own toggle, and ulu flipped it (`GameModeEnabled=true`
  in `launcher.ini`). Captured by re-running `scripts/xlcore-backup.sh desktop`,
  which is what makes it survive a reinstall: stage 3 restores `launcher.ini`
  from `XLCORE_BACKUP_DIR`, so an unrefreshed backup would have quietly put
  the old `false` back.
- fzf deep-dive: ulu didn't know he had it and wants a proper tour of what
  it can do (history search, file finding, previews, zi) once the system runs.
- **`fixes/` — a curlable collection.** Parked by ulu on 2026-07-31 ("halte dir
  den gedanken erstmal im hinterkopf"), not started. Two purposes he named:
  publishing the fixes for others, and reaching them himself after a
  distro-hop — `curl` the one script, done. Shape agreed if it ever happens: a
  directory in THIS repo, not a second one, with the hard rule that a script
  only qualifies if it runs on a machine that has never seen phoinix (no
  `config.sh`, no `REPO_DIR`; parameters via arguments or environment). Where it
  fits, the stages call the same script, so the installer stays the fixes' test
  harness and no second copy can rot. Surveyed candidates: mpc-qt repair, the
  nftables split-tunnel table, the QEMU harness — everything else in `scripts/`
  reads `hosts/<host>/config.sh` and does not qualify. The bulk of what we
  learned is knowledge, not scripts, and belongs in LOG.md either way.
- ~~Evaluate haruna vs. mpc-qt~~ and ~~the VPN session~~ — both done 2026-07-31.

## Post-install manual steps (not scriptable)

- **Strawberry: add the music folder to the collection by hand** —
  Settings → Collection → Add → `/mnt/FilesMusic/Musik`. **An empty collection
  looks exactly like a working one**, which is how it was missed on 2026-08-01:
  the imported playlist plays fine without any collection at all, because
  playlist entries carry their own paths. Check the Collection view, not the
  playlist. Verify from the database if in doubt:
  `sqlite3 ~/.local/share/strawberry/strawberry/strawberry.db "SELECT count(*) FROM songs;"`
  Deliberately not scripted, **re-decided 2026-08-01 with the scripted version
  fully designed** (one row in `directories`, `schema_version` guard, rescan
  verified like the playlist import): ulu chose to keep it manual rather than
  have phoinix write into a database another application owns. See `LOG.md`.
  (Done on this machine 2026-07-31: `/mnt/FilesMusic/Musik`, 55 559 tracks.)
- ~~Strawberry: re-save the playlist after adding tracks.~~ **Automated
  2026-07-31.** `scripts/strawberry-playlist-export.sh` rewrites
  `/mnt/FilesMusic/Musik/Default.m3u` from Strawberry's database on session
  exit, so the file tracks the playlist by itself. Stage 4 imports it back on a
  fresh install. Accepted cost (ulu's call): a crash or power cut loses that
  session's additions.
- ~~**GitHub authentication has to be re-established by hand after every
  reinstall.**~~ **SOLVED before the reinstall (`230470e`) and PROVEN by it
  (2026-08-01).** The problem was real — a fresh machine has no `gh`, no SSH
  key, no credential helper and no stored token, and none of that may live in
  this repo (`DESIGN.md`, "Never in the repo"). The fix follows the
  `VPN_CONFIG_DIR` shape: the token lives in `GIT_CREDENTIALS_FILE` on the
  FilesMusic disk (`/mnt/FilesMusic/phoinix/git-credentials`, mode 0600, one
  line `https://uluToyon:<token>@github.com`), and stage 3 wires it as a
  **repo-local** `credential.helper` — repo-local because a global one would
  offer the token to every clone on the machine. Only the path is versioned.
  Verified on the fresh system: the helper was set by stage 3 and
  `git ls-remote origin` authenticated without a prompt.
  The token is fine-grained, limited to `uluToyon/phoinix`, permission
  "Contents: Read and write", and **has no expiry date** (ulu, 2026-08-01).
  `config.sh` used to claim it expires and pointed here for a date that was
  never written; both are corrected. Nothing rots on a timer, and the trade is
  the usual one: a leaked token stays valid until revoked by hand at GitHub.
- **KDE Connect: pair the phone by hand.** The pairing exchanges keys between
  the two devices and is confirmed on the phone, so it cannot be scripted from
  here. Nothing else is needed — the package is in `packages/kde.txt` and our
  nftables table has no input chain, so its ports are not blocked.
- **Steam, in this order** (verified 2026-07-31): log in, then Settings →
  Storage → add drive → `/mnt/Games/SteamLibrary`. The 39 installed games
  reappear without re-downloading — the library carries its own identity in
  `/mnt/Games/SteamLibrary/libraryfolder.vdf`, and Steam matches on it.
  Then **delete `~/Desktop/steam.desktop`**, which Steam creates on first
  launch — and **re-run stage 3 once**, which restores the non-Steam shortcuts
  (DZGUI) now that `userdata/` exists. Quit Steam first; it rewrites that file
  on exit. Not scripted, for a reason worth recording: no suppression flag
  exists (Steam's `registry.vdf` has no such key and `/usr/bin/steam` does not
  create the file — the client does, during its first run), and both stage 3
  and stage 4 run *before* Steam has ever started, so neither can delete a file
  that does not exist yet.
- **Why the Steam library is not scripted.** It could nearly be: the
  `contentid` is not invented per install, it lives with the disk in
  `/mnt/Games/SteamLibrary/libraryfolder.vdf`. But `libraryfolders.vdf` only
  exists once Steam has run and logged in — and at that moment the user is
  already in the UI where two clicks do it. Scripting the case that matters,
  the fresh install, would mean fabricating the whole file before Steam's first
  start, which cannot be verified here (the QEMU host has neither a Steam
  account nor the games disk). An unverifiable script whose failure silently
  hides 837 GB is the worse trade against twenty seconds of clicking.
- ~~**mpc-qt: start it once before stage 3 can write its settings.**~~
  **DROPPED 2026-08-01 (ulu): phoinix no longer configures mpc-qt at all.**
  The settings could not be seeded (segfault on a settings file without a
  geometry file, see `SETTINGS.md`), so they could only be written into an
  existing profile — which meant running stage 3 a second time. ulu
  configures the player himself instead. The stage-4 window rule stays: it
  needs no profile and no re-run.
- **Printer: switch it on before stage 3**, or the queue is skipped with a
  warning — the device URI can only be resolved from a device that answers.
- Brave: join the sync chain by hand (profile comes via Brave Sync).
- pCloud: log in by hand (credentials in KeePassXC on FilesMusic).
- ~~ProtonVPN: import .ovpn profiles by hand.~~ **Obsolete 2026-07-31** — replaced by the
  scripted WireGuard split tunnel. Manual part left: generating the configs at Proton (done).

## Post-install test points

Verified on the desktop (session 2):

- **Keyboard layout: PASS.** `localectl` reports VC keymap `de` AND X11
  layout `de` — the stage-2 fix (vconsole KEYMAP alone leaves KDE in
  English) does what it promises.
- **Shell restore: PASS.** First Konsole start needed zero input: zinit
  cloned itself, pulled and compiled all 9 plugins, installed 191
  completions, powerlevel10k fetched gitstatusd, and the tuned p10k prompt
  came up with correct Nerd Font glyphs. No `zsh-newuser-install` wizard —
  the empty user `.zshrc` from stage 2 does its job.
- **Plasma monitor layout: PASS (in-session).** All four outputs enabled,
  DP-1 ultrawide 3440x1440@170, DP-2 (TCL 27") 3840x2160**@144** — the cap
  holds — DP-3 2560x1440@144 portrait, HDMI-A-1 3840x2160@120. HDR and wide
  colour gamut on all four.
- **Full 4-monitor PLM test: PASS.** Reboot with all four displays live on
  the PC: picture on all four, no black screen, greeter came up clean. Bonus
  result — the password field appeared on DP-1 (the main monitor) for the
  first time ever; without a restored config KWin used to pick the TV on
  HDMI. The restored `kwinoutputconfig.json` carries a per-output `priority`
  (DP-1=1 primary, DP-2=2, DP-3=3, HDMI-A-1=4), and the greeter copy honours
  it. The monitor-bug fix thus solves the wrong-primary annoyance too.
- **KWallet silent unlock: PASS.** No wallet window of any kind at login —
  neither the Blowfish/GPG dialog nor a password prompt. Journal confirms the
  full PAM chain (`pam_kwallet5`: authenticate → setcred → open_session,
  socket `/run/user/1000/kwallet5.socket`, unit "Unlock kwallet from pam
  credentials"), the store was created at login time
  (`~/.local/share/kwalletd/kdewallet.kwl` + `.salt`), and `ksecretd` runs
  with `--pam-login`, i.e. it got its credentials from PAM. `kwallet-pam` in
  `packages/kde.txt` is therefore the whole fix — nothing else needed.
  Cosmetic leftover: `ksecretd` logs a failed portal registration
  ("Connection already associated with an application ID") on PAM start.
  Harmless; revisit only if an app stops remembering its passwords.
- **Regional formats: PASS** (verified after a real re-login). The session
  exports `LANG=en_US.UTF-8` with all nine `LC_*` format variables on
  `de_DE.UTF-8`; `LC_MESSAGES`/`LC_COLLATE` stay English by design. `date`
  prints the German form, and the panel clocks show `00:16` / `31.07.2026`
  — so the Plasma clock honours `LC_TIME` and needs no per-widget format,
  i.e. nothing extra to script in `plasma/panels.js`.

- **Stage 4 at a real login: PASS.** Marker deleted, rebooted, logged in
  normally — the unit fired out of the login (`status=0/SUCCESS`) and did the
  full run: launchers, 7 widgets cloned to the TV, both side strips, Kickoff
  favourites against the fresh activity UUID, plasmashell restart, marker
  rewritten. The systemd arming path works unattended. Every stage of phoinix
  has now run in the mode it was designed for.
- **Shutdown hang: PASS.** The plasmashell drop-in (order before kwin, 10 s
  cap) removed the 40 s stall — `Stopping`/`Stopped KDE Plasma Workspace` in
  the same second, shutdown is instant.

Still open:

- ~~**Soundbar: the captured value is NOT the verified one.**~~ **RESOLVED
  2026-07-31.** The gap was real: the transcripts document the tested fix as
  `channelVolumes 0.050120` = −26.00 dB, while repo and live system had crept to
  `0.068923` = −23.23 dB, 2.77 dB louder. ulu chose to set it back rather than
  probe upward. Done and captured — the live file now reads 0.050120 exactly,
  and the repo copy matches it byte for byte.
  Two things worth keeping from the doing: `pactl set-sink-volume SINK -26dB`
  reads the leading minus as a RELATIVE decrement and landed on −49.23 dB, and
  `--` does not rescue it (pactl rejects it as an invalid specification). The
  absolute route is the raw PA value, `65536 × linear^(1/3)` = 24163, because
  PulseAudio's scale is cubic while `channelVolumes` is linear amplitude.
  **Still unknown: whether the glitching is actually gone.** That needs hours in
  FFXIV or DayZ and only ulu can judge it.
- ~~ulu's real name and work e-mail are on GitHub.~~ **RESOLVED 2026-07-31,
  history rewritten and the repository recreated.** Details in `LOG.md`.
  Standing consequence: **there is no global git identity on this machine**,
  and the repo sets `uluToyon` + the GitHub noreply address locally, so new
  commits carry the anonymous identity automatically. Do not add a global
  `user.name`/`user.email` — that is exactly how 35 commits acquired the real
  name in the first place.
  ~~Out of scope but worth remembering: the old system's backup on the Downloads
  disk still contains the name.~~ **Gone 2026-08-01** — ulu deleted those
  directories, so the last copies of the name on this machine went with them.
  It was never published in the first place; now it is not on disk either.
- **KeePassXC: a pointless private key sits in `keepassxc.ini`.** KeePassXC
  generated a KeeShare signing key when that settings page was opened; the
  share list is empty, so it protects nothing. Deleting the `[KeeShare]`
  section removes it; it only comes back if the page is opened again. phoinix
  never touches that section either way. ulu's call.
- **KeePassXC databases: 4 conflict copies deleted 2026-07-31** (ulu's call —
  sizes grew monotonically, so divergence was unlikely), **and the pre-merge
  backup was deleted 2026-08-01.** There is no way back now: if an old entry
  turns out to be missing from `KEEPASS_DB`, it is missing for good. The
  divergence was never proven either way, only judged unlikely. Syncthing
  (which caused the conflicts) was retired years ago and is deliberately not
  part of phoinix.
- **Application phase — process rules learned on Dolphin:** close a KDE
  application before diffing (they write their config on exit), and treat a
  file that merely grew with suspicion rather than dismissing it as noise.
- **RUNNING EXPERIMENT — DP-1 at 144Hz instead of 170Hz.** Started 2026-07-31
  against the years-old sporadic black flash on the ultrawide. Diagnosis in
  `LOG.md`: the link runs 4 lanes at HBR3 with no DSC and no FEC, i.e. at the
  DP 1.4 ceiling with ~82% utilisation, where one bit error costs a retrain —
  and a retrain is a black flash the kernel never logs. Watch for a few days.
  **No flash → confirmed**, and a certified DP cable should buy 170Hz back.
  **Flash returns → not bandwidth**, next step is DRM debug logging.
  Baked in both places now: kernel arg in stage 2 (console phase) and the
  captured `kwinoutputconfig.json` in `hosts/desktop/home/` (Plasma session),
  both marked PROVISIONAL. Also unresolved: the portrait monitor (DP-3) threw a
  real hotplug on the same evening, cause unknown — a hotplug on any output
  re-applies all four, so it is a second, independent source of flashes.
- **Dialog window size: CAUSE FOUND, FIX STILL OPEN (2026-07-31).** ulu does not
  want sub-windows ("are you sure?") opening at the size of their parent
  application. The old diagnosis — a previous distro's
  `[Windows] Placement=Maximizing` — was **wrong**, which is why it was found
  set nowhere: **phoinix causes it itself.** Stage 4's KWin rules match only on
  `wmclass`, so an "Apply Initially" size hits every window of that application,
  dialogs included.
  Evidence, in this order: in the QEMU VM Strawberry's dialog opened at exactly
  `0,0` in `900x700` — character-for-character that host's
  `STRAWBERRY_CONNECTOR` origin and `STRAWBERRY_SIZE`; and ulu confirmed on the
  desktop that `Shift+Del` in Dolphin opens a dialog the size of the Dolphin
  window.
  **What does NOT work: `types=1` (NET::NormalMask).** Tried, tested, reverted
  (commit `101a311`). NET window types are X11; on Wayland an application's
  toplevel and its dialog share one app id, and the rule matches both. The
  dialog is pixel-identical with and without the key.
  **DECIDED 2026-07-31 (ulu): keep the rules as they are, for now.** The
  parent-sized dialogs are accepted; the monitor placement of Konsole and
  Strawberry is worth more. Nothing in the repo changes. Do not re-open this
  without being asked — but see the parked fix below, which ulu wants kept.

- **PARKED, ready to pick up — the KWin-script fix for the dialogs (option 5).**
  ulu's call: not now, but do not lose it. The investigation is finished, so
  this can be built without redoing any of it.
  **New evidence, 2026-07-31 (session 7): the same cause has a second, opposite
  symptom, and it hits every fresh install.** ulu reported Strawberry opening
  across the whole monitor at first start while its "first start" message came
  up at exactly half the width. That is the rule landing on the DIALOG (1920
  wide, per `STRAWBERRY_SIZE`) while the main window came up at its own default
  size — the mirror image of the documented "dialogs inherit the parent's
  size". It corrects itself once Strawberry has saved its own geometry, and
  the live windows were measured correct afterwards (`0,804 1920x2105`), so
  the damage is one-time per installation.
  **Agreed with ulu: look at it again after the next full script test**, while
  the case is actually on screen rather than remembered. Deciding it now would
  mean deciding it blind for a second time.
  **The finding it rests on:** KWin does not consider these dialogs dialogs.
  Asked directly via its scripting API, Strawberry's sponsoring dialog reports
  `dialog=false, normal=true, modal=false` — which is why `types=1` matched it
  correctly and excluded nothing. The one field that separates the two windows
  is **`transient`**: `false` for the main window, `true` for the dialog,
  because the dialog has a parent. Title matching is the only other
  discriminator and is language-dependent, so it is out.
  **Why it needs a script:** `kwinrulesrc` has no `transient` matcher. KWin's
  scripting API sees the field.
  **The shape of it:** a small KWin script phoinix ships and installs to
  `~/.local/share/kwin/scripts/`, enabled in `kwinrc`, hooked to `windowAdded`;
  it checks `resourceClass` and `transient` and sets `frameGeometry` only on
  non-transient windows. It would replace the three rules stage 4 writes, and
  it is the only option that costs nothing: apps keep their monitors AND their
  sizes, dialogs behave.
  **The cost, so the decision stays honest:** real code instead of declarative
  config (a script with `metadata.json`), resident and running on every window
  that opens, and one more upstream API the repo depends on.
  Reproducing the measurement takes two minutes in the VM — load a script that
  prints `resourceClass|dialog|normal|modal|transient|caption` for
  `workspace.windowList()` via
  `qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript`, then read
  `journalctl --user -b`.
- ~~EasySMX X20 pad (ACRUX dongle 1a34): verify Steam detects it.~~
  **PASS 2026-07-31, and the decision to drop `steam-devices` /
  `game-devices-udev` holds.** Switched on, the dongle re-enumerates: the
  ACRUX id `1a34` disappears and the kernel loads `xpad`, which binds it as
  `Microsoft X-Box 360 pad` on `event27`/`js1`. systemd's `uaccess` rule then
  puts an ACL on the node (`user:ulutoyon:rw-`), so the session owner can read
  it — which is exactly what those packages would have provided.
  **Measure the pad switched ON.** Idle, the dongle presents as a plain HID
  device called "Receiver Update" with a root-only hidraw node and no input
  device at all; measured in that state it looks like the decision was wrong,
  and it was briefly recorded here as such.
- **`/dev/input/js0` is the ASRock LED controller, not a gamepad.** The board's
  RGB controller is tagged as a joystick, so the pad is `js1` and anything that
  grabs "the first joystick" gets the motherboard lighting. Harmless until some
  game or launcher does exactly that; worth remembering as an explanation
  before debugging the game.
- ~~Cosmetic: stage 4 logs `sed: couldn't flush stdout: Broken pipe`.~~ **Fixed
  2026-07-31, and it was not cosmetic.** `connector_geometry()` had awk `exit`
  on the first match, closing the pipe under `kscreen-doctor` (SIGPIPE). Only
  harmless because the result was interpolated into an argument; the first use
  in an assignment would have aborted stage 4 under `set -e`. awk now reads to
  the end.
- **`konsolerc` needs a re-check next session.** Konsole writes it on exit, and
  the session runs inside Konsole, so nothing there could be verified. Nothing
  appeared changed in this round, but confirm once this window has been closed.
- **Live system is behind the repo on one point:** the boot entry on disk still
  reads `video=DP-2:...` only. The DP-1 cap lives in `KERNEL_PARAMS` in
  `hosts/desktop/config.sh` (moved there 2026-07-31, it used to be inline in
  `stage2.sh`) but stage 2 has not been re-run, so the kernel arg is not active. Irrelevant for the
  running test (KWin holds 144Hz in-session) — it matters at the next reinstall,
  where it will be applied from the script anyway.
- **Live-system cleanup, not yet done:** `~/.config/pipewire/pipewire.conf` is
  a verbatim copy of the packaged 1.6.7 config and shadows the installed 1.6.8
  one. Deleting it restores the package default; the real setting lives in the
  `10-clock.conf` drop-in and is unaffected. Deliberately left to ulu — the
  repo import already excludes it, so a reinstall comes up clean either way.

## Next steps

1. **The complicated question**, then **keychron-launcher** — both at the top of
   this file.
2. ~~**Decide where `qemu-base` + `edk2-ovmf` belong.**~~ **DONE** — both sit in
   `packages/dev.txt` with `socat`, each with its justification, and the
   reinstall installed them from there. The repo rebuilds its own test rig.
   What the rig now lacks is the **ISO**: `scripts/qemu-test.sh` defaults to
   `/mnt/Downloads/archlinux-x86_64.iso`, and that copy was deleted on
   2026-08-01. It is a download, not an asset — fetch a current one and either
   drop it at that path or point `PHOINIX_ISO` at it.
3. **The soundbar question is no longer blocked.** It waited on FFXIV and DayZ
   being installed; both are now here (DayZ 24 GB in the Steam library, FFXIV
   via XIVLauncher). The choice stands: set the sink back to exactly −26 dB, the
   value the old transcripts document as tested glitch-free, or test upward
   deliberately to find where the glitching actually starts. See the entry under
   "Still open".
4. **Watch the 144 Hz experiment** on DP-1 — a few days without a black flash
   confirms the bandwidth diagnosis. Running since 2026-07-31.
5. **Quick wins**, none blocking: the `[KeeShare]` private key, the stale
   `~/.config/pipewire/pipewire.conf`, the `konsolerc` re-check.
6. **Re-run the QEMU test after changes to stages 1-4**:
   `scripts/qemu-test.sh --fresh`, then `--installed` after the reboot.
8. Re-capture `kwinoutputconfig.json` once the monitor tuning is final.
