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
- Remaining work: finish the post-install verification below, then the
  config-capture phase (KDE settings etc.). The chezmoi question from
  DESIGN.md is still undecided — discuss before capturing.

- Repo is live: https://github.com/uluToyon/phoinix (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## Working mode (session 2 onwards)

ulu names an app or a setting; it gets applied on the live system and written
into the scripts in the same step — no big capture at the end. Plasma settings
that need a running shell go into `base/stage4.sh` (see DESIGN.md).

## In discussion (not yet decided) — one topic at a time, per ulu

- Stage 3 notes: alias `nano`→`micro`; zsh config (plugins, prompt) with the
  dotfiles; **custom KDE keybindings** (ulu will adjust, incl. Spectacle) —
  capture `~/.config/kglobalshortcutsrc` once configured.
- **Re-capture `kwinoutputconfig.json`** once ulu is done tuning the monitor
  settings — the file currently in the repo/backup is the old system's state,
  and a reinstall would restore that instead of the final layout.
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

Still open:

- **Stage 4 firing at a real first login.** `stage4.sh` is verified (produces
  the intended state; runs once and is skipped afterwards when started through
  systemd), but the unit has never actually triggered from a login — it was
  installed after the fact on an already-personalised system. Test it by
  deleting `~/.local/state/phoinix/stage4.done` and rebooting.
- EasySMX X20 pad (ACRUX dongle 1a34): verify Steam detects it — dropped
  steam-devices/game-devices-udev on evidence (XInput via kernel xpad).

## Next steps

1. Reboot and run the two open test points above (4-monitor PLM + KWallet).
2. Continue the post-install manual steps with ulu.
3. Start the config-capture phase — decide the chezmoi question first.
