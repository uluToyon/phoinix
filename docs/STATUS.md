# STATUS

_Last updated: 2026-07-30 late evening (session 1 ending — HANDOVER to the desktop)_

## Session handover (desktop takes over from here)

The system is INSTALLED and boots into Plasma. Session 1 ran from the laptop
via SSH; from now on work happens on the desktop in `~/phoinix`.
First moves for the desktop session:
1. Work through "Post-install manual steps" below with ulu.
2. The OUTSTANDING 4-monitor PLM test (see below) — ask before the next reboot.
3. Then begin the config-capture phase (KDE settings etc.); the chezmoi
   question from DESIGN.md is still undecided — discuss before capturing.
Old-system Claude data was restored to ~/.claude; project memory was ported.

## Where we are

- Planning done, repo skeleton committed. **Nothing installed yet — the
  target disk is untouched**, desktop sits in the Arch ISO awaiting go-ahead.
- Backup of old system's Claude data + config captures is on the `Downloads`
  disk: `backup-nvme1n1-20260730/`.
- `base/stage1.sh` is written and reviewed but NOT yet executed.
- `base/stage2.sh` and `base/stage3.sh` do not exist yet.

- Repo is live: https://github.com/uluToyon/phoinix (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## In discussion (not yet decided) — one topic at a time, per ulu

- KDE install scope (leaning: curated explicit list in `packages/kde.txt`);
  waiting on ulu's actual app list. ← current topic
- **Monitor bug on the desktop** — ulu wants to discuss it BEFORE the
  install runs on the PC, in case setup can already work around it. Details
  not yet collected.
- Stage 3 notes: alias `nano`→`micro`; zsh config (plugins, prompt) with the
  dotfiles; **custom KDE keybindings** (ulu will adjust, incl. Spectacle) —
  capture `~/.config/kglobalshortcutsrc` once configured.
- **Mount-path legacy: DECIDED — clean re-wiring, no compat symlinks.**
  Restored configs get new /mnt/<Label> paths written in during capture;
  manual checklist: Steam "add library folder" → /mnt/Games/SteamLibrary,
  re-run MateriaForge for 7th Heaven, set XIVLauncher game path.

## Decided this session

- Kernel: `linux-zen` only. Editor: `micro` only (vim banned, nano not
  installed). Login shell: zsh (in pacstrap so stage 2 can set it at useradd).

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

- **IMPORTANT, ask ulu on the desktop:** the first PLM boot looked good, but
  2 of the 4 monitors were switched to the laptop input at the time — the
  full 4-monitor black-screen test is still OUTSTANDING. When the session
  has moved to the desktop and a reboot is due: remind ulu to have ALL four
  monitors active on the PC, then verify PLM comes up clean.

- EasySMX X20 pad (ACRUX dongle 1a34): verify Steam detects it — dropped
  steam-devices/game-devices-udev on evidence (XInput via kernel xpad).
- Plasma monitor layout: arrangement correct? Ultrawide (DP-1) at 170Hz,
  TCL 27" capped at 144Hz, HDR states as configured?
- Shell restore: does Konsole greet with the old p10k prompt? (zinit
  self-installs its plugins on first shell start — takes a moment.)

## Next steps

1. Settle kernel + package + KDE questions, adjust `packages/`.
3. Run stage 1 on the desktop (needs explicit approval; serial S649NX0T343303X).
4. Write + run stage 2 (chroot: locale, systemd-boot, user, network, zram).
5. Reboot, write + run stage 3 (AUR helper, KDE, gaming stack).
6. Move the working session to the desktop; continue config capture there.
