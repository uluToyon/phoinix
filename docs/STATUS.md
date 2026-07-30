# STATUS

_Last updated: 2026-07-30 (session 1, from the laptop)_

## Where we are

- Planning done, repo skeleton committed. **Nothing installed yet — the
  target disk is untouched**, desktop sits in the Arch ISO awaiting go-ahead.
- Backup of old system's Claude data + config captures is on the `Downloads`
  disk: `backup-nvme1n1-20260730/`.
- `base/stage1.sh` is written and reviewed but NOT yet executed.
- `base/stage2.sh` and `base/stage3.sh` do not exist yet.

- Repo is live: https://github.com/uluToyon/archinstall (public; commits use
  the GitHub noreply address, author name `uluToyon`). Rule: curated config
  imports + secret scan before pushing anything captured from a live system.

## In discussion (not yet decided) — one topic at a time, per ulu

- Kernel choice: `linux` vs `linux-zen` vs CachyOS kernel (gaming focus). ← current topic
- `packages/pacstrap.txt` final contents (decided so far: NO vim, ever;
  candidates micro + nano).
- KDE install scope (leaning: curated explicit list in `packages/kde.txt`).

## Next steps

1. Settle kernel + package + KDE questions, adjust `packages/`.
3. Run stage 1 on the desktop (needs explicit approval; serial S649NX0T343303X).
4. Write + run stage 2 (chroot: locale, systemd-boot, user, network, zram).
5. Reboot, write + run stage 3 (AUR helper, KDE, gaming stack).
6. Move the working session to the desktop; continue config capture there.
