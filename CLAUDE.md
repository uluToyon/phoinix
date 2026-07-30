# CLAUDE.md

Personal Arch installer for ulu (desktop user: `ulutoyon`). Goal: a
git-tracked, multi-stage script that rebuilds the desktop — system *and*
personal settings — so distro-hopping away and back is cheap.

## Session handshake — read this first

1. Read `docs/STATUS.md` — current state, what's done, what's next.
2. Read `docs/LOG.md` — append-only log of every decision *with rationale*.
   Never re-litigate a decision recorded there without being asked.
3. `docs/DESIGN.md` holds the architecture rationale (stages, guard rails,
   capture tooling). Follow it.

At the end of a work session: update `STATUS.md`, append to `LOG.md`,
commit. Repo content is English only; conversation with ulu is German. The repo is the source of truth — scripts are written/updated live as
steps are performed, never reconstructed later from memory.

## Working agreements

- Communicate with ulu in German; repo content stays in English.
- Discuss before acting: decisions get talked through first, files/actions after.
- Destructive steps (partitioning, overwriting) need explicit go-ahead each time.
- Never store secrets in the repo (see DESIGN.md "Never in the repo").
- Never encode discovered identifiers (device names, ALSA card indices) — use
  labels, UUIDs, `/dev/disk/by-id/`.
- The four data disks (`Games`, `Video`, `Downloads`, `FilesMusic`) are never
  formatted by anything in this repo.

## Machines

- **desktop** (`hosts/desktop/`): Ryzen 7 7800X3D, 30 GB RAM, Radeon RX 7900 XT,
  UEFI, target disk Samsung 980 1TB. Gaming is the primary use case.
- **laptop**: Fedora, user `ulu` — where this project started; sessions
  may run from either machine.
