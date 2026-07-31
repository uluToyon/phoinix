# STATUS

_Last updated: 2026-07-31 (session 5 — keychron, the superproject question, the monitor switch)_

## Pick up here

**Open, parked 2026-07-31: the QEMU run for session 5's changes.** Stage 2
(udev rules), stage 3 (the monitor-switch `.desktop`) and stage 4 (multi-icon
positions) all changed and none has been through the VM. Nothing is known to be
broken — the udev rules and the switch are verified on the real desktop — but
the stage 4 icon JSON exists only as arithmetic checked against ulu's running
Plasma, never written by the script itself. That is the one piece of the day
carrying no proof.

Two things stand in the way, both found while trying:

1. **The harness cannot be driven unattended.** `qemu-test.sh` puts the serial
   console on stdio via `-nographic`, and QEMU does not read a stdin that is not
   a terminal — verified three ways (direct, via a log, via a FIFO with a
   persistent writer; `/proc/<pid>/fd/0` pointed at the FIFO each time and
   neither LF nor CR reached the guest). `qemu-mon.sh type` is no way around it:
   it handles `[a-z0-9]` only, on purpose, and the test line needs `:` `/` `|`.
   A pseudo-terminal instead of stdio would fix this and is the actual work item.
2. **Driving it by hand is a long sequence** across two terminals, including a
   `pkill qemu-system` between stage 2's reboot and `--installed`, and a
   password that must be `[a-z0-9]` only so the KDE greeter can be typed into
   later. ulu ran out of patience on 2026-07-31, fairly.

Fixtures are already in place for whenever it runs: `hosts/qemu/config.sh` now
sets `MONITOR_SWITCH` and `DESKTOP_ICONS`, without which the run would have
skipped both new paths and passed while proving nothing.

**Three smaller things found on 2026-07-31, none blocking:**

- **The repo does not manage the pacman mirrorlist at all** — no `reflector`,
  nothing in `base/`. Every install takes whatever the ISO happens to ship,
  which costs download speed on a fresh machine. Five lines of work.
- **`umu-launcher` sits in `packages/aur.txt` but now lives in `multilib`**
  (1.4.4-1). It is no longer an AUR package and goes through paru for nothing.
  One line to move — unless the AUR variant is wanted deliberately.
- **`kdeconnect` is in `packages/kde.txt` but not installed on the desktop yet.**
  `sudo pacman -S --needed kdeconnect`, then pair the phone by hand.

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

Still open on the Keychron topic, deliberately not pursued yet: **no device
configuration is carried in this repo.** Key mapping and DPI live on the devices
themselves, so a distro-hop does not lose them — but a factory reset would. Ask
ulu whether he has remapped anything worth exporting from the launcher.

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

### Still open, deliberately: the old AirVPN files

`/mnt/FilesMusic/OpenVPNConfigs` holds four **AirVPN** `.ovpn` files (2022 and
2024) with inline private keys, plus a Windows installer. The repo used to
describe them as ulu's ProtonVPN profiles, which they never were. Deleting them
is ulu's call.

## Where we are

- **The system is installed and in daily use.** All four stages exist, all
  have run, and stage 4 has now fired from a real login. Sessions run locally
  on the desktop in `~/phoinix`.
- **Post-install verification is complete** — every test point below passes.
- **The repo is self-contained** (since 2026-07-31): captured config lives in
  `hosts/<host>/home/` and `dotfiles/`, not in an external backup. A missing
  source is a hard error rather than a silent skip.
- Backup of the old system's Claude data + config captures is on the
  `Downloads` disk: `backup-nvme1n1-20260730/`. It has proven useful beyond
  restoring — the soundbar investigation was mined out of those transcripts.
- Repo is live: https://github.com/uluToyon/phoinix (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## Working mode (session 2 onwards)

ulu names an app or a setting; it gets applied on the live system and written
into the scripts in the same step — no big capture at the end. Plasma settings
that need a running shell go into `base/stage4.sh` (see DESIGN.md).

**How a setting is recorded (decided 2026-07-31):** deliberate decisions are
written key by key with `kwriteconfig6` in stage 3, each with its reason in a
comment. **Exception, learned on qBittorrent:** `kwriteconfig6` only suits
KConfig files. On a Qt/QSettings file it escapes the backslash that acts as a
group separator, rewrites the whole file, and produces settings the application
never reads. Such files get a line-oriented writer instead (`qbt_set`). Whole-file capture into `hosts/<host>/home/` is reserved for what
cannot sensibly be authored by hand — `kwinoutputconfig.json`, the wireplumber
state, `p10k.zsh`. For a click-through round: snapshot `~/.config`, let ulu
change things, then diff.

