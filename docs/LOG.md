# Decision log

Chronological log of the original installation and every decision made along
the way. The repo is the source of truth — this log is the safety net and the
collection of rationales.

## 2026-07-30 — Session 1: planning & preparation (via SSH from the laptop)

**Setup:** Desktop boots the Arch ISO (2026.07), accessed via SSH as root on
192.168.178.46 (key auth in place). This SSH-driven install is a one-off —
in the future the script runs directly on the target machine.

**Hardware inventory:**
- Ryzen 7 7800X3D, 30 GiB RAM, Radeon RX 7900 XT(X) + Raphael iGPU, UEFI 64-bit
- LAN `enp8s0` (active), Wi-Fi `wlan0`
- Target disk: Samsung SSD 980 1TB, serial S649NX0T343303X (`nvme1n1`)
- Data disks (never touched): `Games` (Samsung 980 PRO 2TB, NVMe),
  `Video` (WD 5.5TB HDD), `Downloads` (OCZ 894GB SSD), `FilesMusic` (Seagate 1.8TB HDD)

**Decisions (with rationale):**
- **ext4 over Btrfs** — deliberate: pure gaming desktop, snapshots would go
  unused; the reinstall script itself is the rollback strategy.
- **No encryption** — desktop sits at home, keeps the curl workflow simple.
- **Separate /home on its own partition** — survives distro hopping.
  Rules: always the same username (`ulutoyon`) as the first user (UID 1000),
  and never format /home in a foreign installer.
- **Partitions:** EFI 1G | root 200G ext4 | home rest (~730G) ext4
- **zram instead of a swap partition** — no hibernation needed.
- **systemd-boot** — UEFI, single OS, minimal.
- **Data disk mount points by label** (`/mnt/Games`, …) instead of the old
  device-name paths (`/mnt/nvme0n1`) — lesson from DESIGN.md: never encode
  discovered identifiers. Path change compared to the old system!
- **Install directly on the desktop**, QEMU-hardening of the scripts afterwards.
- Hostname `archlinux`, locale `en_US.UTF-8`, KEYMAP `de`, TZ `Europe/Berlin`
  (carried over from the old system).

**Backup before wiping** → `Downloads` disk, `backup-nvme1n1-20260730/`:
- `~/.claude` (19M) + `~/.claude.json` — Claude sessions/projects
- `arch-install/DESIGN.md` (now `docs/DESIGN.md` in this repo)
- Capture files per DESIGN.md: `kwinrc`, `.config/pipewire/`,
  `.local/state/wireplumber/` (soundbar −26dB fix), `.local/share/kscreen/`
  (4-monitor layout). `.xlcore/launcher.ini` no longer existed.
