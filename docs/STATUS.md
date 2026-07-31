# STATUS

_Last updated: 2026-07-31 (session 2 — running ON the desktop)_

## Where we are

- **The system is installed and in daily use.** Stages 1-3 all ran; the
  desktop boots into Plasma on `linux-zen`, Wayland session, zero failed
  services. Session 2 runs locally on the desktop in `~/phoinix`.
- `base/stage1.sh`, `stage2.sh`, `stage3.sh` all exist, all executed, all
  fixed up with the field lessons from install night (see `LOG.md`).
- Backup of old system's Claude data + config captures is on the `Downloads`
  disk: `backup-nvme1n1-20260730/`. Old-system Claude data was restored to
  `~/.claude`; project memory was ported.
- **Post-install verification is complete** — every test point below passes,
  including the two that needed a real reboot (stage 4 firing from a login,
  and the shutdown hang). Remaining work: the config-capture phase (KDE
  settings etc.). The chezmoi question from DESIGN.md is still undecided —
  discuss before capturing.

- Repo is live: https://github.com/uluToyon/phoinix (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## Working mode (session 2 onwards)

ulu names an app or a setting; it gets applied on the live system and written
into the scripts in the same step — no big capture at the end. Plasma settings
that need a running shell go into `base/stage4.sh` (see DESIGN.md).

**How a setting is recorded (decided 2026-07-31):** deliberate decisions are
written key by key with `kwriteconfig6` in stage 3, each with its reason in a
comment. Whole-file capture into `hosts/<host>/home/` is reserved for what
cannot sensibly be authored by hand — `kwinoutputconfig.json`, the wireplumber
state, `p10k.zsh`. For a click-through round: snapshot `~/.config`, let ulu
change things, then diff.

## In discussion (not yet decided) — one topic at a time, per ulu

- Stage 3 notes: alias `nano`→`micro`; zsh config (plugins, prompt) with the
  dotfiles. **KDE shortcuts: done 2026-07-31** — media keys freed for
  Strawberry, Spectacle's `Meta+Shift+S` moved to region capture. Written as
  deviations, not captured; the file states its own defaults, so the next
  change is found the same way (compare field 1 against field 2).
- **chezmoi: still undecided, no longer blocking.** The shell config lives in
  `dotfiles/` as plain files stage 3 installs directly, so the question is now
  only *how* those two files are managed — not whether the repo is complete.
- **Mount-path legacy: DECIDED — clean re-wiring, no compat symlinks.**
  Restored configs get new /mnt/<Label> paths written in during capture;
  manual checklist: Steam "add library folder" → /mnt/Games/SteamLibrary,
  re-run MateriaForge for 7th Heaven, set XIVLauncher game path.

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
- Evaluate haruna vs. mpc-qt BEFORE finalizing the scripts (ulu wants a look).
- VPN session with ulu: walk through the whole desktop VPN topic together and
  migrate ProtonVPN from .ovpn imports to WireGuard configs.

## Post-install manual steps (not scriptable)

- Strawberry: add the music folder to the collection by hand. The path lives in
  Strawberry's database, not its config, and that database is state (absolute
  paths, rebuilt by a rescan) — so it is deliberately not scripted.
  (Done on this machine 2026-07-31: `/mnt/FilesMusic/Musik`, 55 559 tracks.)
- Strawberry: **re-save the playlist after adding tracks.** Stage 4 imports
  `/mnt/FilesMusic/Musik/Default.m3u`, but Strawberry never updates that file
  by itself — saving is a one-off export, and the dialog starts in the home
  directory with "Playlist 1.m3u" rather than offering to overwrite. Save with
  **relative paths** so the file stays independent of the mount point.
- Brave: join the sync chain by hand (profile comes via Brave Sync).
- pCloud: log in by hand (credentials in KeePassXC on FilesMusic).
- ProtonVPN: import .ovpn profiles (FilesMusic/OpenVPNConfigs) into the
  network applet by hand — may contain credentials, never into the repo.

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
- **WAITING ON ulu — dialog window size.** ulu remembers a behaviour from the
  old system he does *not* want back: a sub-window ("are you sure?") opening at
  exactly the size of its parent application. That is KWin's
  `[Windows] Placement=Maximizing` ("Window placement: Maximized" in the GUI),
  which opens every new window maximized, dialogs included.
  **Investigated 2026-07-31: it is set nowhere** — not in the old system's
  captured `kwinrc`, not in `~/.config/kwinrc`, not in `~/.config/kdedefaults/`,
  not in `kwinrulesrc` (empty), and Arch ships no `/etc/xdg/kwinrc` at all.
  Most likely it came from the previous distro's system-wide defaults, which is
  why it never appeared in any file of his and never made it into a backup.
  **Open: ulu confirms whether a dialog still opens parent-sized** (e.g.
  `Shift+Del` in Dolphin, then cancel). If it opens small and centred the topic
  is closed; if not, the diagnosis was wrong and it needs another look.
  Either way there is a standing proposal: write `Placement=Centered`
  explicitly, so no future distro default can reintroduce it — exactly the
  class of problem this repo exists for. Raise this with ulu when he comes back
  to it, or when he mentions it himself.
- EasySMX X20 pad (ACRUX dongle 1a34): verify Steam detects it — dropped
  steam-devices/game-devices-udev on evidence (XInput via kernel xpad).
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
  reads `video=DP-2:...` only. The DP-1 cap was added to `stage2.sh` but stage 2
  has not been re-run, so the kernel arg is not active. Irrelevant for the
  running test (KWin holds 144Hz in-session) — it matters at the next reinstall,
  where it will be applied from the script anyway.
- **Live-system cleanup, not yet done:** `~/.config/pipewire/pipewire.conf` is
  a verbatim copy of the packaged 1.6.7 config and shadows the installed 1.6.8
  one. Deleting it restores the package default; the real setting lives in the
  `10-clock.conf` drop-in and is unaffected. Deliberately left to ulu — the
  repo import already excludes it, so a reinstall comes up clean either way.

## Next steps

1. Continue the post-install manual steps with ulu.
2. Start the config-capture phase — decide the chezmoi question first.
3. Re-capture `kwinoutputconfig.json` once the monitor tuning is final.
