# STATUS

_Last updated: 2026-07-30 (session 1, from the laptop)_

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
- **Old mount path `/mnt/nvme0n1` is baked into existing setups** (7th Heaven
  .desktop, MateriaForge prefix paths, likely Steam library + XIVLauncher
  configs). New scheme is /mnt/Games. To decide: compat symlink vs. clean
  re-wiring after install.

## Decided this session

- Kernel: `linux-zen` only. Editor: `micro` only (vim banned, nano not
  installed). Login shell: zsh (in pacstrap so stage 2 can set it at useradd).

## Stage-2 requirements collected so far

- Enable `[multilib]` in pacman.conf (lib32 gaming packages).
- Set zsh as ulu's login shell at useradd (zsh is in pacstrap).
- Ship a minimal global zsh config so first login has no setup wizard.

## Next steps

1. Settle kernel + package + KDE questions, adjust `packages/`.
3. Run stage 1 on the desktop (needs explicit approval; serial S649NX0T343303X).
4. Write + run stage 2 (chroot: locale, systemd-boot, user, network, zram).
5. Reboot, write + run stage 3 (AUR helper, KDE, gaming stack).
6. Move the working session to the desktop; continue config capture there.