- Deliberately NOT backed up (ulu's call): the rest of home, including
  hidden save games / browser profiles.

**Old fstab** (UUID reference): Games=78d74fc9…, Video=4eb23c82…,
Downloads=10015c7b…, FilesMusic=eaa964b8…

## 2026-07-30 — GitHub setup

- Discussed private vs. public vs. a two-repo pipeline: decided on
  **one repo, public** — a pipeline split buys nothing because the fresh
  system needs almost the whole repo anyway; protection against secrets comes
  from curated config imports + a secret scan before pushing, not from the
  repo boundary. `age` encryption noted as the option for real secrets.
- Commit history anonymized before the first push: author `uluToyon`,
  GitHub noreply address instead of the work e-mail.

## 2026-07-30 — Kernel decision

- **`linux-zen` only.** No LTS fallback, no CachyOS repo — deliberate:
  the reinstall script itself is the recovery strategy ("that's why we're
  here"). Discussed zen+lts and an optional CachyOS module; both rejected in
  favor of maximum simplicity. On the 7800X3D (single CCD, GPU-bound)
  kernel differences are in the low single digits anyway; the real gaming
  levers (Mesa, gamemode, VRR, Proton-GE) come in stage 3.
- `vim` removed from pacstrap.txt (ulu's standing rule).

## 2026-07-30 — Repo naming & language

- Old GitHub repos cleaned up manually by ulu; only this project remains.
- Renamed `archinstall` → **`phoinix`**: avoids clashing with the official
  `archinstall` tool, and the FFXIV lore fits (see README). Candidates
  discussed: phoinix, elpis, exarch, arch-reborn; ironworks rejected (name
  taken in FFXIV tooling), alexander rejected (snapshot lore — deselected).
- Repo language policy confirmed: discussion happens in German, **everything
  in the repo is English** — this log was translated from German accordingly.

## 2026-07-30 — Base package decisions

- Editor: **micro only** (ulu reviewed it live). No nano package; instead
  a `nano` → `micro` shell alias comes with the dotfiles in stage 3.
- Login shell will be **zsh** — added to pacstrap so stage 2 can set it at
  useradd time; `bash-completion` dropped (bash itself stays via `base`).
- Open item parked in STATUS.md: a monitor-related bug on the desktop, to be
  discussed BEFORE the install runs on the PC.

## 2026-07-30 — Base list finalized

- `tmux` and `htop` deliberately kept OUT of pacstrap: tmux only matters for
  this one-off SSH session (the ISO ships it; future runs are local on the
  target), htop is comfort — both go on the stage-3 list. Base stays at 17
  packages, each with an installation-time justification.

## 2026-07-30 — Bluetooth investigated (live on the ISO)

- Chip: MediaTek MT7925 (USB 0e8d:0717), board ASRock X870 Steel Legend WiFi.
- Hardware is fine: initializes cleanly on the current kernel, scan found 18
  devices. ulu's "never worked right" traces back to the immature MT7925
  stack in older kernels/firmware — no quirks needed on a fresh system.
- Script consequence: bluez, bluez-utils, bluedevil in stage 3; enable
  bluetooth.service. Nothing else.
- Note: the scary `wl`/taint warning in the ISO dmesg is the ISO's bundled
  broadcom-wl driver false-matching the MediaTek card (overly broad PCI
  alias). Not installed on the target → gone after install.
- Recommendation for ulu (manual): update BIOS (3.08, 2024-09 → current) for
  MT7925 connectivity fixes.

## 2026-07-30 — Package review rounds (everything justifies itself)

Ground rule from ulu: nothing is carried over 1:1 from the old system;
every package is discussed individually or it's out.

- **Plasma core: hand-picked** (packages/kde.txt) instead of plasma-meta —
  11 packages, each with an inline justification. Discover, firewall GUI,
  thunderbolt, accessibility extras deliberately absent.
- **Login: plasma-login-manager** (KDE's SDDM successor, versioned with
  Plasma, already ran fine on the old system) over sddm+sddm-kcm.
- dzgui is NOT an AUR package (verified: 0 hits) — it ships upstream via
  script/git (aclist/dztui). Becomes its own stage-3 install step; config
  at ~/.config/dztui/ goes on the capture list.

## 2026-07-30 — KDE app rounds (one package per round)

In: dolphin, konsole, ark+p7zip+unrar (ulu's rule: every archive format via
Dolphin context menu, never the terminal), spectacle (note: custom keybindings
planned → capture kglobalshortcutsrc later), gwenview, plasma-systemmonitor,
isoimagewriter.
Out: okular — PDFs open in the browser, documents in LibreOffice (new
candidate for the app rounds); mission-center/resources/gnome-system-monitor
rejected as GTK.
**New standing rule from ulu: avoid GNOME/GTK apps wherever possible — prefer
Qt/KDE-native; GTK only when no usable Qt alternative exists (say so openly).**
Stage-3 note: xdg-mime default for PDF → brave.

## 2026-07-30 — CLI tool rounds

In: bat, eza, zoxide, fzf (the old-zshrc quartet — aliases cat→bat,
ls→eza, cd→z restored via dotfiles; ulu wants an fzf tour later), fastfetch,
btop (replaces htop/glances/s-tui), jq (consumer: stage-3 DZGUI fetch via
GitHub releases API), power-profiles-daemon (Plasma profile switcher).
Out: tmux (revisit when the future home-server exists), expac, uv & wmctrl
(old DZGUI setup — DZGUI 7 is turnkey with bundled runtime; all its deps
deferred to actual install), cpupower, libinput-tools, wget.
Old .zshrc/.p10k.zsh backed up to the Downloads disk (found configured
powerlevel10k — input for the zsh round).

## 2026-07-30 — App rounds (ulu's list)

In: steam, discord (official; vesktop = plan B), qbittorrent, strawberry
(HARD req: stereo→5.1 upmix player-internal ONLY, never system-wide),
mpc-qt (haruna evaluation before script finalization), keepassxc,
networkmanager-openvpn (ProtonVPN .ovpn; WireGuard migration on the wishlist),
cups+splix+print-manager (SCX-4300, print only), libreoffice-fresh + hunspell
de/en_US. AUR: brave-bin (PDF default; sync chain by hand), pcloud-drive,
xivlauncher-rb, jdownloader2.
DZGUI: stage-3 upstream install step (turnkey since v7 — deps deferred).

## 2026-07-30 — Final package rounds

- AUR helper: **paru** over yay (successor-in-spirit by yay's co-maintainer,
  reviews PKGBUILD diffs by default — fits the repo culture). Alias yay→paru
  in dotfiles. base-devel in cli.txt; paru bootstrap = first stage-3 step.
- Out: linux-zen-headers (no DKMS consumer), gimp (never used; Krita would be
  the Qt path if image editing ever becomes real).
- **zsh: restore the old setup 1:1** (option A) — zinit self-bootstraps and
  manages powerlevel10k, fast-syntax-highlighting, autosuggestions,
  zsh-completions, fzf-tab; plus zoxide init and the tuned .p10k.zsh (backed
  up). Trade-off accepted: plugins live outside pacman, p10k is on life
  support but config exists and works. ttf-meslo-nerd as the font.
- Transcript-in-repo idea raised and dropped (secrets/name scrubbing burden).

## 2026-07-30 — Monitor bug diagnosed & fix designed

Black screen at first login-manager start (every distro): bandwidth/DSC —
TCL 27" 4K defaults to native 180Hz; four displays at max modes overwhelm
link training. ulu's proven fix (cap to 144Hz) is adopted as the permanent,
scripted solution — restored via the backed-up Plasma 6 kwinoutputconfig.json
(user + PLM greeter, deployed before first graphical start) plus a
video=DP-2:3840x2160@144 kernel arg for the console phase.
Also fixed a DESIGN.md-era gap: Plasma 6 stores output config in
~/.config/kwinoutputconfig.json (not ~/.local/share/kscreen) — file now
backed up, along with kdeglobals and kscreenlockerrc.

## 2026-07-30 — Install night: stages 1-3 executed, lessons collected

Stage 1 & 2 clean (one fstab bug fixed pre-run: genfstab writes real option
strings, not "defaults"). First boot: kernel 7.1.5-zen, zram, monitor fix on
cmdline, zero failed services. Field lessons, each fixed in the scripts:
- 5s device timeout dropped all three SATA data disks (spin-up) → 30s.
- etckeeper auto-commits need a persistent git identity.
- A global /etc/zsh/zshrc does NOT suppress zsh-newuser-install → empty user
  ~/.zshrc in stage 2.
- Stale EFI NVRAM entries pointed at the destroyed ESP's GUID → cleaned,
  fresh entry via efibootmgr from the ISO (chroot bootctl can't write NVRAM).
- mpc-qt and splix are AUR-only → moved lists.
- paru-bin broke on a libalpm soname bump → helper builds from source now.
- `getent passwd a b` exits 2 under pipefail if any key is missing.
- PLM's systemd unit is plasmalogin.service; the package also ships a D-Bus
  .service that a naive grep matches first.
Stage 3 completed (manually finished after the getent abort; scripts fixed).
tmux removed again — system matches the documented package set.

## 2026-07-30 — Session 2: first session running ON the desktop

The working session moved from the laptop to the installed desktop; Claude
Code now runs locally in `~/phoinix` on the machine it builds.

**First-boot verification (details in STATUS.md):** keyboard layout and shell
restore both PASS. The zsh bootstrap is worth recording as a proven result:
the first Konsole start required zero input — zinit cloned itself, fetched and
compiled all 9 plugins, installed 191 completions, p10k pulled gitstatusd, and
the prompt appeared complete with correct Nerd Font glyphs. The whole chain
(stage 2 writes an empty `.zshrc` → stage 3 overwrites it with the restored one
→ that one bootstraps itself on first login) works unattended, which is exactly
the property phoinix is being built for.

Noted for the capture phase: the restored `.zshrc` still carries the old
system's `zsh-newuser-install` and `compinstall` blocks. Harmless, but legacy.

## 2026-07-30 — KWallet: `kwallet-pam` (decided)

First login greeted ulu with the KWallet creation dialog ("Blowfish or GPG?").
Requirement: never see it again after a scripted reinstall.

Diagnosis: `ksecretd` triggered it — some app asked the freedesktop
Secret-Service API for a store. And `/usr/lib/pam.d/plasmalogin` (shipped by
plasma-login-manager) **already** calls `pam_kwallet5.so`, but as an optional
module (leading `-`), so it is silently skipped while the module is absent.
The package `kwallet-pam` was simply not installed. That is also why other
distros never show this dialog — they ship it.

Options weighed:
- **Disable KWallet** (`kwalletrc: Enabled=false`) — cheapest, but apps using
  the Secret-Service API then have no store at all and fall back to their own
  (Brave: obfuscated in-profile), with a risk of repeated logins in single
  apps. Kept as the fallback if PAM misbehaves.
- **Wallet with an empty password** — works, but is not cleanly scriptable:
  it would mean pre-generating a `kdewallet.kwl` and carrying it in the repo.
  Rejected on principle — that is exactly the file class where secrets end up
  by accident later.
- **`kwallet-pam`** — CHOSEN. The wallet is created with, and unlocked by, the
  login password at PLM login: no dialog, no prompt, store fully functional,
  and the secrets are genuinely encrypted. Scripted cost: one package name in
  `packages/kde.txt`, nothing in `/etc/pam.d`, no state in the repo.

Precondition, satisfied here: no autologin configured (PAM has no password to
hand on in that case), and no wallet existed yet — so PAM gets to create it.
Verification is pending on the next reboot, together with the 4-monitor test.
