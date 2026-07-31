# STATUS

_Last updated: 2026-07-31 (session 4 — the one command)_

## Pick up here

### DONE 2026-07-31 — the one command

`scripts/bootstrap.sh` exists and the whole install now runs from one line on
the ISO:

```
curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
```

Each stage arms the next: bootstrap → 1 → 2 (chroot) → reboot → login hook →
3 → reboot → systemd user unit → 4. Two human inputs remain, both by ulu's
explicit choice: the password for the new user, later the sudo password.
Rationale in `LOG.md`; the serial prompt is gone.

**Tested end to end in QEMU on 2026-07-31: PASS.** The whole chain ran from the
one-liner to a personalised Plasma session — stage 1 partitioned, stage 2
installed and rebooted, the login hook started stage 3, the greeter login
started the session, stage 4 built the panel. `scripts/qemu-test.sh` is the
harness; `hosts/qemu/` is the throwaway machine. Details and the six defects it
exposed are in `LOG.md`.

**It found six real defects, five of which would have hit the next reinstall.**
The worst: `bootstrap.sh` did nothing at all under `curl | bash`. Not one of
them was visible by reading the scripts.

Not covered by the QEMU run, and worth stating: no captured configs are
restored there (`CAPTURED_CONFIGS=0`), so the monitor fix and the wireplumber
audio state are exercised on the desktop only. The AUR phase downloads whatever
is current, so a broken upstream package fails the test for reasons that are
not ours.

One live-system detail, harmless: this desktop has no `~/.zprofile` and no
`stage3.done` marker, because both are new. Irrelevant unless stage 2 is ever
re-run *here* — then the next login would start stage 3 once. `touch
~/.local/state/phoinix/stage3.done` prevents that if it ever matters.

---

**Application phase.** Done: Dolphin, Konsole, Strawberry, KeePassXC,
ProtonVPN. Not yet touched: **Brave, Discord, Steam, LibreOffice, DZGUI,
XIVLauncher, mpc-qt/haruna, CUPS/printer**. qBittorrent is done only as far as
the VPN needed (interface binding, WebUI, launcher) — its own settings round is
still open.

### ProtonVPN — LIVE ON THE DESKTOP AND MEASURED

Applied and verified on the real machine 2026-07-31. Measured, not assumed:
ordinary traffic leaves via `enp8s0`, group traffic via `proton0` with an exit
inside Proton's network, the two exit addresses differ, the drop counter stays
at 0 in normal use, switching CH → NL mid-session changes nothing, and **with
the tunnel down the group is blocked by name and by raw IP while everything
else keeps working**. That last one is the requirement ulu actually stated.

Getting there refuted the first design three times — `never-default` does not
restrain a WireGuard connection, the drop rule strangled the tunnel's own
encapsulation, and the filter sat in a hook that runs before the reroute. All
three are written up in `LOG.md`; none was visible on paper.

**Open: port forwarding.** `natpmpc` is refused by both servers (CH answers
"the gateway does not support nat-pmp", NL times out). Both configs say
`NAT-PMP (Port Forwarding) = on`, but that header records what was *requested*
at generation time, not what the server can do — Proton grants it only on P2P
servers, so CH#919 and NL#586 are probably not P2P. Next step is ulu's:
regenerate two configs on servers carrying the double-arrow, drop them in
`VPN_CONFIG_DIR`, re-run stage 3. Torrenting works without it; it costs peers.

**Also open:** qBittorrent has only its VPN-relevant settings so far, and the
QEMU host does not exercise this path at all (`VPN_CONFIG_DIR` is empty there),
so the split tunnel is only ever tested by hand on the desktop.

### Superseded — the pre-verification note

Kept because it is the honest record: this section previously read "scripted
and verified, NOT YET APPLIED", on the strength of a QEMU run that had no
tunnel and therefore only ever proved the blocking half.

Split tunnel over WireGuard: only qBittorrent uses the VPN, and qBittorrent can
use nothing else. The guarantee is an nftables rule, not qBittorrent's own
setting — see `SETTINGS.md` for the inventory and `LOG.md` for why.

Proven in QEMU with the tunnel absent: a process in the `vpnonly` group reached
neither a hostname nor a raw IP, loopback still worked, a process outside the
group was unaffected, and the drop counter moved. The run also caught a bug that
would have left qBittorrent unlaunchable on the desktop (Arch's
`nftables.service` reports inactive while its rules are loaded).

**Open on the live desktop:** stage 2's system half has never run here — no
`vpnonly` group, no nftables ruleset, no `systemd-resolved`. Those need root and
this session's sudo has no password, so they are ulu's to run. Until then the
desktop has no VPN at all, exactly as before.

**Also still open, deliberately:** the old `/mnt/FilesMusic/OpenVPNConfigs`
folder holds four **AirVPN** `.ovpn` files (2022 and 2024) with inline private
keys, plus a Windows installer. The repo used to describe them as ulu's
ProtonVPN profiles, which they never were. Deleting them is ulu's call.

The method is settled — see "Working mode" below. In short: snapshot,
ulu clicks, **close the application**, diff the whole config tree, decide per
value whether it is a decision or a default, write it key by key, verify by
reproducing it, document, commit.

Two rules earned the hard way, both non-obvious:
1. **Read every config file before importing it.** Two of four applications so
   far had a secret in plain text (Strawberry: OAuth token; KeePassXC: an RSA
   private key). Wholesale capture would have published both.
2. **Diff the whole tree, not the application's own files.** Konsole's and
   Strawberry's real settings were autostart entries and KWin rules, i.e.
   nowhere near the application. Filter by path prefix, never by name —
   a `strawberry` filter once hid the autostart entry that mattered.

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
- ~~VPN session with ulu.~~ **Done 2026-07-31** — WireGuard split tunnel built and
  verified in QEMU; see the ProtonVPN entry at the top of this file.

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

1. **Continue the application phase** — next application is ulu's choice; the
   untouched list is at the top of this file.
2. **Decide where `qemu-base` + `edk2-ovmf` belong.** They are installed on the
   desktop now, for the test loop, but are in no package list — so the repo
   currently cannot rebuild its own test rig. Either they go into a package
   list (which makes `DESIGN.md`'s testing loop reproducible) or they get
   removed again after use. ulu's call, deliberately not decided unilaterally.
3. **Re-run the QEMU test after changes to stages 1-4.** It is one command now:
   `scripts/qemu-test.sh --fresh`, then `--installed` after the reboot.
3. **Quick wins waiting for ulu**, none of them blocking: the dialog-window-size
   check (one `Shift+Del` in Dolphin), the `[KeeShare]` private key, the stale
   `~/.config/pipewire/pipewire.conf`, the `konsolerc` re-check now that this
   Konsole has been closed.
4. **Watch the 144Hz experiment** on DP-1 — a few days without a black flash
   confirms the bandwidth diagnosis.
5. Decide the chezmoi question (no longer blocking anything).
6. Re-capture `kwinoutputconfig.json` once the monitor tuning is final.
