# STATUS

_Last updated: 2026-07-30 (session 1, from the laptop)_

## Where we are

- Planning done, repo skeleton committed. **Nothing installed yet — the
  target disk is untouched**, desktop sits in the Arch ISO awaiting go-ahead.
- Backup of old system's Claude data + config captures is on the `Downloads`
  disk: `backup-nvme1n1-20260730/`.
- `base/stage1.sh` is written and reviewed but NOT yet executed.
- `base/stage2.sh` and `base/stage3.sh` do not exist yet.

## In discussion (not yet decided)

- GitHub repo: visibility (public/private), then push.
- Kernel choice: `linux` vs `linux-zen` vs CachyOS kernel (gaming focus).
- `packages/pacstrap.txt` final contents.
- KDE install scope (minimal / curated / full).

## Next steps

1. Push to GitHub once auth is set up on the laptop.
2. Settle kernel + package + KDE questions, adjust `packages/`.
3. Run stage 1 on the desktop (needs explicit approval; serial S649NX0T343303X).
4. Write + run stage 2 (chroot: locale, systemd-boot, user, network, zram).
5. Reboot, write + run stage 3 (AUR helper, KDE, gaming stack).
6. Move the working session to the desktop; continue config capture there.