## In discussion (not yet decided) — one topic at a time, per ulu

- ~~Stage 3 notes: aliases, zsh config, KDE shortcuts.~~ **All done.** The
  aliases now live in `~/.config/phoinix/aliases.zsh`, a file phoinix owns and
  rewrites every run — the old inline block in `.zshrc` was written once and
  could never gain an entry. Shortcuts are written as deviations, not captured.
- **chezmoi: still undecided, no longer blocking.** The shell config lives in
  `dotfiles/` as plain files stage 3 installs directly, so the question is now
  only *how* those two files are managed — not whether the repo is complete.
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

- Strawberry: add the music folder to the collection by hand. The path lives in
  Strawberry's database, not its config, and that database is state (absolute
  paths, rebuilt by a rescan) — so it is deliberately not scripted.
  (Done on this machine 2026-07-31: `/mnt/FilesMusic/Musik`, 55 559 tracks.)
- ~~Strawberry: re-save the playlist after adding tracks.~~ **Automated
  2026-07-31.** `scripts/strawberry-playlist-export.sh` rewrites
  `/mnt/FilesMusic/Musik/Default.m3u` from Strawberry's database on session
  exit, so the file tracks the playlist by itself. Stage 4 imports it back on a
  fresh install. Accepted cost (ulu's call): a crash or power cut loses that
  session's additions.
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
- **mpc-qt: start it once before stage 3 can write its settings.** Seeding the
  profile is unsafe (it segfaults on a settings file without a geometry file —
  see `SETTINGS.md`), so stage 3 skips with a message and needs a re-run.
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

- **Soundbar: the captured value is NOT the verified one.** The old transcripts
  (recovered 2026-07-31, see `LOG.md`) document the tested fix as
  `channelVolumes 0.050120` = **−26.00 dB**, glitch-free across 30+ minutes of
  FFXIV. Repo and live system carry `0.068923` = **−23.23 dB**, i.e. 2.77 dB
  louder. The level crept up between the investigation and the backup.
  **This is the likeliest explanation for ulu's doubt that the glitching is
  gone.** Decide: set it back to exactly −26 dB (`pactl set-sink-volume
  <teufel> -26dB`, then re-capture), or test upward deliberately to find where
  the glitches actually start. Full rationale and the operating rules are in
  `DESIGN.md`.
  **Blocked for now:** both reference titles (FFXIV, DayZ) are not installed
  yet, so neither option can be judged. Revisit once gaming is set up — ulu's
  call, deliberately deferred.
- ~~ulu's real name and work e-mail are on GitHub.~~ **RESOLVED 2026-07-31,
  history rewritten and the repository recreated.** Details in `LOG.md`.
  Standing consequence: **there is no global git identity on this machine**,
  and the repo sets `uluToyon` + the GitHub noreply address locally, so new
  commits carry the anonymous identity automatically. Do not add a global
  `user.name`/`user.email` — that is exactly how 35 commits acquired the real
  name in the first place.
  Out of scope but worth remembering: the old system's backup on the Downloads
  disk (`backup-nvme1n1-20260730/`, the Claude transcripts) still contains the
  name. It was never published, but it is on disk.
- **KeePassXC: a pointless private key sits in `keepassxc.ini`.** KeePassXC
  generated a KeeShare signing key when that settings page was opened; the
  share list is empty, so it protects nothing. Deleting the `[KeeShare]`
  section removes it; it only comes back if the page is opened again. phoinix
  never touches that section either way. ulu's call.
- **KeePassXC databases: 4 conflict copies deleted 2026-07-31** (ulu's call —
  sizes grew monotonically, so divergence was unlikely). Full backup of all six
  files at `/mnt/Downloads/keepassxc-pre-merge-2026-07-31/`; keep it until the
  database has been in use for a while. Syncthing (which caused the conflicts)
  was retired years ago and is deliberately not part of phoinix.
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
2. **Decide where `qemu-base` + `edk2-ovmf` belong.** Installed on the desktop
   for the test loop but in no package list, so the repo cannot currently
   rebuild its own test rig. Either into a package list — which makes
   `DESIGN.md`'s testing loop reproducible — or off the machine after use.
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
7. Decide the chezmoi question (no longer blocking anything).
8. Re-capture `kwinoutputconfig.json` once the monitor tuning is final.
