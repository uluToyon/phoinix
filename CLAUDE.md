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
4. `docs/SETTINGS.md` is the inventory: every setting phoinix applies, where
   it is written, and whether it was carried over or decided. Consult it when
   a setting is in question — and keep it current when adding one.

At the end of a work session: update `STATUS.md`, append to `LOG.md`,
commit. Repo content is English only; conversation with ulu is German. The repo is the source of truth — scripts are written/updated live as
steps are performed, never reconstructed later from memory.

## Working agreements

- Communicate with ulu in German; repo content stays in English.
- In repo files, always call the human "ulu" — never a real name, on any machine.
  This includes **commit metadata**: no global git identity on any machine, the
  repo sets `uluToyon` + the GitHub noreply address locally. A leak once reached
  35 commits this way (see `LOG.md` 2026-07-31).
- **Secret scans run over the whole repo, not over the file being imported.**
  The one leak that got through sat in a hand-written file that no import check
  ever looked at.
- Discuss before acting: decisions get talked through first, files/actions after.
- **One topic at a time.** Even when ulu raises several points in one
  message, work through them strictly one after another — close a topic
  (one question, one decision) before opening the next.
- **No clickable question prompts (AskUserQuestion).** Present choices in
  prose: each option with rationale, pros and cons, and a recommendation —
  thorough but compact. End with an open question.
- **Never ask whether to wrap up.** The session ends when ulu says so, or when
  the topic is genuinely finished — not when a chunk of work happens to close.
  Finish a topic, report it, take the next one.
- Destructive steps (partitioning, overwriting) need explicit go-ahead each time.
- Never store secrets in the repo (see DESIGN.md "Never in the repo").
- Never encode discovered identifiers (device names, ALSA card indices) — use
  labels, UUIDs, `/dev/disk/by-id/`.
- The four data disks (`Games`, `Video`, `Downloads`, `FilesMusic`) are never
  formatted by anything in this repo.

## Machines

- **desktop** (`hosts/desktop/`): Ryzen 7 7800X3D, 30 GB RAM, Radeon RX 7900 XT,
  UEFI, target disk Samsung 980 1TB. Gaming is the primary use case.
- **laptop**: Fedora — where this project started; sessions
  may run from either machine.
