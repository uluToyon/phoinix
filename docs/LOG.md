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

## 2026-07-30 — 4-monitor PLM test: PASS (and a bonus fix)

The reboot with all four displays actually connected to the PC — the first
real run of the black-screen scenario — came up clean: picture on all four,
greeter fully rendered, no flicker phase. The baked-in fix works as designed.

Unplanned bonus: the password field appeared on DP-1, the main monitor. On
every previous distro the login manager grabbed the TV on HDMI, and ulu had
never managed to change that. Cause found in the restored config: Plasma 6
stores a per-output `priority` inside each setup block of
`kwinoutputconfig.json` (current 4-monitor setup: DP-1=1 → primary, DP-2=2,
DP-3=3, HDMI-A-1=4). Without that file KWin picks a primary heuristically;
with it — and stage 3 deploys the same file to the PLM greeter's config dir —
the greeter inherits ulu's intended primary. So the monitor-bug fix carries a
second benefit that was never part of its design goal.

Follow-up recorded in STATUS.md: the deployed file is still the *old* system's
capture. Once ulu finishes tuning the monitor settings it has to be captured
again, otherwise a reinstall restores the stale layout.

## 2026-07-30 — KWallet silent unlock verified: PASS

Same reboot, second test point. No KWallet window at login — neither the
Blowfish/GPG creation dialog that started this whole topic nor a password
prompt. Evidence beyond ulu's observation: journal shows the complete
`pam_kwallet5` chain (auth → setcred → open_session) via plasmalogin-helper,
the socket at `/run/user/1000/kwallet5.socket`, the systemd unit "Unlock
kwallet from pam credentials", a wallet store created at exactly the login
timestamp, and `ksecretd` running as `--pam-login` — credentials handed over
by PAM, not typed by a human.

So the decision holds at its advertised cost: one package name
(`kwallet-pam` in `packages/kde.txt`), no `/etc/pam.d` edits, no wallet state
in the repo. The `-pam_kwallet5.so` lines PLM already ships stop being no-ops
the moment the module exists.

Cosmetic: `ksecretd` fails to register with the host portal ("Connection
already associated with an application ID"). Known noise on PAM-started
sessions, no functional impact — only worth chasing if an app turns out not
to retain its passwords.

## 2026-07-30 — Stage 4: Plasma settings that need a running shell

New working mode agreed with ulu: he names an app or a setting, it gets fixed
on the live system AND written into the scripts in the same breath, instead of
one big capture at the end. First item flushed out a structural gap.

**The item.** A launcher with a broken generic icon sat in the panel next to
Dolphin: `org.kde.discover.desktop`, a package manager ulu will never use and
that phoinix deliberately does not install. It came from neither the panel
layout template nor any config file — the icons-only task manager had no
`launchers` key at all and was showing its built-in default, which lives
compressed inside the applet's Qt resource (hence unfindable by grep and
unpatchable). Writing the key explicitly retires the default. A second, hidden
instance of the same problem sat in `kactivitymanagerd-statsrc`: Plasma's
default Kickoff favourites list ships Discover *and* Kontact, neither
installed. Not visible in the menu (Kickoff hides unresolvable entries) but
still dead weight — cleaned along with it.

**The gap.** Neither fix can be made by stage 3, which runs before the first
graphical login: panel and favourites do not exist yet, and their config
groups are keyed by applet ids and an activity UUID that are regenerated on
every install. Deposited files would land on the wrong widget or nowhere.

**The decision: a fourth stage.** `base/stage4.sh` runs inside the live Plasma
session and drives it through the plasmashell scripting interface, addressing
widgets by type and looking ids up at runtime. Stage 3 arms it as a systemd
user unit (`system/user/phoinix-stage4.service`, a template) ordered after
plasma-plasmashell.service.

Single-shot vs. every-login was put to ulu explicitly. Chosen: **single-shot**,
via `ConditionPathExists=!` on a marker file. Every-login would be the purer
"repo is truth" reading, but it would also wipe any GUI change not yet carried
into the repo — unworkable during the phase where settings are still being
discovered. Rationale kept in DESIGN.md.

Verified on the live desktop: stage4.sh produces exactly the hand-made state;
run through systemd it executes once (`Result=success`) and is skipped on the
second attempt (`ConditionResult=no`). Still untested: the unit actually
firing at a real first login — that needs a fresh install, or a marker delete
plus reboot.

## 2026-07-31 — Panels: built by stage 4, TV mirrors the main monitor

ulu built his panels in the GUI: main panel on the ultrawide (no longer
floating, full width, seven pinned launchers — Konsole, Dolphin, Brave,
KeePassXC, Strawberry, Discord, qBittorrent), plus clock-only strips on the
TCL 4K and the portrait monitor. Captured by diffing a config snapshot taken
before he started, which beats asking him to recall what he clicked.

**"Can panels be linked?" — no.** Plasma has neither panel duplication nor
any coupling between panels; each is a standalone containment. Not a missing
setting, a missing feature.

What replaces it: panels are *built from a script*, so the TV panel is a
clone of the live main panel rather than a second hand-written description of
it. One source, no drift. Changing the main panel means changing the
definition and re-running stage 4 — as close to "linked" as Plasma gets.

`plasma/panels.js` (template, fed to plasmashell's scripting interface by
stage 4) rebuilds the layout from scratch: remove every panel, build the main
one, clone it to the TV, add the side strips. Rebuilding rather than patching
is deliberate — a fresh install starts from Plasma's default panel, and
repairing an unknown state is guesswork.

Three things worth remembering, each learned the hard way here:

- **Screens are matched by geometry, never by index.** Plasma numbers screens
  in detection order. Stage 4 resolves connector names (`DP-1`, `HDMI-A-1`,
  from `hosts/desktop/config.sh`) to geometry via kscreen-doctor and passes
  that in; panels.js finds the matching screen itself. A monitor that is not
  connected yields -1 and its panel is skipped instead of landing elsewhere.
- **Panel length is not copied to the clone.** The main panel is clamped to
  3360 px by Plasma's own 21:9 rule for the ultrawide; the TV gets its own
  full width instead.
- **A freshly created task manager reads its launchers only once, at build
  time.** Writing the config afterwards updates the file but not the running
  widget — the panel keeps showing the built-in default (broken Discover
  icon) until the shell restarts. Stage 4 therefore ends with
  `systemctl --user restart plasma-plasmashell.service`. Which is also why
  the unit uses `Wants=` instead of `Requires=`: a Requires dependency would
  kill stage 4 mid-run at exactly that moment.

Verified on the live desktop: stage 4 wiped the hand-built panels and
reproduced all four correctly (main and TV pixel-identical in the launcher
area, both clock strips in place).

## 2026-07-31 — Regional formats: English UI, German everything else

The panel clocks showed "12:01 AM / 7/31/26" — the system had only
en_US.UTF-8 generated, no German locale existed at all. ulu wants the full
regional package, not just a 24-hour clock.

Split: `LOCALE` stays the UI language, new `FORMAT_LOCALE=de_DE.UTF-8` drives
dates, numbers, currency, measurements, paper. Stage 2 now generates a LIST
of locales — a format locale that locale-gen never built silently degrades to
C, which is the failure mode worth guarding against.

Two files, deliberately, with different jobs (stage 3 writes both):
- `~/.config/environment.d/10-phoinix-locale.conf` — the one that ACTS.
  systemd's user manager exports it into the session. Chosen as the effective
  path because it is a documented, verifiable mechanism; grepping for who
  actually consumes plasma-localerc turned up nothing conclusive.
- `~/.config/plasma-localerc` — the one that DISPLAYS, so the Region &
  Language module does not claim "American English" while the session runs on
  German formats.

Left out on purpose: `LC_MESSAGES` (would translate the UI, which ulu does
not want) and `LC_COLLATE` (German sort order changes shell globs and `sort`
output — a bad trade in a repo made of scripts).

locale-gen needs root and this session's sudo has no password: ulu ran the
two commands himself, `de_DE.utf8` confirmed present. Takes effect on the
next login.

**Verified after that login: PASS.** The systemd user manager exports the nine
format variables, `date` prints `Fr 31. Jul`, and the panel clocks read
`00:16` / `31.07.2026`. Worth recording because it settles an open question:
the Plasma clock takes its format from `LC_TIME` rather than storing one of
its own, so the environment.d file alone is the whole fix — no clock format
has to be written into `plasma/panels.js`.

## 2026-07-31 — The 40-second shutdown, and why it was plasmashell's fault

Every shutdown stalled for a fixed ~40 s. Fixed durations are a tell: that is
not work in progress, that is a timeout expiring. It matched KDE's own
`TimeoutSec=40` on `plasma-plasmashell.service`.

Cause: plasmashell loses its Wayland connection *before* systemd asks it to
stop. A client without a compositor still has a running process, but its event
loop is wedged on the dead connection and never gets around to handling
SIGTERM — so systemd waits out the full timeout and then SIGKILLs it. Nothing
is actually being saved during those 40 s.

Fix, as a drop-in (`system/user/plasma-plasmashell.service.d/phoinix-shutdown.conf`,
deployed by stage 3): order plasmashell *before* kwin so it is stopped while
its compositor still exists, plus `TimeoutStopSec=10` as a safety net in case
the ordering does not take — logind may start the teardown in a way that makes
the ordering moot. A drop-in rather than an edited unit file, so pacman
upgrades of the KDE package keep working.

**Verified on the next real shutdown: PASS.** `Stopping KDE Plasma Workspace…`
and `Stopped KDE Plasma Workspace.` land in the *same second* (00:24:23), and
ulu's own observation was "instant". So the ordering is the real fix and the
10 s cap never comes into play — but it stays, cheap insurance against the same
symptom returning through another path.

## 2026-07-31 — Stage 4 fires at a real login: PASS

The last genuinely untested link in the chain. Stage 4 was known to produce
the right state and known to skip itself on a second systemd start, but the
unit had never actually been triggered *by a login* — it was installed onto an
already-personalised system, so every previous run was hand-started.

Test: delete `~/.local/state/phoinix/stage4.done`, reboot, log in normally.

Result: the unit started out of the login at 00:25:19 and exited
`status=0/SUCCESS`, having done the full run — launchers set on the main
panel, 7 widgets cloned to the TV, both side strips placed (screens resolved
to 1 and 2 by geometry), Kickoff favourites written against the freshly
generated activity UUID, plasmashell restarted, marker rewritten. That is the
same result the hand-started runs produced, which is the point: the systemd
arming path (rendered template + symlink into `plasma-workspace.target.wants`,
`After=plasma-plasmashell.service`, `Wants=` not `Requires=`) works unattended
on a login it has never seen before.

With this, every stage of phoinix has now run in the mode it was designed for.

Cosmetic leftover, noted not fixed: the run logs `sed: couldn't flush stdout:
Broken pipe` — a `sed` whose reader closes early. Exit code was 0, but under
`pipefail` that class of thing is brittle; worth a look on its own.

## 2026-07-31 — The black flash on the main monitor, finally characterised

ulu has chased a sporadic short black flash on the ultrawide (DP-1) for years,
across distros, never reproducible, never found. One occurred mid-session, so
the journal was still warm. What came out is worth recording in full, because
almost every intuition about it was wrong.

**The monitor that flashes is not the one that causes trouble.** At 00:36:03 a
DRM hotplug (`action=change, hotplug=1`) hit connector 400 = `card1-DP-3`, the
*portrait* monitor: gone at 00:36:04, back at 00:36:05. A hotplug on any one
output makes KWin re-apply the entire output configuration — amdgpu dumped ~100
lines of HDR infoframes, i.e. a modeset across all four screens. DP-1 goes
black as collateral. So a flash on the main monitor can be caused by a cable
two ports over. Worth knowing before ever debugging this class of bug again.

**But that was a different incident.** The flash ulu actually reported happened
~00:37:40, and the journal window covering it contains exactly three lines, all
unrelated KSplash noise. `HDR SB:` bursts (a reliable modeset marker) exist for
this boot at 00:25:09, 00:36:03 and 00:36:05 — and nowhere else. **The real
event left no trace at all**, which is itself the finding: no modeset, no
hotplug, no DP link loss. Everything KWin, powerdevil or the compositor could
have done would have logged something.

That eliminated the usual suspects one by one:
- **GPU clock switching** (the classic AMD multi-monitor flicker): out.
  `pp_dpm_mclk` sits pinned at its top state (1249 MHz) — amdgpu does that on
  mixed-refresh multi-monitor setups. What never switches can't blank.
- **VRR**: weakened to near-zero. DP-1 is the only output with adaptive sync
  (`Vrr: Automatic`, range 48–170), but Plasma only engages it for fullscreen
  windows, and the desktop was idle with a terminal open.
- **powerdevil / libddcutil**: it was silent from 00:25:25 until the udev event
  woke it, so it reacted rather than caused. It does hammer the I2C bus with
  retries and timeouts afterwards — noise, not cause.

**What the link actually looks like** (amdgpu debugfs, DP-1):

```
link_settings:  Current: 4  0x1e  0        4 lanes, 0x1e = HBR3 = 8.1 Gbps/lane
dsc_clock_en:   0                          no compression active
dp_dsc_fec_support: DSC no, FEC no         the sink supports neither
force_yuv420_output: 0                     full RGB 4:4:4, no subsampling
```

Four lanes at HBR3 is the ceiling of DP 1.4: 32.4 Gbit/s raw, **25.92 Gbit/s
after 8b/10b**. The sink cannot do DSC, so nothing compresses the stream, and
it cannot do FEC, so nothing absorbs a bit error before it becomes a retrain.
At 3440x1440@170 in RGB 4:4:4 that link runs at roughly 82% utilisation (8 bpc;
10 bpc would need ~26.7 Gbit/s and simply would not fit, so amdgpu's bandwidth
validation must already be falling back to 8 bpc plus dithering — inferred, not
measured: this kernel's `output_bpc` prints only the maximum, not the current
value).

A maxed-out link with no error correction and no headroom is exactly where
in-service link retraining lives, and a retrain is a short black screen that
the kernel does not log. That explains every property of this bug: sporadic,
distro-independent, only this one output, and invisible for years.

**Consequence, and it is deliberately provisional.** DP-1 set to
3440x1440@144, which drops utilisation to ~70%; everything else (HDR, wide
gamut, VRR, geometry, priority) untouched. Possible bonus: at 144Hz 10 bpc
*does* fit under the ceiling, so HDR may now run at true 10 bit instead of 8
bit dithered. If the flash stays away for a few days the bandwidth theory is
confirmed and a certified DP cable should buy the 170Hz back; if it returns,
bandwidth was never it and the next step is DRM debug logging.

ulu's call: bake the 144Hz into the scripts already, rather than wait out the
test. Done for the console phase (`video=DP-1:3440x1440@144` in stage 2,
marked PROVISIONAL there). The in-session mode is **not** covered by that — it
comes from `kwinoutputconfig.json`, which stage 3 restores from the backup on
the Downloads disk, i.e. from outside the repo. Until that file is re-captured
the scripted result of a reinstall is still 170Hz.

## 2026-07-31 — Captured config moved into the repo (and a silent killer found)

Chasing the 144Hz into the scripts turned up something worse than a stale
file. Stage 3's config section restored **seven** things — `kwinoutputconfig`,
`kwinrc`, `kdeglobals`, the PipeWire tree, the wireplumber state (the −26dB
soundbar fix), `.zshrc`, `.p10k.zsh` — all from
`/mnt/Downloads/backup-nvme1n1-20260730/`, a dated one-off directory on a data
disk. None of it was in the repo.

**The guard was the real problem:**

```bash
if [[ -d "$BACKUP" ]]; then
```

No disk, no restore, **no message, exit code 0**. The monitor fix sits inside
that block. A machine rebuilt without the Downloads disk attached would have
run stage 3 to a clean finish and then gone black at the first graphical login
— precisely the bug phoinix was written to prevent, hidden behind a successful
run. Same failure class the locale work guarded against ("silently degrades to
C"), sitting at the most critical spot in the repo.

Two things turned out better than feared:

- **No drift.** The backup's monitor config differed from the live one by
  exactly two lines — `refreshRate 170000 → 144000` and a mode flag — i.e. only
  by the change made an hour earlier. The re-capture STATUS.md had been
  deferring for days was a two-line diff.
- **Publishable.** All seven scanned clean for real name and company domain
  (the one hit was an upstream p10k comment containing the placeholder
  `x@y.com`). `kwinoutputconfig.json` carries EDID *hashes*, no plaintext
  serials or model strings.

**Curation, not a blind copy** — and it earned its keep immediately:
`~/.config/pipewire/pipewire.conf` turned out to be a verbatim copy of the
packaged config from PipeWire **1.6.7**, differing from the installed 1.6.8
only in the version comment. Since a file there shadows the packaged one
completely, that copy had been quietly freezing out every upstream change to
it. Not imported; only the real customisation, the `10-clock.conf` drop-in,
is. Same for `disabled-forceclock.bak/`, switched-off debugging leftovers.

New layout: `hosts/desktop/home/` mirrors destination paths 1:1, so where a
file sits says where it lands. `dotfiles/` takes the two shell files. Stage 3
installs from the repo and **hard-fails on a missing source**. The `.zshrc`
went in *without* the phoinix alias block — stage 3 section 6 appends it and
stays its single owner, so the aliases have exactly one definition site.

Side effect worth naming: this unblocks the chezmoi question without answering
it. It is now only about *how* two shell files are managed, not whether the
repo contains what it needs to rebuild the machine.

## 2026-07-31 — General Plasma settings: written, not captured

Method agreed first, because it decides how every following setting is
recorded: **deliberate decisions get written key by key; only opaque blobs get
captured.** A `kwriteconfig6` line carries its rationale in a comment right
next to it, produces a readable diff, is idempotent, and merges instead of
clobbering whatever else KDE stores in the same file. Whole-file snapshots
stay reserved for what cannot reasonably be authored by hand —
`kwinoutputconfig.json` with its EDID keys, the wireplumber state, `p10k.zsh`.

Working method for the round itself: snapshot `~/.config` first, let ulu click
through the system settings, then diff. Same approach that worked for the
panels, and it beats asking anyone to recall what they changed.

Five files came back changed. One was noise: `kglobalshortcutsrc` had only
gained friendly-name strings for two keyboard-layout shortcuts, a side effect
of opening the KCM, not a decision. The other four are now in stage 3:

- **Screen locking off** (`kscreenlockerrc`): `Autolock=false` *and*
  `Timeout=0`. The timeout is not redundant — left at its default the KCM goes
  on displaying an idle time that no longer applies.
- **German without dead keys** (`kxkbrc`): `LayoutList=de`,
  `VariantList=nodeadkeys`, `Use=true`. This one reached beyond stage 3: the
  login greeter has no user `kxkbrc` and falls back to the X11 system config,
  so stage 2 now writes the variant too. Otherwise ulu would type his password
  on a dead-key layout and land in a session without one. New config variable
  `KEYMAP_VARIANT`, deliberately separate from `KEYMAP`: on the vconsole the
  no-dead-key layout is a different keymap *name*
  (`de-latin1-nodeadkeys`), not a variant, so folding both into one value would
  emit an invalid `XkbLayout`.
- **NumLock on at start** (`kcminputrc`): `NumLock=0`.
- **Never dim, never blank, never suspend** (`powerdevilrc`), power button
  shuts down.

Two enum values could not be decoded from the system — KDE compiles them in,
and both had several plausible readings. Resolved by asking ulu what he had
just selected in the GUI, which beats guessing at a number: `NumLock=0` is
*on*, `PowerButtonAction=8` is *shut down*. Recorded here because the next
person to read those files will have the same question.

Verified rather than assumed: the twelve `kwriteconfig6` calls were run against
the live system and the four files compared against ulu's hand-made state —
**byte-identical**, all four.

Closes a gap on the way past: `kscreenlockerrc` was backed up on 2026-07-30 but
appeared in no restore line of stage 3. It was captured and never deployed.
Now it is written explicitly, so the gap cannot reopen.

## 2026-07-31 — Pointer acceleration off, as a rule rather than a device setting

ulu set one more thing without saying what, as a test of whether the diff
method actually finds things. It did — `kcminputrc`, modified two minutes
earlier: `PointerAccelerationProfile=1`, the flat profile, i.e. mouse
acceleration off.

The find turned into something more useful than the setting. KDE stores the
profile **per device**, in a group built from vendor id, product id and device
name. Querying KWin's D-Bus interface for every pointer showed four devices
capable of a flat profile and exactly one that had it — the Microsoft wireless
mouse. Not set: the **Keychron M6 8K**, an 8000 Hz gaming mouse, which turned
out to be the one ulu actually plays with. The KCM shows one device at a time,
so a setting made there quietly applies to whichever device happens to be
selected. Worth knowing: this is a settings page where doing the obvious thing
gets you a half-configured system.

ulu's call, and it is the better one: **this is a gaming PC, so no mouse gets
acceleration.** A rule about every pointer rather than a value on one device.

That also removes the scripting problem instead of solving it. Writing
`[Libinput][13364][53321][Keychron Keychron M6 8K]` into the repo would have
meant three discovered identifiers in a file (against CLAUDE.md), coverage of
exactly one mouse, and silent nothing the day a different one is plugged in.

Implementation (stage 4, because it needs a running compositor): ask KWin for
`ListPointers`, skip anything that reports no support for the flat profile —
the "Consumer Control" pseudo-devices every keyboard registers — and set the
D-Bus property on the rest. **KWin writes the group name and persists it to
`kcminputrc` itself**, verified live: setting the property produced the correct
group without a single identifier being authored by hand. Same principle the
panels already follow — look things up at runtime, never hard-code them.

Verified: applied to all four capable devices, and the block re-runs cleanly.

Limitation, deliberately accepted: stage 4 is single-shot, so a mouse bought
later is not covered automatically. Re-running `stage4.sh` by hand handles it,
and a new mouse is rare enough not to justify making the unit fire on every
login (which was decided against for good reasons in the panel work).

## 2026-07-31 — Global shortcuts: the file states its own defaults

`kglobalshortcutsrc` had been parked in STATUS.md for days as "capture once
configured". Capturing it whole would have been wrong twice over: ~275 lines of
untouched defaults, and a `switch-to-activity-<UUID>` entry carrying an
activity id that is regenerated on every install — a dead reference the moment
it lands on a new machine.

It also turned out to be unnecessary. Entries are
`key=active,default,friendly`, i.e. **every line carries the default it
deviates from**. "What did ulu actually change" is therefore computable from
the file alone, with no before/after snapshot and no expiry date. Service
entries are the exception, using plain `key=shortcut` with no default field —
which is why a first pass misread all four Spectacle lines as changes; the
truth came from diffing against the evening's snapshot and against Spectacle's
own `.desktop`.

Two real changes:

- **Media keys belong to Strawberry.** Plasma's `mediacontrol` claims the same
  four keys Strawberry registers, so Plasma's four are cleared. Worth recording
  what was *not* touched: `pausemedia` and both seek shortcuts stay at their
  defaults because they do not collide. Without this, a fresh install has
  Plasma grabbing the media keys and Strawberry looking broken — with nothing
  anywhere pointing at the cause.
- **Spectacle: `Meta+Shift+S` moved from "open Spectacle" to "capture a
  region".** The package ships `Print,Meta+Shift+S` on `_launch` and
  `Meta+Shift+Print` on the region action; ulu took the combination off the
  first and added it to the second, so the Windows key combination drags a
  region immediately instead of opening a window. Multiple shortcuts for one
  action are TAB-separated, stored escaped as `\t` — verified that a tab
  written by `kwriteconfig6` round-trips into exactly that.

The two `none` entries in the Spectacle group are not decisions: Spectacle
ships no shortcut for those actions either. Kept anyway, so the group is
explicit instead of partial.

Verified as before: the eight calls were run against the live system and the
file compared to ulu's hand-made state — identical. (First attempt wrote
nothing at all: the test used `$G` for repeated arguments, and this session's
shell is zsh, which does not word-split unquoted variables. The "identical"
that produced was meaningless. Worth remembering when testing bash snippets
from a zsh prompt.)

No daemon owns the file in Plasma 6 — `plasma-kglobalaccel.service` is inactive
and no `kglobalaccel` process exists; KWin handles global shortcuts itself.
Irrelevant for stage 3, which runs before the first login, but it means a write
during a live session can still be overwritten when the session ends.

## 2026-07-31 — Applications, round 1: Dolphin (and where a setting can hide)

Start of the application phase. Ground rules set first, because they differ
from everything so far: from here on config files can contain credentials, so
every file is read before it is imported, and the repo stays public. Dolphin
was picked deliberately as a calibration case — no secrets, but all three
parts: its own config, view properties, and the Plasma half.

**Two process lessons, both learned the hard way in this round.**

1. **KDE applications must be closed before diffing.** The first diff after
   ulu's round showed only a KWin rule. `dolphinrc` was byte-identical, and the
   reason was simply that Dolphin was still running — it writes its config on
   exit. This now belongs to the routine for every application.
2. **A file that grew is not automatically a change.** `user-places.xbel` had
   gained seven `<separator>` blocks, which was dismissed here as KDE
   bookkeeping. Wrong: those markers *are* the sidebar ordering ulu had
   changed, each identifying its device by UDI and UUID. Nothing visible was
   added, which is exactly what made it look like noise.

**The setting that was nowhere.** "Show hidden files" survived restarts,
according to ulu, but appeared in no file: not `dolphinrc` (checksum unchanged
throughout), not in any `.directory` under `~` or `/mnt`, not in extended
attributes on the visited folders, not in the cache. The only hit anywhere was
`Show hidden files=false` in `kdeglobals` — which belongs to
`[KFileDialog Settings]`, i.e. the open/save dialogs, not Dolphin's view.

The web was a detour worth recording: one bug report describes a genuine
regression at exactly this checkbox in Dolphin 24.12, another was closed as
NOT A BUG, and the most promising lead — Dolphin having moved view properties
from `.directory` files to extended attributes — was checked against the live
system with `getfattr` and disproved. What settled it was the machine itself,
not the internet: KDE ships the schema in
`/usr/share/config.kcfg/dolphin_directoryviewpropertysettings.kcfg`, and it
names both the key and, crucially, its group:

```
group [Settings]  →  HiddenFilesShown (Bool, default false)
```

`[Settings]`, not `[Dolphin]` where all the other view properties live — which
is why searching for a value in the obvious group would have failed too. Same
file confirms `GlobalViewProps` defaults to true, so the one shared view file
is the right target:
`~/.local/share/dolphin/view_properties/global/.directory`. Dolphin had created
that directory and never written the file: the setting existed only inside the
running process.

**Proven, not assumed** — ulu's idea: after writing `true` and confirming the
hidden files appeared, set it to `false`, restart Dolphin, hidden files gone,
set it back. Without that counter-test we would only have known the files were
visible, not that our file was the cause.

Scripted in a new stage-3 section for application settings: the view property,
`GlobalViewProps` written explicitly (the default is true today, but a default
is not a decision), and the KWin window rule for Dolphin's size — "Apply
Initially", so the window opens at 1295×839 and can still be resized. The rule
id is a UUID we author and keep fixed, so re-runs update that rule instead of
appending duplicates; `count`/`rules` in `[General]` have to grow when a second
rule is added.

Verified: all three files reproduce byte-identically from the script.

Still open from this round: the sidebar ordering. It encodes device node names
(`sda1`, `nvme0n1p1`) and filesystem UUIDs, two of which belong to root and
home and are regenerated on every install. It needs runtime resolution from the
disk labels rather than a captured file — same treatment as the panels and the
pointer profile.

## 2026-07-31 — Places sidebar order, resolved from labels

The ordering KDE persists as `<separator>` markers, each naming its device
twice over in identifiers the repo may not contain: a UDI carrying the device
node (`/org/freedesktop/UDisks2/block_devices/sda1`) and the filesystem uuid.
Device nodes are handed out in probe order; the root and home UUIDs are created
fresh by every install. Capturing the file would produce an ordering that is
half-dead on a rebuilt machine.

What made it easy: **every disk already has a label**, including root and home
— stage 1 gives them `archroot` and `archhome`, the four data disks carry
their own. So `hosts/<host>/config.sh` stores an order of labels, and stage 4
resolves each to device node and uuid at runtime via
`/dev/disk/by-label/` plus `lsblk`, both unprivileged. No identifier in the
repo, and the ordering survives a reinstall that renumbers everything.

The install USB stick (`ARCH_202607`, still plugged in) had a marker of its own
and is deliberately not scripted — removable media has no place in a
reproducible layout. A label that is absent is skipped with a message, so an
unplugged disk costs its entry and nothing more.

Stage 4, not stage 3: the file must already exist. KDE creates it with its
standard bookmarks, and writing it from scratch would mean authoring KDE's
bookmark ids too. If it is missing, the step says so and asks for a re-run
rather than inventing one.

**A mistake worth keeping.** The first test wiped all seven markers and wrote
nothing back. The cause was in the test harness, not the script: the config was
sourced in one shell and the extracted snippet run with `bash` as a separate
process, which does not inherit non-exported variables — `PLACES_ORDER` was
empty there, the loop never ran, and the awk stripped everything. Restored from
the copy taken beforehand.

But it exposed a real flaw: with an empty list the script *would* have destroyed
a working ordering, silently, and that could equally happen on a machine whose
disks are not plugged in. There is now a guard — no separators resolved means
the file is left untouched. The accident produced a better script than the
review would have.

Verified: the generated file matches ulu's hand-made state exactly, minus the
install stick.

## 2026-07-31 — Applications, round 2: Konsole (and a latent stage-4 abort)

Konsole breaks the rule established on Dolphin — close the application before
diffing — because the session runs inside it. Konsole writes profile changes
immediately but `konsolerc` only on exit, so `konsolerc` cannot be trusted
until this window has been closed at least once. Noted in STATUS.md for the
next session; nothing was changed there in this round anyway.

Both of ulu's settings turned out to be **outside** Konsole:

- **Autostart.** `~/.config/autostart/org.kde.konsole.desktop`, added through
  System Settings. KDE's autostart is a directory of .desktop files, so the
  entry lives nowhere near the application's own configuration — it would never
  have been found by looking at Konsole's files, only by sweeping the whole
  config tree. Stage 3 installs the packaged `.desktop` rather than carrying a
  copy: KDE writes a normalised version when adding through the GUI, but the
  packaged file behaves identically and cannot go stale.
- **A KWin rule**: `position=7280,0`, `size=1440,1262`, both Apply Initially.
  And `7280,0` is *exactly* the origin of DP-3, `1440` exactly its width — so
  the intent is "top-left of the portrait monitor", confirmed with ulu, not a
  coordinate that happens to be there.

**Window rules moved wholesale to stage 4.** A position written as `7280,0`
is a coordinate in the current monitor layout and points somewhere else the day
a screen is rearranged, without a word of warning. Stage 4 already resolves
connector names to geometry for the panels, so the repo stores
`KONSOLE_CONNECTOR="DP-3"` and the position is computed at runtime. Dolphin's
rule moved along even though it needs no position: `count` and `rules` in
`[General]` are a single shared index, and two stages writing into it would
eventually have one drop the other's entries. One owner for the file.
`org.kde.KWin.reconfigure()` is called afterwards, or a fresh install would
only see its rules from the second login onwards.

**The test failure that was not a test failure.** Running the new section
aborted with exit 141. Cause: `connector_geometry()` had awk `exit` on the
first match, which closes the pipe while `kscreen-doctor` is still writing —
SIGPIPE upstream. That was already visible as the cosmetic
`sed: couldn't flush stdout: Broken pipe` parked in STATUS.md, and it was
harmless *there* only because the result is interpolated into a `sed` argument,
where the exit status is discarded. The new code assigns it:
`konsole_geom="$(connector_geometry ...)"` — and in an assignment the
substitution's status IS the assignment's, so under `set -e` this would have
aborted stage 4 mid-run on every install. Dropping the `exit` and reading to
the end fixes the abort and the cosmetic warning in one line.

Worth generalising: a helper that is safe as an argument is not automatically
safe in an assignment.

Verified: rules reproduce byte-identically apart from the order of the id list
in `[General]`, which is irrelevant while no two rules match the same window
(commented in the script).

## 2026-07-31 — Applications, round 3: Strawberry

The first application where the secrets rule actually bit. `strawberry.conf`
holds a 305-character OAuth `access_token` for a streaming service in plain
text. ulu does not use the streaming side at all — Strawberry is his local
collection player — so those sections are simply out of scope, and the file is
never captured as a whole. Only individual keys are written. Worth stating
plainly: had we captured this file the way `kwinrc` is captured, a live token
would have been pushed to a public repo.

**Telling a decision from a default, when the diff shows both.** Strawberry
serialises entire sections of defaults the moment its settings dialog is
opened — the diff after ulu's round showed seventeen new sections and roughly
150 keys, almost none of them decisions. A raw diff is useless here.

The technique that worked: run the application once against an empty
`XDG_CONFIG_HOME`/`XDG_DATA_HOME`, let it write its own defaults, and compare.
In the twelve sections both files had, exactly **one** value differed
(`MainWindow maximized`, window state). Its limit is worth recording too: the
pristine run never wrote `[Backend]`, `[Behaviour]` and the other fifteen
sections, because those only appear once the dialog has been opened — so for
those the comparison says nothing, and ulu had to name what he touched. He had
changed exactly one thing.

Scripted:

- **The stereo → 5.1 upmix** (`[Backend] channels_enabled=true`, `channels=6`).
  This is the requirement Strawberry is in the package set for: the upmix
  happens inside the player and never system-wide. Strawberry's default is
  `false`, so the two keys are the entire setting. `kwriteconfig6` writes into
  the Qt config without reformatting it — verified byte-identical, permissions
  stay 600.
- **Autostart**, same mechanism as Konsole.
- **A window rule**: `position=0,804` is exactly the origin of DP-2, so it is
  stored as `STRAWBERRY_CONNECTOR="DP-2"` and resolved at runtime.

**A blind spot of my own making.** The autostart entry did not show up in the
sweep after ulu's round: the exclusion filter contained `strawberry` to hide
the application's own files, and it swallowed
`~/.config/autostart/org.strawberrymusicplayer.strawberry.desktop` along with
them. Filter by path prefix, never by substring — a name-based filter will
eventually hide the one file that mattered.

**The collection is not scriptable, and it is empty.** Strawberry keeps
collection directories in its database, not in the config, and that database is
state: absolute paths, rebuilt by a rescan. It currently holds zero directories
and zero songs, so the music folder still has to be added by hand. Recorded as
a manual post-install step rather than pretended away.

## 2026-07-31 — The −26 dB soundbar fix: the reason, finally written down

ulu pulled the Teufel to 100% in the KDE volume applet and asked for it to be
captured. It was not captured, because it collided with a documented fix — and
that collision is the whole point of writing things down.

What actually changed, in the wireplumber route state:

```
before:  channelVolumes: [0.068923, …]   (≈ −23…−26 dB, the fix)
after:   channelVolumes: [1.000000, …]
```

`DESIGN.md` listed the file under "encodes hours of debugging" with the note
"bar must NOT run at max" — but **no reason**. It was lost in the move from the
pre-phoinix notes, which is exactly how a hard-won setting turns into an
inexplicable quirk that someone eventually undoes.

ulu had it: **audio glitches in games, specifically FFXIV and DayZ.** Now in
`DESIGN.md` next to the file, where the next person to look will find it. He
also notes he is not fully convinced the problem is solved — parked in
STATUS.md rather than treated as settled.

Restored by stopping wireplumber, putting the repo's copy back, and starting it
again — in that order, because wireplumber writes its in-memory state on
shutdown and would otherwise overwrite the file we just replaced. Verified:
`wpctl` shows 0.41, which is the cubic display mapping of linear 0.0689, and
the live file matches the repo byte for byte again.

Two lessons, both cheap to state and expensive to relearn: a captured fix needs
its *reason* captured with it, or it will be undone by the person it protects.
And a JSON parser is not a diff tool — the first comparison here ran both files
through `json.load`, which fails on wireplumber's format, and dutifully
reported "no difference" between two empty outputs. A wrong "identical" is
worse than an error.

## 2026-07-31 — The soundbar investigation, recovered from the old transcripts

The pre-phoinix Claude sessions were backed up with `~/.claude` on the
Downloads disk, and they contain a full write-up of the four-day audio hunt.
Extracted here as findings; the transcripts themselves stay out of the repo,
per the decision of 2026-07-30 (secret- and name-scrubbing burden). This is
what that decision assumed would happen instead — mine the transcript for
knowledge, keep the knowledge, discard the transcript.

**Symptoms.** Broadband static during FFXIV *and* DayZ, never in FF7 Remake.
That ruled out game, Dalamud, XIVLauncher and Proton early: whatever it was
lived below all of them.

**Cause.** The Teufel driven at 100% hardware gain. The variable connecting all
three games was simply how far the bar was turned up — FFXIV runs with in-game
sound off, leaving only Dalamud TTS and Browsingway at roughly −73 dBFS, so the
bar was at maximum to compensate; DayZ was cranked for footsteps; FF7 has
normally loud audio and never needed it.

**Ruled out by measurement, not by argument** — the durable part:
5.1 channel-order mismatch (ALSA's `USB-Audio.conf` already routes correctly),
xruns and the quantum floor (sink errors 0, DSP ~10–15 µs against a 5.3 ms
period), garbage or clipping in the surround channels (RL/RR/FC/LFE captured
bit-exact zero), the 6-channel USB mode itself, the host `faudio` package, and
the Wayland driver. A 40 s in-game capture measured FL/FR peak −72.8 dBFS with
no zero-runs: **what PipeWire hands to ALSA is numerically pristine.** The noise
was never in software.

**Mechanism, honestly unexplained.** The tempting story — a very quiet signal
lifted by huge analog gain — is contradicted by ulu's own observation that
perceived loudness did *not* change at −26 dB. So the USB volume control is not
an output attenuator; it changes the bar's internal DSP state, and leaving
maximum exits some regime where the CONCEPT 12's own automatic gain or limiter
misbehaves. Firmware behaviour, which is why every software hypothesis failed.

**Operating rules that came out of it** (also in DESIGN.md):

1. Never run this bar at 100%. Raise the *source*, keep the sink attenuated.
2. Pass dB to `pactl`, never percentages — they are cubic,
   `percent = 10^(dB/60)`, so `2000%` is +78 dB, not +26 dB. That mistake once
   hard-clipped at 0 dBFS mid-game.
3. When re-staging gain: lower the sink first, raise the stream second, so
   there is never a moment of combined gain.
4. Resolve the card by id, never by index — it has already drifted `hw:5` →
   `hw:3`.

**A discrepancy the recovery turned up.** The verified fix was
`channelVolumes 0.050120`, i.e. exactly **−26.00 dB**. What the repo and the
live system actually carry is `0.068923` = **−23.23 dB**, 2.77 dB louder than
the value that was tested glitch-free over 30+ minutes of FFXIV. Somewhere
between the investigation and the backup the level crept up. That is a
plausible explanation for ulu's doubt that the problem is really gone — and it
means the captured "−26 dB fix" is not, in fact, the −26 dB fix.

## 2026-07-31 — Strawberry: the playlist as an anchor outside the repo

ulu's idea, and it is a good shape for this problem: keep a curated playlist as
a **file in the music folder**, extend it over time, and have a reinstall pick
it up again.

What the system says, checked rather than assumed:

- Strawberry keeps playlists in its **database** (`playlists`,
  `playlist_items`), not in the config — so a reinstall loses them.
- It can import and export playlist **files**, and the CLI exposes that:
  `--create <name> <file>`, `--load`, `--append`, `--play-playlist`.
- It has **no** auto-export setting. Saving is a one-off snapshot; there is no
  link between the running playlist and the file. Checked in the binary: only
  actions (`SaveCurrentPlaylist`, `SaveAllPlaylists`), no config key.
- It can write **relative paths** (`path_type`, "Relative path" in the save
  dialog), which is what makes the whole idea robust — the mount paths already
  changed once, from `/mnt/nvme0n1` to `/mnt/FilesMusic`.

So the file lives on a data disk this repo never touches: it survives by
construction, it grows with ulu's taste rather than with the repo, and it never
needs scrubbing. Only the **import** belongs to phoinix. Verified result: 159
entries, UTF-8, zero absolute paths, Japanese titles intact.

Stage 4 imports it as `Default`, guarded against creating a second playlist of
the same name on a re-run — names compared with `grep -Fxq` against
`SELECT name FROM playlists`, which keeps the name out of the SQL entirely.
`sqlite3` is safe to depend on here because `strawberry` depends on it, so it
exists wherever this step can do anything. Both paths tested: first run
imported 159 tracks, second run declined.

The honest limitation, recorded rather than hidden: **the file is an anchor,
not a mirror.** Adding tracks in Strawberry does not update it; re-saving over
the same path stays a manual step.

## 2026-07-31 — …and the anchor becomes a mirror

The manual re-save was the weak point: "remember to export after adding
tracks" is exactly the kind of resolution that quietly fails, and the file only
matters at reinstall time, which is precisely when nobody checks it. So phoinix
now writes it — `scripts/strawberry-playlist-export.sh`, the first tool in this
repo that is not a captured setting but a program of its own.

It reads Strawberry's database and rewrites the `.m3u`. Two facts made it
straightforward, both checked rather than assumed: playlist items reference the
collection by `collection_id` rather than carrying a path, so `songs` has to be
joined in and `pi.ROWID` is the ordering (there is no position column); and
lengths are stored in nanoseconds. URLs are percent-encoded `file://`, decoded
in shell by turning every `%` into `\x` and letting `printf %b` do the work —
which handles UTF-8 correctly because each byte is encoded separately.

`sqlite3` rather than python: `strawberry` depends on sqlite directly, so it
exists wherever this script can do anything at all, while python is in none of
our package lists and would only arrive as somebody else's dependency.

**Verified against the application itself**: run over the untouched playlist it
produced a file byte-identical to Strawberry's own export. That is the strongest
check available here — not "looks right" but "indistinguishable from what the
program writes".

**Trigger: session exit, not a timer** (ulu's call, and the better one). A
periodic job would run all day for a file that is read once per reinstall.
Losing the last session to a crash is an accepted cost. Implemented as a
oneshot with `RemainAfterExit=yes` and the real work in `ExecStop`, wanted by
`graphical-session.target`. Tested by starting the unit (nothing happens) and
stopping it (160 tracks written, including one added minutes earlier).

Ordering against Strawberry is unnecessary: it writes playlist changes to the
database immediately — verified by adding a track with the application still
open and nothing saved, and watching the row count rise.

Two guards, both earned earlier tonight:

- **Never write an empty result.** A missing or empty playlist leaves the file
  alone. The Places ordering was destroyed exactly this way a few hours ago.
- **Never write into a missing mount.** At session exit the data disks may
  already be going; writing into an unmounted `/mnt/FilesMusic` would create
  the file on the root filesystem, where it would then shadow the real disk at
  the next boot. The directory is checked first.

Plus one generation of backup (`.m3u.bak`) before each write, because this file
is years of curation and a bad export must never be the only thing left.

## 2026-07-31 — Applications, round 4: KeePassXC (and a private key in a config)

**The find that matters: `keepassxc.ini` contains an RSA private key.**
KeePassXC generates a KeeShare signing key — private key, public key and signer
name — into its plain config file the first time that settings page is opened,
whether or not KeeShare is ever used. Here it is *not* used: the share list is
`<KeeShare><Active/></KeeShare>`, i.e. empty. So a key that serves no purpose
sits in a world-readable-format file, and capturing that file the way `kwinrc`
is captured would have published it.

This is the second application in a row where wholesale capture would have
leaked a secret (Strawberry had an OAuth token). The rule from the start of the
application phase — read every file before importing it — has now paid for
itself twice. `[KeeShare]` is never read or written by phoinix.

Scripted: browser integration on, dark theme, monochrome-light tray icon, and
`Security/LockDatabaseIdle=false`. That last one is deliberate and was
confirmed rather than assumed — single-user machine, screen lock and session
lock are off for the same reason. It is written explicitly *because* a fresh
install would otherwise silently re-enable idle locking, and a password manager
that suddenly starts locking gets blamed on everything except the reinstall.

**Preselecting the database meant deliberately seeding state.** ulu wanted
KeePassXC to come up with his database already selected. That path lives in
`~/.cache/keepassxc/` (`LastDatabases`, `LastOpenedDatabases`,
`LastActiveDatabase`) — state, not settings — and on a fresh install it is
empty no matter which options are set. So stage 3 seeds those three keys, and
only when `LastDatabases` is absent, so a database opened later is never
overwritten by a re-run.

**Proven without looking at the screen.** Two failed attempts first, both worth
recording: checking open file descriptors showed nothing, because KeePassXC
reads the database header and closes the file again while asking for the
password; and the first test instance exited immediately because KeePassXC runs
single-instance and simply handed off to the running one (`SingleInstance=false`
in the test config fixed that). The atime trick then failed too — `/mnt` is
`relatime`, and the database's atime was already newer than its mtime.

What worked: point the seeded config at a **dummy file** with a deliberately
old atime. Starting KeePassXC moved that atime to now, proving it opened the
file named only in the seeded state — and ulu's real database was never touched
by the test at all.

Noted for ulu, not done: deleting the `[KeeShare]` section would remove the
pointless private key from disk. It regenerates only if that settings page is
opened again.

## 2026-07-31 — Session 3 closed: what the night actually produced

Handoff note. The session ran from post-install verification into the
application phase; four applications are done and the method is settled.

**The repo became self-contained.** Stage 3 used to restore seven config items
from a dated backup directory on a data disk, guarded by a bare
`if [[ -d "$BACKUP" ]]` — a missing disk skipped everything, including the
monitor fix, without a word. That was the single worst defect found tonight: a
clean stage-3 run followed by a black first login. Captured config now lives in
the repo and a missing source is a hard error.

**Three latent bugs, all found by testing rather than reading:**
`connector_geometry()` would have aborted stage 4 on every install the moment
its result was used in an assignment (awk `exit` → SIGPIPE); the Places
ordering step would have silently destroyed a working sidebar when no label
resolved; and the `[General] rules` index in `kwinrulesrc` would eventually
have had two stages overwrite each other's entries. None of these were visible
by inspection.

**Two secrets caught before they were published**, in two consecutive
applications. That ratio is the argument for the read-before-import rule.

**Knowledge recovered rather than re-derived.** The soundbar's −26 dB fix had
its *reason* lost; it was mined back out of the old Claude transcripts, along
with the finding that the value actually in use is −23.23 dB rather than the
verified −26.00 dB. That discrepancy is the most likely explanation for ulu's
long-standing doubt that the glitching was ever fixed.

**A years-old bug characterised**: the sporadic black flash on the ultrawide is
in-service DP link retraining, not software — the link runs at the DP 1.4
ceiling with no DSC and no FEC, and the flash leaves no journal trace at all.
The 144Hz experiment is running.

**One tool rather than a setting.** `scripts/strawberry-playlist-export.sh` is
the first program in the repo: it writes the playlist back to its file on
session exit, which closes the gap between "the file survives a reinstall" and
"the file is current".

## 2026-07-31 — The name: history rewritten, repository recreated

The end-of-session scan ran over the **whole repo** rather than over the files
being imported, and found what four earlier scans had missed: the SSH key in
`hosts/desktop/authorized_keys` carried a comment field with ulu's real name
and work e-mail. That file was written by hand on day one and had therefore
never been through an import check — the scans were aimed at incoming material,
not at what was already there.

Pulling that thread found far more than one file:

- **35 of 62 commits** still had `<real name> <work address>` as author *and*
  committer. The anonymisation of 2026-07-30 had only covered part of the
  history.
- Early versions of `CLAUDE.md`, `DESIGN.md`, `PROTOKOLL.md`, `LOG.md` and
  `STATUS.md` named him in running text.
- `authorized_keys` carried it in essentially every commit.

Rewritten with `git filter-branch` (no `git-filter-repo` on this machine):
`--env-filter` for author and committer identity, `--tree-filter` replacing
every spelling variant in file contents. Then the `refs/original` backups were
deleted, the reflog expired and the object database pruned.

**Force-pushing was not enough.** Verified rather than assumed: after the
force-push, `api.github.com/repos/.../commits/<old sha>` still answered **HTTP
200**. Unreferenced objects stay reachable by SHA until GitHub garbage-collects
them, which is not guaranteed to happen on any schedule. With zero forks, zero
stars and a 34-hour-old repository, deleting and recreating it was both cheap
and certain. After recreation the same request answers **HTTP 422** — the
strongest evidence available from outside that the objects are gone.

Final verification went over **every object in the database** (433: blobs,
commits, tags), not just reachable commits, plus commit metadata across all
refs, the working tree including binaries, git config, hooks, `packed-refs`,
reflog and dangling objects. Zero hits. The rewrite backup that had been kept
as the rollback path was checked (it did contain the old name), then deleted.

**What stops it coming back:** there is no global git identity on this machine,
and the repository sets `uluToyon` plus the GitHub noreply address locally, so
every new commit is anonymous by default. Adding a global `user.name` would
reopen exactly the hole this came through.

Two lessons, both cheap to state:

1. **Scan the whole repo, not the incoming file.** Every check until now
   targeted material being imported. The leak was in a file written by hand
   before any of those rules existed.
2. **A force-push does not delete anything.** It moves a reference. For a
   public repository, removal means recreating it — or trusting a support
   request.

Small lesson worth keeping, since it cost two rounds of confusion: **newly
installed fonts only reach processes started afterwards.** Kanji rendered as
boxes in Konsole and in the Plasma widget while Strawberry showed them fine —
the difference was purely process age. Irrelevant on a fresh install (the
package is in `packages/apps.txt`), relevant every time a font is added live.

While at it, a correction to something claimed earlier tonight: `sqlite3` is
*not* missing on this system. An earlier check queried an empty table, printed
nothing, and was misread as "tool absent".

**Bonus: a mystery from earlier tonight, solved.** The transcript documents a
*separate* problem from 07-25 — `force-clock.sh` pinning a non-power-of-two
`clock.force-quantum 500` on the AMD HDMI batch device, causing dropouts in
FF7 Remake, fixed by disabling it in favour of a clean `10-clock.conf`. That is
exactly the `disabled-forceclock.bak/` directory found in the PipeWire config
during the repo import and excluded as switched-off leftovers. The call was
right; now the reason is on record too.

## 2026-07-31 — Session 4: the one command

ulu's requirement, stated plainly: **one command on the ISO kicks off the whole
installation.** Typing passwords is fine; typing the target disk's serial is
not.

**The serial prompt was ceremony.** `hosts/desktop/config.sh:3` already reads
`DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NX0T343303X"` — the by-id
path *contains* the serial. So `read -rp "Type the disk serial to continue"`
asked ulu to retype a string sitting two lines above it in the same repo. It
proved that the config had been read, nothing more, and it was the single thing
making a one-command install impossible.

What actually protects the disk, and always did, is `[[ -e "$DISK" ]]`: on a
machine that is not this one the by-id path does not resolve and stage 1 aborts
before touching anything. That is a *machine-level* lock and it needs no human.
Verified both ways rather than argued: pointed at a made-up by-id path stage 1
exits with "does not exist"; run against this running desktop it exits with
"has mounted partitions — refusing". The prompt is replaced by a 10 s countdown
(`PHOINIX_YES=1` skips it), which covers the one case the by-id check cannot —
right machine, right disk, started by accident.

**The chain, and how each link arms the next.** Nothing is started by hand
after the first line:

```
curl … bootstrap.sh | bash -s desktop
  → stage 1 (destructive)  → stage 2 (chroot)  → reboot
  → ~/.zprofile hook       → stage 3          → reboot
  → systemd user unit      → stage 4
```

Stage 4 was already armed this way, which is why the pattern was not invented
here — it was extended downwards.

**A gap that had been bridged by hand every time.** Stage 1 rsyncs the repo to
`/root/phoinix`, root-owned. Stage 3 must run as the user (AUR builds refuse
root) and could never read it there. The README promised `~/phoinix` — and
**no script had ever created it.** Stage 2 now does, once: guarded by
`! -d "$USER_REPO/.git"`, because from the second run onwards that directory is
a working repo with its own commits (it is where sessions happen), and
refreshing it would eat exactly that work.

**Stage 3 starts from a login shell, not a systemd unit.** Weighed explicitly.
A unit would fire without any login at all, but it has no terminal: `sudo -v`
would fail, so it would need a passwordless-sudo drop-in — a hole that then has
to be closed again — and the long pacman/AUR phase, the part of this install
that has actually broken before (paru-bin against a libalpm soname bump), would
run invisibly into the journal while the screen sits blank. A login shell gets
the password prompt, the output on screen, and the right user for free.
`.zprofile` is unoccupied: the dotfiles bring only `.zshrc` and `.p10k.zsh`, and
it is read by login shells only, not by every terminal. Disarmed by
`~/.local/state/phoinix/stage3.done`, written by stage 3 **last** so a run that
died halfway is retried at the next login instead of skipped — and deleting the
marker re-arms it, the same contract stage 4's marker already has. Wrapped in
`flock -n` in case a second login (or an ssh session from the laptop) arrives
mid-run.

**One bug, found by the dry run rather than by reading.** `bootstrap.sh`
reattaches `/dev/tty` to stdin, because under `curl | bash` stdin is the pipe at
EOF — a `read` gets nothing and a `read -t` returns instantly instead of
counting. The first version guarded that with `[[ -r /dev/tty ]]`, which tests
the permission bits and cheerfully says yes where there is no controlling
terminal at all. Worse, `exec` is a special builtin: a failed redirection on it
kills a non-interactive shell outright, so the installer would have died on the
spot in exactly the environments where it is most likely to be scripted. The
test has to be a real open in a subshell: `if ( : < /dev/tty ) 2>/dev/null`.
Same reasoning killed `read -t` for the countdowns — they use `sleep`, which
needs no stdin at all.

**Verified in isolation, not yet as a whole.** The login hook was run under zsh
against a fake `$HOME` through all three paths (stage 3 fails → still armed;
succeeds → marker written, reboot; marker present → silent). `bootstrap.sh` was
dry-run with the stages stubbed: fresh clone, existing clone, tag pin, missing
host argument. Both stage-1 guards were fired for real. The full chain has
**not** run on hardware or in QEMU — that is now the top item in STATUS.md,
because a broken bootstrap is discovered on the day the machine is already
wiped.

Documentation caught up with the goal: the README's "Don't `curl | bash` the
disk stage" and the matching DESIGN.md caveat are gone, replaced by a section
that names where the protection actually sits. Both had been written for the
one-off SSH-driven first install and then generalised into a rule that
contradicted the reason this repo exists.

## 2026-07-31 — The QEMU run: six defects, five of them waiting for the next reinstall

`DESIGN.md` has called the QEMU loop "the thing that makes hand-rolling viable"
since day one, and it had never been run. It got run. The result is the
strongest argument in this repo for testing over reading: **none of the six
defects below was visible by inspecting the scripts, and five of them would
have hit the next real reinstall.**

Harness: `scripts/qemu-test.sh` plus `hosts/qemu/`, a throwaway machine whose
`DISK` is a by-id path built from the serial the script hands to QEMU — so
stage 1's real guard is exercised rather than bypassed. Verified both ways: a
made-up by-id path exits "does not exist", and pointed at the running desktop it
exits "has mounted partitions — refusing". The ISO boots on a serial console
with its own boot options read out of the ISO (`archisosearchuuid` changes with
every monthly image), so the whole run is scriptable and logged.

**1. `bootstrap.sh` did nothing at all.** The one-liner returned to a prompt in
silence. Under `curl | bash`, stdin is the pipe bash is reading the script FROM,
and the `exec < /dev/tty` added to give the stages a terminal replaced exactly
that source: bash lost the rest of the script and read the remainder from the
terminal. Reduced to three lines afterwards:

```
printf 'echo A\nexec < /dev/null\necho B\n' | bash     # prints only A
```

Fixed by redirecting per command. That closes a second hole in passing: a child
reading stdin (pacman's "Proceed with installation?") would have eaten the
script text.

Two false leads on the way, both worth recording. The console echo showed
`/m aain/` and was read as a mangled URL — it is zsh redrawing at the line wrap,
`^M^[[K`, and the URL was always intact. And the second attempt was probably
working when it was aborted for being "silent": `git` is **not** on the current
Arch ISO, so `pacman -Sy --noconfirm git` runs first and its database sync takes
longer than the patience it was given. `STATUS.md` had claimed "git and curl are
both on the Arch ISO". Only the fallback saved that.

**2. Host-specific kernel parameters were hardcoded in `stage2.sh`.** The boot
entry carried `video=DP-2:… video=DP-1:…` inline, so the test VM was configured
for monitors it does not have. Invisible while one host existed; obvious the
moment a second did. Now `KERNEL_PARAMS` per host, and the desktop's rendered
entry is unchanged, checked rather than assumed.

**3. The sudo keepalive in `stage3.sh` died on its first failure.** Three
password prompts in one run. `sudo -n true` sat in the loop BODY and the
subshell inherits `set -e`, so a single failed refresh ended it silently. As the
loop CONDITION, a lost ticket ends the loop instead of aborting it. Measured
afterwards: the prompts that remain are both from the paru bootstrap
(`makepkg -si`), which by definition runs before paru exists; the AUR phase
itself, now with `--sudoloop`, asks **zero** times. So this is not "one password
and walk away" — the paru bootstrap asks twice on a fresh install, and that is
now a documented property rather than a surprise.

**4. Stage 3 assumed every host has captured configs.** It aborted after
completing every package phase because `hosts/qemu/home/` does not exist — and
should not, since the desktop's captured files are keyed to four monitors' EDID
hashes and to a soundbar the VM lacks. Relaxing the hard error to "skip if
absent" would have reopened exactly the hole it was written for (a missing
source, a clean run, a black first login). So the host **declares** it:
`CAPTURED_CONFIGS`, and an undeclared host is an error too. Adding a host is now
a decision rather than an omission.

**5. Stage 4 died with `PANEL_MAIN_CONNECTOR: unbound variable`** — true,
useless, and two hundred lines from the file that had to change. It now checks
the required declarations by name and says which are missing. The TV clone, the
side strips and `PLACES_ORDER` became optional, defaulted in `config.sh`: a
machine with one screen is the normal case rather than an incomplete one, and
the laptop this repo already plans for has exactly one. An undeclared screen
yields the same "not connected" geometry as an unplugged one, which `panels.js`
already skips — absence needs no second code path.

**6. `ROOT_SIZE=12G` for the test host.** Mine, not the repo's: the first guess
assumed the test only had to reach a booting system, and stage 3 ran for half an
hour before dying on disk space mid-AUR. A test host has to be sized for the
real package set or it tests the installer only up to where it runs out of room.

**What the harness gained on the way.** Stage 4's result — a greeter, a panel —
is not observable on a serial line, and an unobservable test proves nothing. So
`qemu-test.sh` opens a QEMU monitor on its own socket: `screendump` to look,
`sendkey` to type. That turned out to be worth more than planned. The intention
was to skip the greeter and start a session by hand; instead the password was
typed into the real PLM greeter (14 dots for 14 characters, checked on the
screenshot), so the **greeter login is covered too**.

**The chain, verified end to end:** one-liner → clone → stage 1 → stage 2 →
reboot → login hook → stage 3 → greeter login → stage 4. Stage 4's evidence is
worth keeping, because it is the fresh-install path that never existed before:
Kickoff favourites written against a freshly generated activity UUID, the flat
pointer profile applied to a mouse discovered at runtime, `archroot`/`archhome`
resolved from labels to `vda2`/`vda3`, window rules placed at `Virtual-1`'s
origin, marker written. The panel came up with exactly the seven pinned
launchers in order, where Plasma's default had been before.

Also confirmed in passing, none of it planned: the restored `.zshrc` is active
(the `ls`→`eza` alias broke one of my own commands), Strawberry autostarts, the
panel clock reads `31.07.26` from the German format locale, and stage 3 is
genuinely re-runnable — it was re-run after the fix and completed from where it
had failed.

One process lesson, cheap and recurring: a watcher that greps a whole console
log finds the ERROR from the PREVIOUS run and reports a failure that did not
happen. Match from a mark, not from the top of the file.

And one that this repo has now learned twice: `${!v}` is bash-only indirect
expansion, and this session's shell is zsh, so testing a bash snippet at the
prompt reported "bad substitution" for code that is perfectly correct in the
file it lives in.

## 2026-07-31 — The parent-sized dialogs are ours, and the obvious fix does not work

A years-old annoyance of ulu's, parked in `STATUS.md` as "waiting on ulu": a
confirmation dialog opening at exactly the size of its parent window. The
recorded diagnosis was a previous distro's `[Windows] Placement=Maximizing`,
together with the honest note that the setting was found **nowhere** — not in
any captured file, not in Arch's defaults.

It was found nowhere because it was never there. **phoinix does it.**

Spotted by accident in the QEMU VM: Strawberry's sponsoring dialog was small
while stage 4 was still failing, and window-sized once stage 4 had run. Then
measured rather than eyeballed — the dialog opens at `0,0` in `900x700`, which
is character-for-character that host's `STRAWBERRY_CONNECTOR` origin and
`STRAWBERRY_SIZE`. Those are our numbers, not Qt's. ulu confirmed the same on
the desktop: `Shift+Del` in Dolphin opens a dialog the size of Dolphin.

Cause: stage 4's rules match on `wmclass` alone, and a KWin rule that names only
an application matches every window of it, dialogs included. "Apply Initially,
size 1295x839" is therefore also an instruction about the "are you sure?" box.

**The obvious fix does not work, and that is the part worth recording.**
`types=1` (NET::NormalMask) was added, committed, and reverted within the hour:
NET window types are an X11 concept, and under Wayland an application's toplevel
and its dialog share a single app id, so the rule matches both regardless. The
dialog is pixel-identical without the key and with it.

So the size/position rules and the unwanted behaviour are, as things stand, the
same mechanism — the rules are why Konsole and Strawberry open on their intended
monitors at all. Four options are written up in `STATUS.md`; none is ulu's yet.

**Two process notes, both about not fooling yourself.**

The first "proof" that `types=1` failed was worthless: the FIFO holding the VM's
serial console open had been started with `sleep 600` instead of the usual long
timeout, so it expired mid-experiment and every command after it went nowhere.
QEMU kept running and the screen kept showing the old state, which looks exactly
like a fix that did not take. Caught by noticing the console log had stopped
growing, not by anything the experiment itself reported. **A silent control
channel and a failed experiment are indistinguishable from the outside** — so
the channel has to prove itself (a marker command with a timestamp) before its
silence means anything.

And the diagnosis was announced to ulu one step before it was earned: the rule
was *plausible* from the screenshots and only *proved* later by the geometry
matching to the character. It happened to be right. The fix, announced with the
same confidence, was wrong. Report the measurement, not the hypothesis.

## 2026-07-31 — Asking KWin instead of guessing, and a fix parked on purpose

The dialog question was settled by asking KWin directly rather than reasoning
about it further. A short script through
`org.kde.KWin /Scripting … loadScript`, printing every window's properties into
the journal:

```
PHX|org.strawberrymusicplayer.strawberry|dialog=false|normal=true|modal=false|transient=false|caption=Strawberry Music Player
PHX|org.strawberrymusicplayer.strawberry|dialog=false|normal=true|modal=false|transient=true |caption=Sponsoring Strawberry — …
```

**KWin does not consider that dialog a dialog.** `dialog=false`, `normal=true`,
not even `modal`. So `types=1` was not mismatched — it matched correctly and had
nothing to exclude, and window types are finished as an avenue for good. Which
also retires the theory that Wayland "loses" the type: KWin simply classifies
this window as normal, and it is the application that decides how its own
sub-window is advertised.

**The two windows differ in exactly one field: `transient`** — `false` for the
main window, `true` for the dialog, which has a parent. That is the separating
line, and the only other candidate (matching on the window title) is
language-dependent and therefore not something to put in this repo.

`kwinrulesrc` has no `transient` matcher, so this cannot be done with rules at
all. KWin's scripting API does see it, and stage 4 already talks to Plasma's
scripting interface — so the fix would be a small KWin script that phoinix
installs, hooked to `windowAdded`, applying geometry only to non-transient
windows. It would replace the three rules and is the only option that costs
nothing: monitors AND sizes kept, dialogs normal.

**ulu's decision: option 1 for now — keep the rules, accept the dialogs.** The
monitor placement is worth more than the annoyance, and the script is real code,
resident, on an API the repo would then depend on. The fix is written up in
`STATUS.md` in enough detail to build without redoing any of the investigation,
because ulu explicitly asked for it to be kept rather than dropped.

Worth stating plainly, since this session produced a lot of the opposite: this
is a bug we found, characterised to the exact field, and then deliberately did
not fix. That is a legitimate outcome, and the reason it is safe is that the
*reason* is on record — the failure mode `LOG.md` documented for the soundbar
(a captured fix whose rationale was lost, then undone by the person it
protected) applies just as much to a fix deliberately not made.

## 2026-07-31 — Applications, round 5: ProtonVPN as a split tunnel

ulu named ProtonVPN as the next application and set two requirements that turned
out to be different problems: **qBittorrent must never reach the internet
outside the tunnel**, and **nothing except qBittorrent may go through it.**

**The folder said something else than the repo.** `packages/apps.txt`,
`STATUS.md` and the wishlist all described ProtonVPN over `.ovpn` profiles in
`/mnt/FilesMusic/OpenVPNConfigs`. Every file in there is **AirVPN**
(`*.vpn.airdns.org`), the newest from April 2024, and each carries an inline
private key with no `auth-user-pass` — certificate-only, i.e. the key IS the
credential. Leftovers from an older subscription that the repo had recorded as
the current setup. Worth remembering as a class: a documented "manual step" that
nobody has performed since it was written is a claim, not a fact.

**Nothing was configured at all.** No VPN connection existed on the machine, so
this was never a migration — which removed the main argument for staying on
OpenVPN.

**WireGuard, for a reason that is about phoinix rather than about protocols.**
Proton's OpenVPN profiles need a separate OpenVPN username and password, so an
import can never be unattended: either it is typed after every reinstall, or a
plaintext credential lands in a NetworkManager connection file. A WireGuard
config carries its own key and imports in one command. NetworkManager speaks
WireGuard natively, so `networkmanager-openvpn` (and `openvpn` with it) left the
package set. Obfuscation, OpenVPN's real advantage, is irrelevant: ulu's VPN
runs at home only.

**Port forwarding decided the shape, and it needed checking rather than
assuming.** Proton's WireGuard configs carry a `NAT-PMP (Port Forwarding)`
toggle, available only on P2P servers, and the granted port has a **60 second
lease** — so it is a service that renews, not a setting. Both of ulu's configs
came back with `NAT-PMP = on` and `Moderate NAT = off`, which is the right pair:
Proton documents that the two are mutually exclusive. That trade — port
forwarding *or* console-style Type 2 NAT — is the real decision on a gaming
machine, and it dissolved once ulu chose "VPN for qBittorrent only".

**The guarantee is the kernel's, not the application's.** qBittorrent's
"bind to interface" setting was set, but it is the application promising
something about itself: it does not survive a bug, an update that resets it, or
a mistyped option, and it never covered name resolution at all. So qBittorrent
runs with a dedicated group (`sg`, via a wrapper the desktop entry points at)
and an nftables output rule drops every packet from that group that would leave
through anything but `proton0`. A group rather than a separate user, because a
GUI application in ulu's session would otherwise drag in a second home
directory, download-folder permissions and Wayland socket access to express one
bit. The ruleset is deliberately **not** an input firewall — policy stays
`accept`, so enabling `nftables.service` does not hand the machine a posture it
never had, and the laptop's SSH access keeps working.

**DNS was the subtle part, and it nearly broke the whole thing.** Proton's
config points at `10.2.0.1`, a resolver that only exists inside the tunnel. With
one global `resolv.conf` both options are bad: route all DNS through the tunnel
and a dropped tunnel stalls the entire desktop in lookup timeouts; route
qBittorrent's DNS past it and the nftables rule drops the query, leaving
qBittorrent unable to resolve anything at all. Also worth naming: doing nothing
is not neutral — NetworkManager gives VPN connections DNS priority by default,
so the whole system would have moved into the tunnel silently. `systemd-resolved`
removes the dilemma by keeping DNS per link, and ulu chose it from three options.
The nftables rule accepts loopback for exactly this reason: qBittorrent talks to
the resolved stub, and resolved — not being in the group — queries Proton
through the tunnel itself.

**Verified in QEMU before touching the desktop**, which is the point of having
the VM. With the group created, the ruleset loaded and no tunnel present:

- a process **outside** the group reached the internet (nothing else broke);
- a process **inside** the group could not resolve anything;
- a process **inside** the group could not reach a raw IP either — the case
  that proves it is not merely DNS filtering;
- loopback still worked from inside the group;
- the drop counter stood at 15 packets, so the rule demonstrably fired.

**And the test found a bug that would have made qBittorrent unlaunchable.** The
wrapper refuses to start unless something demonstrably enforces the tunnel, and
used `systemctl is-active nftables.service` as its proxy, since a normal user
cannot read the ruleset. Arch ships `nftables.service` as a bare `Type=oneshot`
with **no `RemainAfterExit`**: it loads the rules and goes inactive while they
stay in the kernel. So on a perfectly healthy machine the check said "not
active" and qBittorrent would never have started — with the rule loaded and
counting drops in the same breath. A drop-in adds `RemainAfterExit=yes`, which
makes the unit's three states mean what the check assumes. The packaged unit has
no `ExecStop`, so nothing else changes.

Two smaller things caught by the end-of-session scan and the read-before-import
rule: the WireGuard files never enter the repo (only `VPN_CONFIG_DIR` does), and
a stage 3 comment had quoted ulu's actual Proton server name — not a credential,
but a discovered identifier in a public repo, removed.

## 2026-07-31 — The split tunnel, as it actually had to be built

The entry above describes a design that did not work. It was written before the
thing had ever carried a packet, and running it on the desktop refuted it three
times over. Recorded in full, because every one of the three is the sort of
mistake that looks like a working design on paper.

**1. `never-default` does not keep a WireGuard connection out of the way.**
NetworkManager sees `AllowedIPs = 0.0.0.0/0`, enables its own *auto default
route*, and installs a private table plus `suppress_prefixlength 0` rules that
capture everything. So the whole machine was running through the tunnel — the
exact opposite of the requirement — while `ipv4.never-default` reported `yes`.
The property is not ignored; it only governs the main table, which is not where
NetworkManager put the route. Fix: `wireguard.ip4-auto-default-route no` (and
ip6), and confine the tunnel's default route to its own table.

**2. The drop rule strangled the tunnel it was protecting.** WireGuard's
encapsulated packets must leave over the ordinary interface — that is what a
tunnel is — and they inherit the group of the process that caused them. So
"group `vpnonly`, not leaving via `proton0`" matched the encryption itself.
Measured: 7 dropped packets per connection attempt, while `ip route get` pointed
correctly at the tunnel. Fix: WireGuard stamps its own `fwmark` on those
packets, and the rule makes an exception for exactly that mark — precise,
unlike an exception on UDP port 51820, which anything could have used.

**3. And the filter sat in the wrong hook.** With marking in place the packets
were still dropped, and the counters said something very specific: the *same*
7 packets appeared in the marking rule and in the drop rule of a single pass.
`nft(8)` explains it — a `route` chain performs its new route lookup once the
packet "is about to be accepted", i.e. at the **end** of the output hook. A
filter chain sitting inside that hook therefore still sees the OLD output
interface, and drops packets that were on their way to being rerouted into the
tunnel. Moving the filter to **postrouting** puts it after the reroute, where
`oifname` is the truth. Marking stays in output, where a route chain belongs.

Also found while wiring it up: the port-forwarding service asked `natpmpc` for a
mapping without being in the group, so its request to the in-tunnel gateway went
out of the ordinary interface to the LAN router instead — `ip route get 10.2.0.1`
showed it resolving via the local gateway, in plain sight.

**What the finished thing measures on the live desktop:**

| check | result |
|---|---|
| ordinary traffic | via `enp8s0`, ulu's own line |
| group traffic | via `proton0`, exit inside Proton's network |
| the two exit addresses | different — the traffic is separated |
| drop counter during normal use | 0 |
| switching CH → NL mid-session | group traffic continues, nothing to re-do |
| **tunnel down entirely** | ordinary traffic keeps working, group blocked by name AND by raw IP |

The last row is the requirement ulu actually stated, and the shared interface
name is what makes the fifth row true: both connections are `proton0`, so
qBittorrent's binding and the nftables rule survive a change of country.

**One test that nearly reported a leak, and why it did not.** Bringing the NL
connection down appeared to let group traffic straight out. It had not: the CH
connection autoconnects, NetworkManager had raised it within the second, and the
traffic went through *that* tunnel. The test only became valid after autoconnect
was disabled on both. A negative result is worth as much as a positive one only
when the setup is what you believe it is.

**Still open: port forwarding.** `natpmpc` is refused by both servers — CH says
"the gateway does not support nat-pmp", NL times out without answering. Both
configs carry `NAT-PMP (Port Forwarding) = on`, but that header records what was
*requested* when the file was generated, not what the server can do: Proton
grants port forwarding only on P2P servers. The likely answer is that neither
CH#919 nor NL#586 is one. Torrenting works without it; it costs peers, not
function.

**And the QEMU harness could not have caught any of this.** It ran without a
tunnel, so it only ever exercised the blocking half — which is precisely the
half that was already right. A test that cannot fail in the interesting
direction is not a test of that direction.

## 2026-07-31 — Applications, round 6: qBittorrent (and a config writer that wrote nothing)

**The finding that matters: `kwriteconfig6` must never touch qBittorrent.conf.**
That file is Qt's QSettings format, where the backslash in `Session\Interface`
is a group separator written as ONE character. KConfig treats a backslash as an
escape and doubles it on save — and because it rewrites the whole file, it
doubled qBittorrent's own keys too. The result looked entirely plausible in the
file and was completely inert: qBittorrent read not one setting phoinix wrote.
The WebUI was never enabled, and the interface was never bound — through the
whole of the VPN work, the "first of two lines" was not there at all.

It surfaced only because ulu opened qBittorrent for his settings round: the
application rewrote the file in its own format, every backslash came back
single, and our keys vanished entirely because they had never been read.

Worth recording as a wrong turn too: a few hours earlier the doubled backslashes
had been noticed and dismissed — "qBittorrent's own convention", on the evidence
that `Session\\Port=48815` sat right next to them. That line had itself been
through kwriteconfig6. The corroborating evidence was the damage.

Replacement: a line-oriented writer that sets one key under one section and
leaves every other byte alone. That property matters twice here — the escaping,
and the `@ByteArray` blobs of window geometry that any full-file rewriter would
re-encode.

**Method, unchanged and still earning its keep.** Snapshot `~/.config`, let ulu
click, close the application, diff the WHOLE tree. Two of his three settings
were once again *outside* qBittorrent: an autostart entry and a KWin rule. And
"close the application" needed saying twice — qBittorrent's `CloseToTray` means
the window going away is not the process going away, and it writes its config on
exit only.

Three details from that diff:

- **The autostart entry came out pre-wrapped.** KDE copied it from
  `~/.local/share/applications/`, i.e. from phoinix's own launcher override, so
  it starts qBittorrent inside the VPN group. Had it copied the packaged entry,
  every login would have started an unprotected client.
- **The window rule needed an OFFSET**, not just a connector. qBittorrent shares
  DP-2 with Strawberry, which occupies the left half, so its position is "that
  monitor's origin plus 1920". Stored as `QBT_CONNECTOR` + `QBT_OFFSET`; the
  absolute `1920,804` the GUI produced would silently point elsewhere the day a
  screen moves.
- **The window class has a leading space.** qBittorrent reports an empty
  instance name, so with `wmclasscomplete=true` KDE stored
  `\sorg.qbittorrent.qBittorrent`. Reproduced verbatim — without it the rule
  matches nothing.

Verified as the round demands: the script's values against ulu's hand-made
state. `kwinrulesrc` came back byte-identical, and re-running the qBittorrent
block changed only the keys he had never set.

**Then the whole port-forwarding chain was removed** (ulu: "mir ist die WebUI
egal"). The WebUI existed for exactly one reason — qBittorrent does not re-read
its config while running, so an API was the only way to hand it a new port — and
Proton's port has a 60 second lease, which rules out doing it by hand. So the
two stood or fell together. Both of ulu's servers refuse NAT-PMP anyway, and it
had been my addition rather than his requirement. Out went the renewal service,
its unit, `libnatpmp`, `QBT_WEBUI_PORT` and, once nothing referenced it,
`VPN_GATEWAY`. Stage 3 now *removes* a previously installed unit, because a
stage that drops a feature has to take its leftovers with it.

Recorded for a possible revival: qBittorrent refuses to enable the WebUI until
credentials exist ("WebUI: Credentials are not set") even with `LocalHostAuth`
off, so it would need a random password generated at install time whose PBKDF2
hash is written to the config — never a password in the repo. The generation was
proven to work with `openssl kdf` before the feature was dropped.

**And the VPN got its real confirmation on the way**, from qBittorrent's own log
rather than from `curl`:

```
Successfully listening on IP. IP: "10.2.0.2". Port: "TCP/27562"
Detected external IP. IP: <Proton's exit>
```

The application binds to the tunnel address and sees Proton as its external
address — the first end-to-end proof with the program the whole construction
exists for.

## 2026-07-31 — The alias that could not be added, and the file that fixes it

Closing the last everyday path by which qBittorrent could start unprotected:
the panel launcher and the autostart entry both go through the wrapper, but
typing `qbittorrent` in a terminal did not. An alias handles that — and adding
it exposed a defect in how aliases were managed at all.

The block lived inline in `.zshrc`, appended behind
`grep -q "phoinix aliases"`. That guard makes the append idempotent and, in the
same stroke, makes the list **immutable**: the block is written once, so a new
alias reaches fresh installs only and every machine that already has the block
keeps the old list forever. Nothing announces this; stage 3 reports success and
changes nothing.

Aliases now live in `~/.config/phoinix/aliases.zsh`, a file phoinix owns
outright and rewrites on every run, with a single sourcing line added to
`.zshrc` once. Stage 3 also retires the legacy inline block, so the two cannot
disagree. Verified on the live machine: exactly the three old lines replaced by
the three new ones, the rest of `.zshrc` untouched, and `nano`→`micro` survived
the migration.

Stated plainly in the file itself, because an alias invites overconfidence: it
covers the shell and nothing else — not `/usr/bin/qbittorrent`, not a .desktop
file from elsewhere. The guarantee remains the nftables rule; this only removes
a way to trip over it.

## 2026-07-31 — Applications, round 7: Discord (and a package that is only a downloader)

The shortest round so far, and the reason is structural: **Discord's settings
are not on this machine.** Theme, notifications, audio devices, keybinds,
privacy — all of it lives server-side in the account and comes back at login,
the same class as Brave's sync chain. Its `settings.json` came out of ulu's
round at 168 bytes' worth of substance: window bounds, a background colour and
Discord's own `DESKTOP_TTI_*` experiment flags. Not one decision.

So the round produced exactly two things, and both were once again *outside*
the application: an autostart entry and a KWin rule. The rule puts Discord on
the lower half of the portrait monitor, directly beneath Konsole — an offset
from the connector origin, like qBittorrent on DP-2. Reproduced byte-identically
from the script.

The autostart entry KDE writes turned out to carry the same keys and values as
the packaged `discord.desktop`, only alphabetically reordered, so stage 3
installs the packaged file rather than a copy that could go stale.

**The interesting find was in the packaging.** ulu asked whether
`SKIP_HOST_UPDATE` in `settings.json` is still relevant — he did not want
Discord checking for an update at startup and then failing to load its UI. The
answer came from the machine rather than the wiki (which blocks automated
fetches): `/usr/bin/discord` is a ~40-line shell script. On first run it calls
`/usr/share/discord/updater_bootstrap`, which downloads the actual client from
`updates.discord.com` into `~/.config/discord/app-<version>/` — 554 MB — and
execs it from there. The package itself contains six files.

That makes the setting not merely unnecessary but harmful. The workaround
belongs to the era when the package shipped the application under a read-only
system directory: Discord noticed a newer version, tried to update itself,
could not write there, and hung — precisely ulu's symptom. In this model the
application sits in a directory it owns and updates fine. Setting the flag
would freeze the client at its installed version until Discord's servers refuse
to talk to it, i.e. it would *cause* the failure it was meant to prevent.
Recommended against, and recorded so the question does not get re-answered from
folklore.

Two consequences of the bootstrapper model belong in the manual steps:
`pacman -Syu` does not update the running client, and a fresh phoinix install
re-downloads half a gigabyte the first time Discord is started.

**A process check of mine was wrong twice.** `pgrep -f '[Dd]iscord'` matched my
own shell, whose command line contained the pattern — so it reported Discord
still running after ulu had closed it, and I passed that on as a warning. The
bracket trick only defeats self-matching for the *pattern's* own process, not
for a shell that happens to carry the word for other reasons. `pgrep -x` on the
exact process name is the check that means something.

## 2026-07-31 — Applications, round 8: Brave, and a flicker that is not Brave's

ulu's round produced exactly one line worth keeping, and it took a question to
find out what it meant.

Everything else was profile: bookmarks, Local Storage, half a dozen LevelDB
logs. That profile returns through Brave Sync and contains `Login Data`,
`Cookies`, `Web Data` and `Local State`, so none of it is captured — the same
shape as Discord, where the settings live in the account rather than on the
disk. No `brave-flags.conf` was created (`/usr/bin/brave` reads one for start-up
flags; ulu needs none), and no autostart entry.

What remained was a KWin rule with a single key: `adaptivesync=false`, forced.

**Asking why was the whole value of the round.** A bare `adaptivesync=false`
reads like an accident in two years, and `LOG.md` already records what that
costs: the soundbar's −26 dB was captured without its reason, the reason was
lost, and ulu nearly undid the fix himself. So the reason was asked for before
the line was written down.

It is video. A constant slight flicker while watching, YouTube being the case
that drove him up the wall — **and mpc-qt does exactly the same**. Those two
share nothing except playing video, which moves the finding out of Brave
entirely.

The mechanism that fits, inferred rather than measured: DP-1's VRR range is
48–170 Hz, video runs at 24/25/30 fps, so the content sits *below* the range,
the display duplicates frames to compensate, and the refresh rate oscillates
between two states. Games never show it because they stay inside the range.

That makes per-application the right level, not a workaround for the lack of
something better. Switching VRR off at the output would cure the flicker and
simultaneously discard the reason VRR is enabled on a gaming machine. And it
predicts recurrence: every video player will want this rule, mpc-qt first.

Recorded explicitly to keep two things apart that share an output: this flicker
is continuous, only during video, and cured by disabling VRR. The black FLASH
in STATUS.md is instantaneous, happens with nothing playing, and is diagnosed as
DP link retraining. Conflating them would send the next investigation sideways.

## 2026-07-31 — Applications, round 9: Steam, which yielded nothing to script

The first round that produced no setting at all — and that is worth an entry,
because "nothing to do here" is a result rather than an omission.

Steam had never been started on this machine. Its durable state lives in
`~/.local/share/Steam` (3.2 GB) and `~/.steam`, is bound to the account, and
carries auth tokens, so none of it is captured. After ulu's round `~/.config`
held two changes, both Plasma bookkeeping: a notification source marked seen,
and a screen mapping for the desktop icon Steam had just created. No autostart,
no window rule, no preference worth a line.

**The library re-attached exactly as the mount-path decision intended.** 39
games, 837 GB, no re-download. And the reason it is that cheap turned out to be
a fact worth recording: the identity is not invented per install —
`/mnt/Games/SteamLibrary/libraryfolder.vdf` carries the `contentid` that Steam
matches on, so it travels with the disk.

That nearly makes the step scriptable, and it was deliberately left manual.
`libraryfolders.vdf` only comes into existence once Steam has run and logged
in, and at that moment the user is already in the UI where two clicks do it.
Automating the case that actually matters — the fresh install — would mean
fabricating the entire file before Steam's first start, which cannot be
verified here: the QEMU host has neither a Steam account nor the games disk. An
unverifiable script whose failure silently hides 837 GB is the worse trade
against twenty seconds of clicking.

**The desktop shortcut is manual for a similar timing reason.** Steam creates
`~/Desktop/steam.desktop` during its first run; there is no flag to suppress it
(`registry.vdf` has no such key, and `/usr/bin/steam` does not create the file —
the client does), and both stage 3 and stage 4 run before Steam has ever
started, so neither can delete something that does not exist yet. It joins the
first-launch checklist, which ulu has to walk anyway.

**And the gamepad test point closed, after I got it wrong first.** Measured
with the pad switched off, the ACRUX dongle is a plain HID device called
"Receiver Update" with a root-only hidraw node and no input device at all;
`xpad`'s device table does not contain vendor `1a34` either. On that evidence I
reported that the decision to drop `steam-devices` / `game-devices-udev` did not
hold. Switched on, the dongle re-enumerates entirely: the ACRUX id disappears,
the kernel loads `xpad`, and the pad appears as `Microsoft X-Box 360 pad` on
`event27`/`js1` with a `uaccess` ACL for the session owner. The original
decision was right; I had measured the wrong device state. The measurement
condition is now written next to the test point, because the same trap is set
for whoever checks it next.

Separate finding, harmless until it is not: **`/dev/input/js0` is the ASRock LED
controller.** The board's RGB controller is tagged as a joystick, so the pad is
`js1`, and anything that grabs "the first joystick" gets the motherboard
lighting instead.

## 2026-07-31 — Applications, round 10: LibreOffice, one setting and a verified seeding trick

ulu's own summary was "nicht viel eingestellt", and the file agreed: 116 lines
of `registrymodifications.xcu`, almost all of it window and toolbar state.

Exactly one decision survived the sifting: **the dark appearance**, and
specifically chosen rather than left on "System" — `ApplicationAppearance=2`
with `CurrentColorScheme=COLOR_SCHEME_LIBREOFFICE_DARK` corroborating it. Both
are written, because either alone would be ambiguous. `UseOpenCL=false` is
LibreOffice's own default and stays out; the `welcomedialog` entry only records
which tab was last shown, so it is not the "never show again" flag it looks like.

**The pristine-profile trick failed here, and its failure is instructive.** Run
headless against an empty profile, LibreOffice writes 461 bytes and never draws
a UI — so everything the GUI serialises on first paint shows up as "only in
ulu's profile", defaults included. The same limitation Strawberry set. The
decision had to be identified by reading the values, not by diffing.

**But the seeding question got a real answer, unlike Steam's.** Both
applications have the same timing problem: the config file does not exist until
the program has run once, which is never true at stage 3 time on a fresh
install. For Steam that made automation unverifiable and it stayed manual. Here
it was testable in two minutes — a hand-written minimal `registrymodifications.xcu`
placed before the first start is read and kept, with LibreOffice merging its own
entries in around it (516 → 767 bytes, both values intact). So stage 3 seeds the
profile, guarded on absence: an existing profile is ulu's and gets left alone,
the same shape as the KeePassXC database preselection.

Worth stating because it is a class of decision this repo keeps meeting: the
difference between Steam and LibreOffice was not the risk appetite, it was
whether the claim could be tested on the machine at hand.

Two notes on secrecy, both fine: the file accumulates recently opened documents
with full paths, so it is never captured whole — only the two items are
authored. And its `UserData` node is empty, ulu having never filled in the
user-details page, which is the outcome a public repo wants.

And a process check of mine misfired again: `pgrep -f soffice` matched my own
shell, exactly the trap recorded after the Discord round. `pgrep -x` on the real
process names (`soffice.bin`, `oosplash`) is the check that means something.

## 2026-07-31 — Applications, round 11: mpc-qt, a crash loop and a seeding answer that reversed

ulu tried haruna, dismissed it ("vergiss es"), and mpc-qt stays — which closes
a TODO that had been sitting in `aur.txt` since the package rounds. haruna and
mpvqt came back off the machine so it matches the documented package set again.

Then mpc-qt would not start at all, and the diagnosis is worth keeping.

**The crash.** SIGSEGV in `QScreen::availableGeometry()` straight out of `main`
— a null screen dereference. The first hypothesis was the monitor layout: none
of ulu's four screens covers the point (0,0), so a `screenAt(0,0)` would return
nullptr. Plausible, and wrong. `QT_QPA_PLATFORM=xcb` ran fine while `wayland`
crashed, which looked like a Wayland bug — also wrong. Moving `settings.json`
away made it start under Wayland too, and that was the thread worth pulling.

**The actual condition, reproduced deterministically: `settings.json` present
and `geometry_v2.json` absent.** And it is self-perpetuating — the crashing run
writes `settings.json` and never reaches the geometry file, so it recreates the
state that kills it. Any interrupted first launch produces a player that never
starts again, which is exactly how ulu experienced it. The cure is to delete
`settings.json` once and let a clean run write all six profile files.

Worth being explicit about the false starts: the layout theory and the Wayland
theory were both consistent with the evidence available at the time, and both
would have led somewhere useless. What settled it was removing one file.

**The seeding question came back and answered the other way.** LibreOffice had
just established that pre-writing a config before an application's first run
works — verified. The same question here got the opposite answer, and it had to
be tested rather than assumed: a two-key `settings.json` alone crashes, and so
does one paired with an empty or stub `geometry_v2.json`. The crash wants a real
geometry entry, which would mean writing this desk's window coordinates into the
repo — barred anyway. So seeding mpc-qt would make it unstartable on every fresh
install.

Stage 3 therefore does two things instead: it **repairs** the broken state when
it finds it, and it writes the two settings only into a profile that already
exists, saying so plainly when there is none. The contrast is the lesson —
same question, opposite answers, and only the measurement told them apart.

**The settings themselves** are small: English audio, no subtitles
(`playbackAudioTracks=eng,en`, `playbackSubtitleTracks=none,no`).
`keys_v2.json`, 46 KB of key bindings, is untouched and stays out.

**And the predicted recurrence arrived.** The VRR rule written for Brave now has
its twin for mpc-qt — the second application whose only relevant property is
that it plays video. That is the evidence the finding was never about the
browser.

One process note: `bash -n` validates shell syntax and nothing else. A stray
backslash inside the `jq` filter passed it cleanly and would have failed at
runtime; catching it needed feeding the expression to `jq` itself.

## 2026-07-31 — Applications, round 12: the printer, and a dependency with an expiry date

Samsung SCX-4300 over USB, print only. Set up, scripted and verified end to end
— queue created, test page printed, paper confirmed by ulu. That last step is
not ceremony: splix is a third-party driver for an eighteen-year-old device, and
CUPS reporting a clean filter chain only means the data left the system.

**The split between what is stored and what is resolved wrote itself.** CUPS
builds the device URI as
`usb://Samsung/SCX-4300%20Series?serial=<serial>&interface=1` — it carries the
printer's serial number, which is both a discovered identifier and a hardware
ID, so it stays out of a public repo. The driver string
(`drv:///splix-samsung.drv/scx4300.ppd`) comes from the splix package and is the
same on every machine, so that one is configuration. Stage 3 resolves the device
with `lpinfo -v` at runtime, exactly as it already does for monitors, disks and
pointers.

Three defaults were wrong for this desk and are now written explicitly:
`PageSize` (the driver ships **Letter**), `printer-is-shared` (CUPS shares a new
queue on the network by default, which a single-user desktop has no use for),
and the default destination, which was unset.

**No root required**, which was worth checking rather than assuming: CUPS accepts
administration from the `wheel` group on Arch, so `lpadmin` runs unprivileged
like the rest of stage 3.

**And a warning worth more than the setup.** `lpadmin` says on every call:
*"Printer drivers are deprecated and will stop working in a future version of
CUPS."* CUPS 3 removes PPD-based drivers — which is precisely what splix is —
and a 2007 multifunction device does not speak IPP Everywhere. So this queue has
a known expiry date tied to an Arch package update, and the fallback will be a
local IPP-Everywhere adapter or a print server in front of it.

That is recorded next to the setting rather than buried here, because of the
failure mode it prevents: without it, the repo would say "printer configured,
verified" and the day it stops working would look like a regression in phoinix
rather than an upstream removal that was visible all along.

## 2026-07-31 — Applications, round 13: DZGUI, a deferred dependency and a silent failure

Three findings, and none of them was the settings round.

**The dependency the package rounds deferred, arrived.** DZGUI 7.0.0b20 died at
startup with `Typelib file for namespace 'xlib', version '2.0' not found`.
`gobject-introspection-runtime` provides it and was not installed. `LOG.md` had
recorded DZGUI 7 as "turnkey with bundled runtime, deps deferred to actual
install" — this is that install. The structure is what matters: DZGUI is an
upstream tarball, not a package, so it *cannot* declare dependencies, and its
bundled Python still needs the system typelibs. For everything else in this repo
pacman makes that class of failure impossible; here only the package list can.
Checked before adding, since `kde.txt` rejects GTK on principle: 150 KB, one
dependency, no GTK chain.

**The config moved.** DZGUI 7 uses `~/.config/dzgui/`, not the `~/.config/dztui/`
the package rounds noted. Small, but it is exactly the sort of stale detail that
sends someone looking in the wrong directory.

**Steam integration is broken and fails silently — read out of the source.**
ulu reported that the wizard offered to add DZGUI to Steam and nothing appeared.
There is no `shortcuts.vdf` at all, and the reason is in
`Shortcuts._load_shortcuts()`: it opens the *existing* file for reading, and
Steam only creates it once a non-Steam game has been added by hand. The
resulting exception is caught and merely logged, and the wizard page carries its
author's own comment: *"best-effort, permissive even on failure (page is already
marked as complete)"*. So it reports success, does nothing, and says nothing.
Worth recording as a shape rather than a bug report: a step that cannot fail
visibly is a step that will be believed.

**The settings themselves went to a data disk, at ulu's request — including the
secret.** DZGUI's config holds a Steam Web API key and his server list. Both
must survive a reinstall and neither belongs in a public repo, so both live in
`/mnt/FilesMusic/DZGUI/dzgui-private.json` (0600) and only the path is
versioned. Same anchor pattern as the WireGuard configs and the playlist. Asked
rather than assumed: a DayZ server address is not secret, but it says where he
plays, and that is his call to make about a public repo.

**And seeding pays here more than anywhere so far.** Without a config the first
run demands an API key — a trip to steamcommunity.com and 32 characters typed
after every reinstall. Seeded, the wizard does not run at all. Verified rather
than hoped: the seeded config was accepted unchanged, DZGUI adding not one field
of its own. That makes three applications with three different answers to the
same seeding question — LibreOffice yes, mpc-qt never, DZGUI emphatically yes —
and in every case only the measurement decided it.

## 2026-07-31 — DZGUI, the aftermath: a shortcut backed up rather than rebuilt

Two follow-ups to the DZGUI round, both small and both about the same principle.

**The seeding claim is now observed, not just measured.** ulu confirmed that the
seeded config produced the server browser and no wizard. The measurement (DZGUI
accepted the file unchanged, adding no field) had said so; his eyes settled it.

**And the Steam shortcut he added by hand is backed up, not regenerated.** It
could be generated — the format is a small binary VDF and the only computed part
is a CRC32-derived appid — but that would be self-written machinery replacing
something Steam writes anyway, and it would not touch the real obstacle:
`userdata/<account-id>/config/` exists only after a Steam login, so stage 3 has
nowhere to write on a fresh install regardless.

So the file is copied to the games disk and stage 3 restores it when it can,
with three guards that each cover a way this could go wrong: no `userdata` yet
(say so, wait for the second run), a file already there (leave it — it holds
every non-Steam game added since), and Steam running (refuse, because Steam
rewrites this file on exit and the restore would vanish). All four branches
exercised.

Backing up rather than generating has a second benefit worth naming: whatever
ulu adds later comes along by itself, where a generator would only ever recreate
the one entry that existed the day it was written.

Also cleaned up: `~/.config/haruna/`, left behind when the package was removed.

## 2026-07-31 — Applications, round 14: XIVLauncher and Dalamud

ulu asked the design question first, which turned out to be the right order:
rebuild the Dalamud install, or image it? The sizes answered it. `~/.xlcore` is
~2.7 GB, of which the Proton prefix (954 MB), Dalamud, the .NET runtime, its
assets and Browsingway's embedded browser (623 MB) all re-download themselves.
What does not come back is about 80 MB.

**The character configuration was already solved, by ulu, before I proposed
anything.** `/mnt/Games/FFXIV/ffxivConfig` sits on the games disk and
`GameConfigPath` points at it, so hotbars, macros and UI survive by
construction. My first analysis had planned to carry it — a solution to a
problem his disk layout had already removed. Worth remembering: look at what is
already arranged before designing the arrangement.

**A 4.4 GB backup from February 2025 was on FilesMusic**, and ulu chose to set
up fresh and image afterwards rather than restore it. Right call: its
`installedPlugins` and Dalamud framework were seventeen months old, and stale
plugin binaries against a current game patch is precisely the state where
nothing loads.

**What is carried**, ~80 MB: `launcher.ini`, `accounts.json` (a credential —
account name and last OTP, kept at 0600), `dalamudConfig.json`, `dalamudUI.ini`,
`pluginConfigs/` minus Browsingway's runtime directory, and `installedPlugins/`.
The binaries are carried on ulu's call: `dalamudConfig.json` does hold the full
profile (ten plugins with enabled state) and the three third-party repo URLs, so
in principle Dalamud could reinstall — but that behaviour was never verified and
the repos are outside anyone's control. 79 MB is the cheaper insurance.

**Two things the seeding test found that reading never would.**

First: **`~/.xlcore` is a symlink**, not a directory. XIVLauncher-RB creates it
for compatibility beside the real `~/.local/share/dev.goats.xivlauncher`. The
backup read through it and worked; the restore would have created a plain
directory in its place, shadowing the link with files the launcher never opens.
The backup would have looked perfect and the restore would have been silently
inert. Caught because `du -sh ~/.xlcore` reported 0 while its children were
gigabytes — a symlink's own size.

Second, and smaller: `pluginConfigs/Browsingway/dependencies` is not a cache. It
is the CEF runtime Browsingway *executes from* — its helper processes were seen
running out of that path. Excluding it is still right, because it re-downloads,
but the comment justifying the exclusion was wrong and is fixed.

**Then the test answered its actual question: seeding works.** The live
directory was moved aside, 80 MB restored into an empty one, and XIVLauncher
came up fully configured — account, settings, all ten plugins — and carried
through into the game, Dalamud rebuilding its framework around the restored
config. ulu kept the restored directory and deleted the original.

## 2026-07-31 — Browsingway's first-run failure is a startup race

A long-standing annoyance of ulu's, present on his previous Arch install too:
after entering FFXIV, Browsingway's overlays do not react to cactbot until the
plugin is disabled and re-enabled once. Diagnosed live, while the broken state
was on screen.

Not a graphics fault, though the log invites that reading: Dawn logs
`D3D12CreateDevice failed` and a pair of OpenVR registry warnings, all noise.
The timestamps are the finding:

```
19:43:54.755  Browsingway finished loading
19:43:58.969  IINACT finished loading            (+4 s)
19:43:58.977  OverlayPlugin initialised
19:43:59.830  cactbot event source enabled       (+5 s)
```

Browsingway's inlays load their URLs — Horizoverlay and three cactbot pages,
each carrying `?HOST_PORT=ws://…` — about five seconds before IINACT's websocket
server exists. The connection fails and the pages do not retry indefinitely.
Toggling the plugin reloads them, by which time the server is up.

There is no configuration-level fix: Dalamud does not expose plugin load order,
Browsingway has no start delay, and whether a page retries is cactbot's and
Horizoverlay's business. The lighter workaround than toggling the whole plugin
is the per-overlay reload action in Browsingway's own window.

Recorded because it costs nothing to write and saves the next investigation:
the symptom points at graphics, the cause is ordering.

## 2026-07-31 — Session 4 closed: what the day produced

Two large pieces and a phase finished.

**The install became one command**, and the QEMU loop that `DESIGN.md` had
prescribed since day one was finally run. It found six defects in a chain that
read correctly — the worst being that `bootstrap.sh` did nothing whatsoever
under `curl | bash`, because `exec < /dev/tty` destroys the very stdin bash is
reading the script from. Not one of the six was visible by inspection.

**ProtonVPN became a split tunnel with a kernel-enforced guarantee**, and that
one refuted its own design three times before it worked: `never-default` does
not restrain a WireGuard connection, the drop rule strangled the tunnel's own
encapsulation, and the filter sat in a hook that runs before the reroute. Every
correction came from a counter, never from a re-reading.

**The application phase finished** — thirteen rounds. The pattern that held
throughout: the settings are rarely in the application. Autostart entries, KWin
rules, a desktop icon position, a launcher wrapper — the diffs kept landing
outside the program whose round it was, which is why the method diffs the whole
tree and filters by path prefix rather than by name.

**The seeding question was asked four times and answered differently each
time**, which is the through-line worth keeping: LibreOffice yes (verified),
mpc-qt never (verified — a settings file without a geometry file segfaults),
DZGUI emphatically yes (verified, and it saves retyping a Steam API key after
every reinstall), XIVLauncher yes (verified end to end). Same question, four
measurements, and the measurements disagreed with each other. Nothing about the
applications' similarity predicted the answers.

**Where testing beat reading, concretely:** a jq filter with a stray backslash
that `bash -n` accepts; `kwriteconfig6` reading `-1` as an option; a `pgrep -f`
pattern matching my own shell, twice, after I had written the lesson down; and
`~/.xlcore` turning out to be a symlink, which would have made a
perfect-looking backup restore into a directory the launcher never opens.

**And where asking beat assuming:** the VRR rule looked like a Brave setting
until ulu said mpc-qt does it too, which moved the finding into the display.
The soundbar's −26 dB has this exact shape recorded from an earlier session —
a value captured without its reason nearly being undone by the person it
protected. Every setting scripted today carries why, not just what.

Open at the close: a question ulu wants to work through next, keychron-launcher
as a fresh topic, the `qemu-base`/`edk2-ovmf` package-list decision, the
soundbar level (no longer blocked — DayZ and FFXIV are both installed now), the
144 Hz experiment on DP-1, and MateriaForge for 7th Heaven, which is the last
unfinished item of the mount-path decision.

## 2026-07-31 — No submodules: why phoinix stays one repo

ulu asked whether GitHub can do what GitLab calls a "superproject" with
subprojects — check out the parent, commit in the children and in the parent.
It can: GitLab's superproject is not a GitLab feature, it is plain **git
submodules**, and GitHub handles them identically. The differences are UI.

His idea was to split phoinix into a superproject with `phoinix-script` (what
we have) and `phoinix-fixes` (the fixes developed along the way). Decided
against, for reasons specific to this repo rather than general submodule
grumbling:

- **The install chain would break in a place that must not break.** Stage 1
  rsyncs the repo to `/mnt/root/phoinix/`, stage 2 copies it to
  `/home/<user>/phoinix`. A submodule keeps its real git directory in the
  parent's `.git/modules/<name>` and carries only a `.git` *file* holding an
  ABSOLUTE path to it. After the copy into the home directory that path still
  points at `/root/phoinix/...`, so the working repo — the one we hold sessions
  in — would have dead submodules. Fixable, but it is new machinery on the
  critical path, and `scripts/bootstrap.sh` would additionally need
  `--recurse-submodules` or the one-command install stops working.
- **The split does not follow the code.** Five of six scripts in `scripts/`
  source `config.sh` and `hosts/<host>/config.sh`; only `qemu-mon.sh` stands
  alone. They are limbs of the installer, not a separable collection.
- **The rationale is the artifact.** `docs/` is 3614 lines, larger than every
  script in the repo combined, and LOG.md references across all of it. The
  mpc-qt fix is fifteen lines of code and one hard-won insight; separating them
  keeps the cheap half.
- **One copy or it rots.** If the stages call the fix scripts instead of
  duplicating them, the installer is their test harness and a broken fix shows
  up in the next QEMU run. Two repos give you a published copy nobody tests.

ulu's actual requirement, stated after the first answer, was publication plus
reachability after a distro-hop: curl one script and be done. That does not
argue for submodules at all — curling a single file needs a stable raw URL and
a dependency-free script, and the repo layout is irrelevant to both.

Parked at ulu's request, not built. The agreed shape is recorded in STATUS.md
under "Later, with ulu". If it ever outgrows a directory it can move out with
`git filter-repo` and keep its history; merging back a premature split is the
harder direction, which is why the directory comes first.

## 2026-07-31 — keychron-launcher: it was never the keyboard, it was udev

Symptom: on launcher.keychron.com in Brave, pressing connect did nothing at all
for both the Q6 Max (3434:0861) and the M6 8K (3434:d049). ulu had a
`50-qmk.rules` lying on the data disk because "you usually have to fiddle with
udev rules" — so the suspicion was in the right area, but the file was not.

Measured before touching anything:

- `/etc/udev/rules.d/` was **empty**. The rule had never been installed on this
  system at all.
- Consequently every `/dev/hidraw*` was `crw------- root:root`. Brave runs as
  ulu and cannot open any of them. WebHID does not surface that as an error —
  the device picker just comes up EMPTY, which is precisely "nothing happens".

The data-disk file would not have fixed it either. It contains **no Keychron id**
(`3434`: zero hits) because it is qmk_firmware's *bootloader* rule set, for the
id a board takes on while being flashed. The only line that would have applied
was line 71, `KERNEL=="hidraw*", MODE="0660", GROUP="plugdev"` — a catch-all
over every hidraw device on the machine (ASRock LED controller, Focusrite, USB
audio, the Microsoft receiver) that also names a group Arch does not have.

Decided: keep the 32 upstream bootloader rules — ulu **does** update firmware,
and only they cover the bootloader ids. Drop line 71. Add one rule of our own,
by vendor, for the launcher. Both files go in the repo under `system/udev/`,
split by provenance, installed by stage 2. The data-disk copy was only ever
there because there was nowhere else; a udev rule is a setting, not a secret.

**The lesson is in how I got it wrong, not in the fix.** My first handover
chained the install with `&&` and ended in
`udevadm trigger …; getfacl … 2>/dev/null | grep`. Two mistakes compounded:
`2>/dev/null | grep` swallowed the very error that would have explained the
empty output, and — the real one — **`udevadm trigger` only QUEUES events and
returns immediately**. The `getfacl` ran before udevd had executed the uaccess
builtin, so I reported the rule as not working while it already was. Minutes
later all four Keychron nodes carried `user:ulutoyon:rw-`, and ulu confirmed
the launcher had been working the whole time.

This is the same failure as the soundbar and the FIFO: a measurement taken
under the wrong condition, reported as a finding. Any check after
`udevadm trigger` needs `udevadm settle` first — the counters do not settle
just because the command returned.

Left unexplained honestly: `install` reported exit 1 on the second file while
writing it correctly. Both files in `/etc` are byte-identical to the repo
(sha256 verified) with `-rw-r--r-- root:root`, so the outcome is right; the
exit code is not understood and is not being papered over.

## 2026-07-31 — Monitor switching: one icon instead of two scripts

ulu has three monitors wired to both this machine and the Fedora laptop, and
switched them with two hand-written scripts on a data disk. `SwitchToDesktop.sh`
was deleted with that folder (deliberately, on his word); `SwitchToLaptop.sh` he
had moved one directory up, which is why it appeared to vanish mid-inspection —
the disk was fine and my alarm about it was wrong.

Both scripts addressed the monitors by i2c bus number, and the numbers HAD
ALREADY DRIFTED: the desktop-side script carried a commented-out `--bus 8`
directly above its replacement `--bus 10`, i.e. ulu had renumbered it by hand
after a reboot moved things. That is exactly the discovered-identifier trap
CLAUDE.md exists to prevent. `ddcutil detect` gives a stable handle instead:

    bus 9  DP-1  TCL:34R83Q:X2412000442
    bus 10 DP-2  TCL:27R83U:X2414000091
    bus 11 DP-3  ACR:XZ322QU V3:14110A5B13W01
    bus 7  HDMI  HEC:HISENSE:  — "Invalid display", no DDC/CI

So selection is by MODEL now, which comes from the EDID and travels with the
panel. Verified that `--model` works for all three, including the Acer whose
model string contains a space.

**Decided: a toggle, not two scripts.** The reference monitor is asked what it
is showing and everything moves to the other side. One icon does both jobs, and
there is no state file that can disagree with the hardware. ulu's counterpart
script on the Fedora laptop is what brings the monitors back, so in practice
this side almost always runs one way — noted at the time, built anyway because
it is self-correcting and costs nothing.

**Why a reference monitor rather than asking each panel:** the two TCLs report
input source 0x07 whatever is written to them, and their own capabilities list
advertises only 0x0f/0x10/0x11/0x12 — it does not contain 6 or 8, the values
that demonstrably switch them. They can be DRIVEN but not BELIEVED. The Acer is
standards-conformant (0x0f DisplayPort-1, 0x11 HDMI-1), so it decides for all
three. The 6 and 8 stay in the host config as bare measured numbers with a
warning not to "correct" them to the advertised codes.

Tested without touching the monitors, by shimming `ddcutil` on PATH so `setvcp`
was logged and `getvcp` went to the real hardware. All three cases came out
right, and the toggle reproduces BOTH original scripts exactly:

    reference reads 0x0f (desktop) -> 8, 8, 17   = ulu's SwitchToLaptop.sh
    reference reads 0x11 (laptop)  -> 6, 6, 15   = the deleted SwitchToDesktop.sh
    reference reads 0x07 (unclear) -> to laptop

The ambiguous case going to the laptop is deliberate: this is triggered from a
desktop icon, so whoever clicked it is sitting at the desktop, and "I could not
tell" should still do what they asked.

`ddcutil` went into `packages/cli.txt` — it was missing entirely, so a fresh
install had neither the tool nor the script. It needs nothing else from us: the
package ships `modules-load.d/ddcutil.conf` for i2c-dev and a udev rule that
tags the graphics i2c devices with `uaccess`. That is the second time today the
answer was uaccess rather than a group.

**Stage 4 generalised from one desktop icon to a list.** `DESKTOP_ICON_CELL`
became `DESKTOP_ICONS=("<basename>.desktop:col,row" …)`. Two findings there:

- The `positions` value is `{res:[a, b, url, col, row, url, col, row, …]}`, and
  what the two LEADING values mean is not understood. Stage 4 hardcoded "2","31";
  ulu's hand-arranged desktop carries "5","31". Since Plasma writes them itself
  they are now CARRIED OVER from whatever exists for that resolution, and only
  invented when there is nothing to carry. Verified against his live file.
- The icon cell was going to be my invention (1,2) until his running config was
  read: he had put it at 4,3. Captured reality beats an authored guess, so 4,3
  it is.

## 2026-07-31 — Correction: the monitor switch worked on the first run

The entry above ends with the toggle verified only through a shimmed `ddcutil`.
It was then run for real, and I reported it as having done nothing: the Acer
still answered 0x0f, every connector was still `connected`, every display still
answered over DDC. On that basis I called it "wirkungslos verpufft" and started
taking it apart.

Wrong. ulu: "alle 3 monitore hatten sauber umgeschaltet." All three switched,
he saw it happen, and he had already sent them back from the laptop before I
took my reading. I measured a state he had since changed and reported the
difference as a defect.

**Third time today.** The soundbar was measured with the dongle switched off,
the Keychron ACL was read before `udevadm trigger` had processed its queue, and
this was read after ulu had undone it. Same shape every time: a measurement
whose CONDITION was not established, reported as a finding. The rule that comes
out of it is not "measure again" but: before reporting that something did not
work, state what the condition was at the moment of measuring — and if a human
is operating the same hardware, the condition includes what they just did.

The damage was self-inflicted and small: the exploratory `setvcp` calls left the
Acer sitting on HDMI-1 until ulu put it back. Nothing else was touched.

Two things changed as a result:

- `scripts/monitor-switch.sh` no longer writes `setvcp … >/dev/null 2>&1`.
  stderr is captured and printed when the call fails. That redirect is what had
  made the run silent in the first place, and it is the same mistake as the
  `getfacl … 2>/dev/null | grep` in the Keychron handover a few hours earlier.
  Worth knowing while reading that code: ddcutil VERIFIES by default (`--verify`
  is the default, `--noverify` disables it), so a non-zero exit really does mean
  the value did not stick.
- `SwitchToLaptop.sh` is gone, from the desktop and from the data disk. Its
  three values live on in `MONITOR_SWITCH` in the host config, which is now the
  only place they exist.

Left alone deliberately: Plasma's `positions` still names `desktop:/SwitchToLaptop.sh`
for this resolution. Rewriting it means stopping and starting plasmashell in the
middle of ulu's session, and stage 4 writes the whole list correctly on the next
run anyway.

## 2026-07-31 — Mirrorlist, umu-launcher, and two things dropped

Four small decisions from ulu, in one breath: drop the QEMU run, drop the work
to make the harness unattended, do the mirrorlist, move umu-launcher.

**Mirrorlist.** The repo had never touched `/etc/pacman.d/mirrorlist` — every
install simply took whatever ordering the ISO happened to ship. That worked, but
by luck rather than by decision. `reflector` now runs in stage 1, and the
POSITION is the point: it runs BEFORE pacstrap, because pacstrap copies the
ISO's mirrorlist into the target. One sort pays twice — for the ~1 GB pacstrap
pulls and for everything stage 3 installs afterwards.

Guarded rather than assumed, on both ends. `command -v reflector` first, because
a download-speed optimisation must never be the reason an install aborts; and a
failed run falls back to the ISO's list with a warning instead of `set -e`
killing the install. `MIRROR_COUNTRY="Germany"` lives in `config.sh` — a
location fact, and the same for both of ulu's machines.

Verified what could be verified from here: `reflector` is not installed on this
desktop, so the command itself was NOT run. What was checked is the one thing
that would silently produce an empty list — the country name — against the same
source reflector reads: archlinux.org's mirror status JSON has "Germany" and 58
active https mirrors, so `--latest 20` has room. `reflector` also went into
`packages/cli.txt` for re-sorting by hand later; its timer is deliberately NOT
enabled, since an unattended weekly re-sort can pick worse mirrors and a
reinstall regenerates the list anyway.

**umu-launcher** moved from `aur.txt` to `gaming.txt`: it ships in [multilib]
now (1.4.4-1), so building it through paru was pure waste. Found while checking
every package name in every list against the repos after ulu asked for
"kconnect" — which does not exist either; the package is `kdeconnect`. All other
names are valid, and the eight that pacman cannot see are exactly the AUR ones.

**Dropped: the QEMU run and the pty work.** ulu's call, after the harness
refused to be driven from a background session. The consequence is recorded in
STATUS rather than buried here: stage 4's multi-icon `positions` JSON has never
been written by the script, only computed and compared against his running
Plasma. It is the single piece of today with no proof behind it, and it is the
first place to look if desktop icons come back in the wrong cells.

## 2026-07-31 — The soundbar is back at −26 dB

ulu: "soundbar zurück." Of the two options recorded in STATUS he took the first
— restore the value the recovered transcripts document as tested, rather than
probe upward to find where the glitching starts.

Measured before touching anything: the live sink read −23.23 dB on all six
channels, and the live wireplumber state matched the repo copy byte for byte on
`default-routes`, `default-nodes` and `default-profile`. So there was no
uncaptured drift to destroy, and the 2.77 dB gap was exactly as documented.

**`pactl set-sink-volume SINK -26dB` does not do what it looks like.** The
leading minus is read as a RELATIVE decrement: −23.23 − 26 = **−49.23 dB**, which
is where the soundbar briefly went. `--` does not rescue it either — unlike
`kwriteconfig6` earlier today, pactl answers "Invalid volume specification". The
absolute route is the raw PulseAudio value, because PA's scale is CUBIC while
`channelVolumes` is linear amplitude:

    raw = 65536 × (10^(dB/20))^(1/3) = 65536 × 0.050119^(1/3) = 24163

That produced −26.00 dB on all six channels, and wireplumber then persisted
`channelVolumes: [0.050120, …]` on its own — **exactly** the figure the old
transcripts carry, not a rounding neighbour of it. That exactness is the useful
part: it says the transcripts' number and this machine's number are the same
quantity, so the restored state really is the tested state.

Captured into `hosts/desktop/home/.local/state/wireplumber/default-routes`.
Checked that nothing else rode along: of the five devices with a stored volume
in that file, only the Teufel entry differs from the committed version. The key
ORDER inside the JSON object also shuffled — wireplumber writes its keys in no
fixed order, which is worth knowing before anyone reads a whole-file diff of
this thing as meaningful.

What this does NOT establish: that the glitching is gone. −26 dB is the level
that was tested glitch-free years ago, and restoring it removes the most likely
explanation for ulu's lingering doubt — but confirming it needs hours in FFXIV
or DayZ, and only he can report that. If it still glitches at −26 dB, the level
was never the cause and the hunt reopens elsewhere.

## 2026-07-31 — chezmoi rejected, and a drift check instead

The chezmoi question had been open since the first sessions. `DESIGN.md` chose
it over stow for one reason: templating, to handle differing usernames across
machines. That reason was checked rather than taken on trust, and it is gone:

- `dotfiles/p10k.zsh` — **no** machine-specific value at all. Its two matches on
  a username are comments about `asdf` inside the generated file.
- `dotfiles/zshrc` — exactly one, `zstyle :compinstall filename
  '/home/ulutoyon/.zshrc'`, a cosmetic leftover from `zsh-newuser-install`.
- And ulu settled the rest: "der laptop wird nie dieses skript hier ausführen,
  maximal überwachend bei einer installation involviert sein." There is no
  second machine to template for, so the feature has no subject.

Rejected, then. Adopting it anyway would have meant a SECOND mechanism for
getting configuration onto a machine next to stage 3 — two answers to one
question — and it would have to be installed and initialised before doing
anything, in a repo whose entire premise is that one command does everything. It
would also have owned two files while stage 3 owns forty-odd `kwriteconfig6`
settings and a captured tree.

**What chezmoi would genuinely have given us is `chezmoi diff`:** noticing when
a captured file and the live one stop agreeing. That is worth having on its own
merits, because this repo has already lost that bet once — the soundbar sat
2.77 dB from its documented value for months, and nothing said so until the old
transcripts were dug up by hand. So the benefit was taken without the framework:
`scripts/check-drift.sh`.

It walks `hosts/<host>/home/` rather than carrying a list, so a file added there
is covered without anyone remembering to update the checker. Two special cases,
both stated in output instead of hidden:

- `.zshrc` legitimately differs by the alias hook stage 3 appends, so the hook
  is stripped before comparing. Without that it would report drift on every
  machine phoinix has ever touched, i.e. always, which is the same as never.
- `stream-properties` is per-application wireplumber state and grows with every
  app that has played a sound. It is reported as "expected to differ" rather
  than skipped — a check that hides things is worse than one that explains them.

**It found real drift on its first run.** `~/.config/kdeglobals` carried
`Breadcrumb Navigation=false` under `[KFileDialog Settings]` while the repo
still had `true` from whenever the file was captured. Nothing in `docs/` ever
mentioned the setting, so the repo's value was never a decision — just the state
of a moment. The live value was captured. Nine files in sync afterwards, exit 0.

One bug of my own, caught by reading the output instead of trusting it: the
summary line printed "0 drifted" while listing a drifted file, because it
counted the wrong variable. A checker that miscounts is worse than no checker.

## 2026-07-31 — The reinstall handoff, and a bug ulu's correction exposed

ulu is about to run the installer on the real desktop. First he described the
plan as driving it over SSH from the laptop, then corrected it: "wir werden die
installation NICHT per ssh machen. ich werde alles händisch am desktop
eintippen. der laptop wird nur per ssh verbunden um fehler zu diagnostizieren."

That correction found a real defect. The `.zprofile` hook stage 2 writes ran

    if flock -n "$HOME/.local/state/phoinix/stage3.lock" stage3.sh "$HOST"; then

and `flock -n` returns non-zero for **two different things**: the lock is held by
someone else, or the command ran and failed. The `else` branch said
">> Stage 3 failed. Log: ~/stage3.log". So the exact setup ulu just described —
stage 3 running from the console login, a diagnostic ssh session opened
alongside it — would greet him with "Stage 3 failed" at a completely healthy
install. He would then be debugging the message rather than the install.

Fixed with `flock -n -E 99`, which sets the exit code used for a lock conflict.
Verified rather than assumed, and the first attempt at verifying was wrong:
`flock -n -E 99 "$T" command true` makes flock try to execute a program called
`command`, so all three cases returned 69 ("failed to execute"). With real
binaries the three are cleanly separable:

    lock held by another    -> 99
    lock free, command fails -> 1
    lock free, command ok    -> 0

The generated `.zprofile` was then syntax-checked with **zsh**, not bash — it is
read by ulu's login shell, and `bash -n` would have been the wrong instrument.

`docs/REINSTALL.md` is the handoff itself. The part worth keeping regardless of
this particular run is section 0: stage 1 partitions the disk holding `/home`,
and two things there are covered by nothing else. `~/.ssh/id_ed25519` is not in
the repo and must never be. `~/.claude` holds the session transcripts, whose
existing backup predated the last two sessions — and this repo has already had
to mine those transcripts once, to recover why the soundbar runs at −26 dB.
Both were copied to `/mnt/Downloads/rescue/` before the reboot.

Also recorded there, because both would otherwise be discovered at the worst
moment: archiso's root has no password and sshd refuses an empty one, so the
diagnostic channel does not exist until `passwd` is typed at the machine; and a
login as ulutoyon after stage 2 starts stage 3 on its own, console or ssh alike,
because `.zprofile` fires on any login shell.

Pre-flight checks before the run, all passing: target `nvme1n1` is a different
device from all four data disks, `check-drift.sh` reports 10 in sync, and every
restore source (xlcore backup, Steam shortcuts, DZGUI secrets, both WireGuard
configs, the playlist, the KeePass database) exists and is current. The repo's
`authorized_keys` differs from the live one only in the comment field — the
sanitised `ulu@laptop` against what ssh-keygen wrote — while the key material
hashes identically, so ssh access survives the reinstall. That check is now part
of `check-drift.sh`, which had been blind to the file.

## 2026-07-31 — mpc-qt becomes mpc-qt-bin, decided mid-install

ulu called it during the first real run, watching the AUR phase: the mpc-qt
source build (CMake, Qt, a full C++ compile) is the slow spot of stage 3, and
the painless parts of the same phase — brave-bin, proton-ge-custom-bin — had
just demonstrated what -bin feels like. "das compilen nervt."

Checked before switching, not after:

- **Version parity:** mpc-qt 26.07-1 and mpc-qt-bin 26.07-1, neither flagged
  out of date. The -bin package repackages the upstream release AppImage, so it
  tracks the same source, not a fork.
- **Path dependencies:** the -bin PKGBUILD RENAMES the desktop file from
  `io.github.mpc_qt.mpc-qt.desktop` to `mpc-qt.desktop`. A repo-wide grep found
  exactly one consumer of those names: stage 4's KWin window rule, whose
  `wmclass` line already matches both spellings. The config dir
  (`~/.config/mpc-qt`) belongs to the binary, which is unchanged — the segfault
  note in aur.txt (settings.json without geometry_v2.json) therefore stays.
- `provides=(mpc-qt)` + `conflicts=(mpc-qt)` in the -bin package make the swap
  clean on an installed system too; on a fresh run only the list entry matters.

One thing this buys beyond speed: the AUR provider prompt for mpc-qt (three
providers, stage 3 waits on a keypress) disappears — the list now names the
exact package.

## 2026-07-31 — Run 1 dies at resolv.conf: the line that can never work in a chroot

The first supervised run stopped right after the password prompt. Stage 2's
`ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf` cannot succeed
under arch-chroot: the chroot bind-mounts the ISO's /run wholesale AND its
resolv.conf over the target's, so ln sees source and destination as one file
and refuses — and a mountpoint cannot be unlinked anyway. `set -e` ended the
stage there; everything after (services, bootctl, loader entries) was missing,
which would have meant a system that boots into nothing.

Two fixes were tried ON the machine before committing one. Reaching the real
file through a second bind mount of `/` fails: the resolv.conf child mount
comes along (mount propagation) and ln hits EBUSY all the same — and the
aborted attempt left a stray mount that had to be cleaned by hand. The simple
route works: `umount /etc/resolv.conf` first, then link. arch-chroot's
teardown tolerates the missing mount (prints "not mounted", exits 0 —
verified), and nothing after that point in stage 2 needs the network.

Why QEMU's PASS never caught it: the line sits in the VPN block, and only the
desktop declares a VPN. The E2E test exercised a path the real host never
takes.

## 2026-07-31 — Run 2 dies silently in the printer block: enable is not start

Stage 3 stopped after the Steam line with no error at all — the log just
ends. The printer section probes `lpinfo -v` before section 10 has enabled
cups, and enable would not have helped: it is not start. Against a dead CUPS
scheduler lpinfo exits non-zero; `pipefail` turns the probe pipeline into a
fatal assignment, `set -e` ends the stage, and `2>/dev/null` swallows the
only evidence. The old system never hit it (CUPS was already running when
stage 3 ran there) and QEMU declares no printer.

The block promised "loud, not fatal" and did the opposite. Fixed twice over:
cups.service is started if inactive before the probe, and the probe carries
`|| true` so a failing lpinfo lands in the existing warning path.

Found because ulu asked whether the reboot needed to be manual — checking
the answer exposed that the marker was missing and the log too short. A
lock oddity from the same investigation, worth keeping: the .NET build
daemons (MSBuild nodeReuse, VBCSCompiler) inherit stage 3's flock fd and
outlive it by ~15 minutes, so a relogin inside that window reports "already
running" against a stage that is long dead. pkill's -f pattern matching its
own SSH command line is the second trap in that cleanup.

## 2026-07-31 — Run 3 stops at the very last step: a reading tail holds /mnt

Stages 1 and 2 perfect, and then `umount -R /mnt` fails "target is busy". The
holder was the LAPTOP's diagnostic watcher: a `tail -F` on
`/mnt/var/log/stage2.log`. Read access, one open file descriptor — enough.
The supervision channel broke the run it was supervising, which is exactly
what REINSTALL.md's "the laptop never drives" rule was written to prevent; it
just never occurred to anyone that watching counts as driving.

`umount -R` works depth-first, so the children (boot, home, the four data
disks) were already unmounted; only /mnt itself was held. Verified before
recovering: loader entries present on the ESP, resolv.conf symlink correct —
stage 2 was complete, the run lacked literally only umount + reboot.

Consequences: bootstrap retries the umount and, if still busy, prints
`fuser -vm /mnt` and the two-command recovery instead of a bare error.
REINSTALL.md now says: under /mnt, `cat`, never `tail -f` — the logs on the
booted system (~/stage3.log, ~/stage4.log) are safe to tail because no
unmount follows them.

## 2026-07-31 — The identity leak, laptop edition

The resolv.conf fix was committed on the laptop and went to GitHub with the
real name. Repo-local user.name/user.email were set correctly and were
OVERRIDDEN: the laptop's shell profile exports GIT_AUTHOR_NAME,
GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL — and environment
beats every config level. This is a THIRD leak path next to the two the rule
already knew (global config, hand-typed identity). Small mercy: the exported
email carries a typo (missing @), so the real datum leaked was the name.

Amended and force-pushed within ~2 minutes; the pushed history is clean
(verified across all of origin/main). Residue: GitHub keeps orphaned commits
reachable by hash for a while and recorded the push event. Last time the
answer was re-creating the repository; whether ~2 minutes of a name (no
valid email) warrants that again is ulu's call, still open. Also open: a
durable guard on the laptop — until then, every laptop commit sets the four
variables inline, which is exactly the kind of by-hand discipline that
failed the last two times.

## 2026-07-31 — Stage 4's icon positioning cannot work on a virgin install

The one piece STATUS flagged as never script-verified failed its first real
test, and the diagnosis is structural, not a typo: stage 4 finds the Folder
View containment by `lastResolution`, and Plasma writes that key only once
icons have been arranged by hand. On a fresh install there is nothing to
find — verified live: four folder containments, zero lastResolution keys.
The old system had the key because ulu had arranged icons there years ago.
Re-running the installer can never fix this; the matcher has to change
(`lastScreen` + activity is the candidate — stage 4 already resolves
connector→screen for the panels).

Everything else in stage 4's log succeeded: launchers, the 7 TV widgets,
both side strips, Kickoff favourites, window rules, playlist import. ulu's
"sieht schlecht aus" is not yet mapped to specifics — that question is asked
and unanswered, and the next session starts there.

## 2026-07-31 — FFXIV opens on the wrong monitor: a borrowed window class

ulu reported FFXIV starting on the wrong screen, and the first diagnosis was
wrong in an instructive way. `FFXIV.cfg` survived the reinstall intact — it
lives on the games disk, `GameConfigPath` points there, and its display block
is character-identical to `FFXIV.cfg.old`. So the game's own configuration was
never the problem.

**Which monitor is "the TCL" was itself ambiguous, and the repo caused it.**
ulu asked for borderless on "my TCL 34\"", while `config.sh` called DP-2 the
"TCL 4K" and DP-1 merely "ultrawide". The EDIDs settle it: DP-1 is a TCL
34R83Q (797x333 mm, 34"), DP-2 a TCL 27R83U (597x336 mm, 27") — **both are
TCLs**, which is exactly why the shorthand was dangerous. DP-3 is an Acer
XZ322QU, HDMI-A-1 a Hisense. The connector comments now carry model names.

**The Wayland toggle moves the ground under the whole question.** With
`WaylandEnabled=true` a Wayland-native client cannot position itself and
neither `ScreenLeft` nor any KWin position rule is the deciding factor — the
compositor places it. ulu had switched the launcher to `WaylandEnabled=false`
between two messages, so the game now runs over XWayland, where placement
rules work normally. Recorded because the failure mode is silent: flip that
toggle back and the rule below stops doing anything, with no error anywhere.

**The finding worth keeping: the window class is not the game's.**

    WM_CLASS = "steam_app_default", "steam_app_default"

umu/Proton labels every non-Steam title it launches this way, because no Steam
AppID is set. A class-only rule would therefore also catch DayZ under DZGUI
and drag it onto the ultrawide. The rule matches on the **title** as well
(`FINAL FANTASY XIV`), which is the only field separating them — a
language-independent string the game sets itself. If it ever stops matching
after a patch, that is where to look.

Its size comes from `connector_geometry()` rather than a `*_SIZE` variable:
borderless means exactly one monitor's resolution, so hardcoding 3440x1440
would only create a second place to forget. `FFXIV_CONNECTOR="DP-1"` is the
whole per-machine part. Verified by ulu on the running system.

## 2026-07-31 — gamemode for FFXIV was two-thirds done already

The wishlist entry asked for `gamemode` in the package lists and for a hook to
make XIVLauncher invoke it. Both premises were wrong on inspection: the
packages were installed AND already in `packages/gaming.txt`, and no wrapper is
needed because the launcher has its own toggle. ulu set `GameModeEnabled=true`
himself.

The one real task was capture, and it is the kind that is easy to miss: stage 3
restores `launcher.ini` from `XLCORE_BACKUP_DIR` on the games disk, so a change
made in the live launcher is invisible to a reinstall until
`scripts/xlcore-backup.sh desktop` has run. It has; the backup now carries both
`GameModeEnabled=true` and `WaylandEnabled=false`. The rule this generalises to:
**anything under `~/.local/share/dev.goats.xivlauncher` is only as durable as
the last backup run.**

## 2026-07-31 — qBittorrent would not start at all: `sg` no longer exists

Two of ulu's complaints after the first real install ("qBittorrent starts not
at all", "no autostart") were one defect: the panel launcher and the autostart
entry both point at `scripts/qbittorrent-vpn.sh`, and that script ended in

    exec sg "$VPN_GROUP" -c "$cmd"

**`sg` is gone from Arch.** shadow no longer ships it; util-linux, which took
`newgrp` over, never did; nothing else provides it. So the wrapper died with
`exec: sg: not found` — a line that had been correct when written and was
invalidated by a packaging change, with nothing in the repo to notice.

The first suspicion was wrong and is recorded so nobody re-runs it: the
WireGuard configuration is NOT missing on a fresh install. `/etc/wireguard/`
being empty is by design — stage 3 imports Proton's configs from
`VPN_CONFIG_DIR` into NetworkManager with `nmcli`, and the live tunnel is the
NM connection `protonvpnCH-CH-919`. That part of the install worked.

**One thing went right by construction:** it failed CLOSED. A missing switch
meant no qBittorrent, not an unprotected qBittorrent — which is what the two
guards at the top of the wrapper exist for.

**The replacement is `newgrp`**, setuid root and part of util-linux. It takes no
command argument, so the command arrives on stdin. The interesting part is what
does NOT: the file arguments from `%U` would have to be quoted for the login
shell — zsh here, not sh — and a torrent path containing a quote is exactly how
that becomes a second argument or an executed command. They travel in the
environment instead, NUL-separated and base64'd; `newgrp` was measured to pass
the environment through byte for byte, special characters included. Only the
script's own path and the host name are interpolated, both `%q`-quoted.

**And the wrapper now VERIFIES the switch instead of trusting it.** Everything
before that line only checks that the machinery is present; a single comparison
of the effective gid against the group's establishes that it worked. This is
the case that matters: a half-working switch fails OPEN — qBittorrent running,
looking configured, past a kernel rule that matches nothing.

Verified end to end on the live system: qBittorrent runs with `Gid: 967` in all
four fields, ordinary traffic leaves over ulu's own line, and traffic inside the
group exits at a Proton address in the same /24 as the peer endpoint.

## 2026-07-31 — the playlist import reported success and did nothing

ulu noticed his playlist was missing after the first real install. Stage 4's
journal from that login says the opposite:

    playlist: imported /mnt/FilesMusic/Musik/Default.m3u as 'Default'

The database said otherwise: one empty "Playlist 1", no "Default", zero
`playlist_items`, zero songs in the collection. The `.m3u` on the music disk
was untouched, 321 lines.

**Cause: `strawberry --create` is an IPC message to a RUNNING instance.** With
no instance there it is dropped — and exits 0 regardless. Stage 4 runs at the
first graphical login, when Strawberry has never started, so the one moment the
import actually matters is the one moment it cannot work. Measured both ways:
the identical command with Strawberry running produced the playlist with 160
tracks within seconds.

**The deeper defect is the success message, not the import.** The line hung on
`&&` against an exit code that carries no information about the outcome. This
is the second instance of the same mistake found in one evening — the
qBittorrent wrapper checked that its machinery was *present* and not that it
*worked* — and it is the more expensive of the two, because it printed a
confirmation. A silent failure gets investigated; a false success does not.

Stage 4 now: starts Strawberry itself if no process is running, imports, then
polls the database and reports the actual track count, warning loudly when the
playlist is absent or empty. The start uses `systemd-run --user --scope` rather
than `strawberry &` — this stage is a `Type=oneshot` unit, so anything left in
its cgroup is killed the moment ExecStart returns, and a plain background job
would die with the stage, possibly before writing anything.

Not a bug and worth separating: the collection is empty (`songs = 0`) because
adding the music folder is a documented manual step. The playlist holds file
paths and does not depend on it.

## 2026-07-31 — desktop icons: matching the containment by screen, not resolution

The stopper from the first real install is fixed. Stage 4 located the Folder
View containment by `lastResolution`, a key Plasma writes only after icons have
been arranged by hand — so a virgin install has none, the stage warned and
skipped, and no amount of re-running could ever have helped. It had worked on
the old system purely because ulu had arranged those icons years earlier.

**The replacement matches on `lastScreen`,** which Plasma writes from the
start. That key holds Plasma's own screen NUMBER, assigned in detection order,
which this repo must not store — so it is resolved at runtime by asking the
running shell which of its screens carries the geometry of
`PANEL_MAIN_CONNECTOR`, the same trick `panels.js` already uses for panels.
Measured on the live system: DP-1 is Plasma screen 0, and the matcher returns
containment 1. The old matcher returns nothing on the same machine.

**The activity is part of the match.** A second activity gets its own folder
containment on the same screen — same plugin, same `lastScreen` — so matching
without it would be a coin flip the day one is added.

Applied to the live desktop, and Plasma's reaction is worth recording: after
the restart it rewrote `positions` itself, kept both icons on their requested
cells, replaced our leading value `2` with `5`, and added `steam.desktop` at
0,0 on its own. That confirms the guess in the code comment — those two leading
numbers are Plasma's bookkeeping, not ours, which is why carrying them over
rather than inventing them is the right call.

Still unverified by construction: the case this fixes is a FRESH install, and
this machine is not one. What was verified is that the matcher finds the right
containment where the old one found none, and that the write survives a
plasmashell restart.

## 2026-08-01 — the defence against the name leak was not installed at all

Found while making this session's commits: `git var GIT_AUTHOR_IDENT` on the
freshly installed desktop answered **"Author identity unknown"**. No local
identity, no global one — nothing. `CLAUDE.md` and `STATUS.md` both describe
the repo-local `uluToyon` + GitHub noreply address as the standing protection
against ulu's real name reaching GitHub, and on the machine rebuilt by this
installer that protection did not exist.

**Why, precisely:** the identity lives in `.git/config`, which is not
versioned. `bootstrap.sh` does a fresh `git clone`, stage 1 rsyncs the tree,
stage 2 copies it to `~/phoinix` with `cp -a` — that copy WOULD have carried a
local identity, but there was never one to carry. It had been set by hand on
the old install years of commits ago, and no script ever knew about it.

Fixed by making it a setting like any other: `GIT_IDENTITY_NAME` and
`GIT_IDENTITY_EMAIL` in the repo-wide `config.sh` (the identity belongs to the
person, not the machine), written repo-locally by stage 3 — early, before
anything else in that stage can fail, and re-runnable, unlike stage 2's
one-shot copy step.

The noreply address in the repo is not a secret. It appears in every commit of
this public repository; it is the substitute for a secret.

**Two warnings ship with it, one per leak this repo has actually suffered.**
A global git identity is reported loudly (that is how 35 commits acquired the
real name), and so is `GIT_AUTHOR_*`/`GIT_COMMITTER_*` in the environment (the
laptop case, where a shell profile overrode the repo-local setting). Warnings,
not aborts: both states can be legitimate on a machine not dedicated to
phoinix, but neither may pass unnoticed, because both override or pre-empt the
setting stage 3 just made.

All three paths were tested. The global-identity branch was exercised against a
throwaway `HOME`, because creating a real global identity to test it is the
exact thing the repo forbids — the live system still has no `~/.gitconfig`.

## 2026-08-01 — NumLock at the login screen, and who actually switches it

Asked for by ulu right before the reinstall run: the numeric keypad should be
live at the greeter, not only after login. NumLock was already set — but only
in ulu's own `kcminputrc` (stage 3, section 6), a file the login screen never
reads. It runs as its own user with its own config directory.

**The instance that flips it is KWin, not the login manager.** Checked rather
than assumed, because plasma-login-manager looked like the obvious address:
it ships no config file at all on this system (no `/etc/plasmalogin.conf`,
none in the package's file list), while `libkwin.so` exports
`KWin::Xkb::setNumLockConfig()` and carries the string `NumLock` — the config
it reads is `kcminputrc`, group `Keyboard`. The greeter starts its own
`plasma-login-kwin_wayland`, so the same key in the greeter's home does it.
This is the same shape as the monitor fix: the greeter is a mini-Plasma, and
what configures Plasma configures it.

**Written with `kwriteconfig6` as the greeter user, not dropped in as a file.**
The alternative — two lines via `sudo install`, matching the
`kwinoutputconfig.json` line right above it — was rejected: KDE writes to
`kcminputrc` itself (keyboard layout persistence, see `SETTINGS.md`), so a
whole-file write would silently discard whatever else ends up there on a
re-run. Merging was verified against a throwaway config dir: a pre-existing
`KeyRepeat` key and a whole `[Mouse]` group survived while `NumLock` changed.

**One thing had to be fixed to make that possible.** The loop's existing
`install -D` creates `/var/lib/plasmalogin/.config/` as `root:root` — the
`-o`/`-g` flags apply to the file, not to the directories `-D` invents. Writing
as the greeter user into a root-owned directory would fail, so the loop now
creates it explicitly with `install -d -o … -g … -m 700`. That also repairs the
ownership on a machine where an earlier run already made it root's.

Not verified live, deliberately: proving it would mean restarting the greeter,
i.e. logging out, and the fresh install ulu is about to run is the better test.
It is on the verification list in `STATUS.md`.

## 2026-08-01 — Session 9: the reinstall ran, and Strawberry's size finally has a cause

First session on the machine the scripts rebuilt from scratch. ulu's opening
report — "Strawberry's size is definitely wrong" — landed on the one item
STATUS had reserved for exactly this moment: the parked KWin-script fix, to be
decided with the case on screen rather than from memory. Measured before he
touched a single window, which is why it is worth anything.

**What the measurement showed, and it corrects the parked diagnosis:**

```
main window:      0,804  3840x2105   transient=false
"Sponsoring…":    0,804  1920x2105   transient=true
```

The dialog carries the rule character-for-character. The main window is not
"too wide" — it is **maximized**: 3840x2105 is exactly DP-2's maximize area
(3840x2160 minus the 55 px panel). Not a coincidental number.

So the mirror-image symptom recorded in session 7 was read one step short. The
rule fires on both windows; the main window then maximizes itself over it,
because Strawberry starts maximized when it has no saved geometry — and
`strawberry.conf` confirmed the precondition: neither `geometry` nor
`maximized` existed on the fresh install.

**And it does not heal itself**, which is the part that changes the decision.
The session-7 note ("corrects itself once Strawberry has saved its own
geometry") is only true if the window is resized by hand first. Left alone,
Strawberry saves `maximized=true` on exit and every later start reproduces it.
A one-time cosmetic flaw would not have been worth code; a permanent one is.

**ulu's call: the declarative fix, not the parked script.**
`maximizehoriz=false` / `maximizevert=false`, both Apply Initially, added to
the existing Strawberry rule in stage 4. Two keys instead of a resident KWin
script with its own `metadata.json`, and it addresses the cause that was
actually measured. The script would additionally have had to demaximize, so
this session made it *more* expensive rather than less.

Verified in the harder case on purpose: Strawberry was quit first, so it wrote
`maximized=true` into its config, and only then restarted. It came up at
`0,804 1920x2105`. The rule beats a saved maximized state, so the fresh-install
case is covered a fortiori.

**Unchanged and still parked: the dialog.** "Sponsoring Strawberry" still opens
at 1920 wide, and KWin still does not consider it a dialog
(`dialog=false, normal=true, transient=true`) — the `transient` finding from
session 7 reproduces exactly on the new system. ulu's 2026-07-31 decision to
accept parent-sized dialogs stands; nothing here reopens it.

## 2026-08-01 — Why the playlist import did nothing, in three parts

ulu's second report: no playlist and no library. The library is the documented
manual step and is treated separately. The playlist is verification point 3,
and the rewritten step did the one thing it was rewritten for — it **warned**
instead of claiming success:

```
12:14:06 WARNING: 'Default' is empty or absent after the import —
```

Since the same command, typed by hand at a Strawberry that had been up for
minutes, imported all 160 tracks instantly, the command was never the problem.
The journal has the rest:

```
12:13:45  Started [systemd-run] /usr/bin/strawberry     ← stage 4, itself
12:13:46  strawberry --create Default …
12:14:06  Starting Strawberry…                          ← the autostart entry
12:14:06  "Strawberry is already running - activating existing window"
```

**Part one: the comment in the script was backwards.** It read "Strawberry
autostarts anyway, so this only pulls that start forward". In fact stage 4
reaches this step 21 seconds BEFORE the autostart entry fires, so the branch
that launches Strawberry is not a fallback, it is the normal path. Every fresh
install imports into an instance that is one second old.

**Part two: waiting for the process is not waiting for the instance.** The loop
broke as soon as `pgrep` saw a process. Reproduced deliberately: `--create`
fired in that gap printed Strawberry's startup banner instead of the
"already running" line, i.e. it found no server and became a second primary
instance. The server is `KDSingleApplication`, listening on
`/tmp/kdsingleapp-<user>-strawberry`, and it appears **60 ms** after the
process — measured, not estimated. Narrow, but it is a real hole and it is
cheap to close by grepping `/proc/net/unix` for the socket instead.

**Part three, the one that actually bit on 2026-08-01: reachable is not ready.**
At 12:13:46 the socket had been up for a second, so the message did reach the
instance. It vanished anyway — no error, exit 0, no playlist row. A one-second
old Strawberry on a virgin database is evidently not yet in a state to accept
one. There is no signal for that, so the fix is not a longer wait but a
**retry that verifies**: up to four attempts, each checked against the
database, and a resend only while the playlist row is ABSENT — `--create` does
not merge by name, so an unconditional retry would leave two playlists called
"Default".

Also removed: the `>/dev/null 2>&1` on that call. It swallowed every diagnostic
this investigation needed; there was not one line about the failed attempt
anywhere.

Verified on a cold start with a throwaway playlist name, so ulu's imported
playlist was never at risk: socket up after 1 s, import landed on attempt 1,
160 tracks. The retry path itself is therefore insurance rather than something
this test exercised — the failure it covers could not be reproduced on demand,
which is precisely why it is a retry and not a longer sleep.

MPRIS was considered as the readiness signal and **rejected by measurement**:
`org.mpris.MediaPlayer2.strawberry` appears 0.1 s after launch — it is a real
name (gone while Strawberry is stopped), but it would report "ready" long
before anything else is, i.e. it would look like a fix and change nothing.

## 2026-08-01 — The sponsoring dialog, and the writer that was still wrong

ulu asked whether Strawberry's sponsoring message can be switched off for good.
It can, and finding the setting turned up a much bigger problem on the way.

**The setting.** The key name is in the binary — `do_not_show_sponsor_message`
— but not its group, because Strawberry only writes the value once the
checkbox in the dialog is ticked, so a pristine run does not reveal it (the
technique that worked for round 3 came up empty here). Determined by
experiment against a throwaway config instead: set the key in four candidate
groups at once, dialog gone; then one group at a time. Only **`[MainWindow]`**
suppresses it; `[General]`, `[Settings]` and `[Sponsor]` leave it standing. The
counter-test is the point — without it we would have shipped three keys that do
nothing and never noticed.

Also worth recording: it is not a *first start* dialog. Strawberry shows it on
EVERY start until the box is ticked.

**The problem, found while verifying.** Writing that key with `kwriteconfig6`
on the live `strawberry.conf` corrupted the file:

```
before:  geometry=@ByteArray(\x1\xd9\0\x3)     presets\1\name=Classical
after:   geometry=@ByteArray(xxd9\\d9\\0\\x3)  presets\\1\\name=Classical
```

38 lines of doubled-backslash junk beside the originals, and the geometry blob
re-encoded into nonsense. This is the qBittorrent lesson from 2026-07-31,
verbatim, on a file we had explicitly cleared: round 3 verified `kwriteconfig6`
as byte-identical on `strawberry.conf` — and that verification was sound, it
was just done on a file that did not yet contain a single backslash key or
`@ByteArray` value. **A fresh install cannot show this bug.** Only a re-run
can, and the Steam step in STATUS.md makes a re-run routine.

**Why the fix is not local this time.** `qbt_set` was defined inside the
qBittorrent block, so the knowledge was inside it too, and the same mistake was
made again three weeks later. It is now `qs_set` at the top of `stage3.sh`,
taking the file as its first argument; `qbt_set` is a one-line wrapper so the
fifteen qBittorrent call sites stay readable, and Strawberry's five keys go
through the same writer. One implementation, one place to fix.

`qs_set` also ends with `cat "$tmp" > "$file"` rather than `mv`, which keeps
the destination's inode, mode and owner — a config that is user-readable only
stays that way without a chmod after every call.

Verified in three steps: the writer against a fixture holding both value
classes (only the intended line changes), then against the live file (only the
restored `[PlaylistSequence]` appears in the diff, permissions unchanged), then
across a full Strawberry start/quit cycle — 0 doubled-backslash lines, 38
presets intact, all five keys present, sponsoring dialog gone.

**One loose end, deliberately not written up as solved.** `[PlaylistSequence]`
— ulu's shuffle and repeat modes — had disappeared from the live config
somewhere between 12:31 and the cleanup. The corrupting write sits inside that
window, and a clean file survives a start/quit cycle intact, so the chain
"corrupt file → Strawberry drops what it cannot parse → rewrites without it" is
consistent with everything observed. It is not proven, several Strawberry
restarts sit in the same window, and it is recorded as unattributed rather than
guessed at. The values are back.

## 2026-08-01 — The collection stays manual, decided again on better grounds

The second half of ulu's report: no library. Confirmed by measurement rather
than by looking at the window — `directories: 0, songs: 0, subdirectories: 0`,
`[Collection]` in `strawberry.conf` holding grouping options and no path, and
no scan in progress. What ulu was seeing is the **playlist**, whose 160 entries
carry their own file paths and play perfectly well without a collection. That
is the trap this step sets: an empty collection looks like a working one.

**No interface exists.** Checked before discussing anything: Strawberry's D-Bus
surface is MPRIS only (playback, playlists, tracklist), and its CLI has no
option for the collection or a rescan. The only scriptable route is a row in
`directories(path TEXT, subdirs INTEGER)` inside `strawberry.db`.

**The old rationale was partly wrong, and that is why this was reopened.** It
read: the path lives in the database, and the database is state rebuilt by a
rescan. The first half is true; the second conflates two things. The *scan
result* is state — 55 559 song rows, nothing that belongs in a repo. The
*directory row* is not state, it is one decision written as one row, and the
scan result is precisely what we would want rebuilt.

**ulu's call: it stays manual.** So the trade was put honestly and he took the
other side of it — writing into a database another application owns is a class
this repo has avoided, and one directory added by hand every few years is a
smaller price than the first script in phoinix that edits foreign state, even
with a `schema_version` guard (23 today) to turn an upstream change into a
message instead of corruption. Recorded so the reasoning survives, not just the
outcome: the scripted version was designed, costed, and declined — do not
rebuild it without being asked.

## 2026-08-01 — The Places race, measured to the millisecond and closed

Verification point 7 existed because the previous run left an ambiguity: the
step reported the file missing at 22:44:00 and the file carried mtime 22:44,
i.e. "somewhere in the same minute". Not enough to tell a race from an ordering
problem, so STATUS asked for the observation before the decision. It came:

```
12:13:44        WARNING: user-places.xbel does not exist yet
12:13:44.871    the file is created
```

The same SECOND, a few hundred milliseconds after the check. A race, confirmed,
and nothing to do with where the step sits in the script.

Two further facts made the fix easy. The session creates the file by itself
(KIO/plasmashell) rather than waiting for a human to open Dolphin, so it is
only ever *early*, never absent — waiting is guaranteed to terminate on a
healthy session. And nothing rewrote it afterwards, not even the plasmashell
restart at 12:14:06, so whoever gets to write it keeps it.

**Fix (ulu's call): wait, do not move.** The existence check becomes a bounded
wait — up to 30 s for the file to appear AND to contain its closing `</xbel>`.
The completeness half is not decoration: the file is being written at exactly
this moment, so "exists" and "usable" are genuinely different states here. On
timeout the old warning stands, now phrased so it does not claim the file is
merely missing.

Moving the step behind the plasmashell restart was the alternative and was
rejected as the same bet with better odds — a slower machine would lose it
again, and then the warning appears with no explanation attached.

Applied live in the same step, with the section sourced from the script rather
than retyped (the 2026-07-31 lesson about `bash` not inheriting non-exported
variables): six labels resolved, six separators written in the declared order,
all 22 bookmarks preserved, and the result parses as XML.

## 2026-08-01 — Session 9 closes the verification list

FFXIV was the last open point and ulu had already played: everything correct.
Verified afterwards what can be verified without the game running — the rule
carries `position=3840,1120 size=3440,1440` with class **and** title match, and
`launcher.ini` has `WaylandEnabled=false`, `GameModeEnabled=true` and both game
paths on the games disk. The Wayland flag is the load-bearing one: without it
the client is Wayland-native and no rule of ours could place it. It survived
the reinstall because `xlcore-backup.sh` carries `launcher.ini`, which is
exactly the mechanism the gamemode work put in place on 2026-07-31.

**Result of the run, in full: nine points, seven passed outright.** Desktop
icons (the stopper of the previous run) landed on the right containment,
qBittorrent started, the commit identity was set, KeePassXC placed itself,
NumLock was live at the greeter, the Places race behaved exactly as predicted,
and FFXIV opened borderless. Two failed — the Strawberry window size and the
playlist import — and both were fixed with the failure on screen rather than
from memory, which is what the list was written for.

The two failures also each produced something larger than themselves: the
window-size case retired the parked KWin-script plan on measured grounds, and
the playlist case led, via the sponsoring dialog, to the discovery that
`kwriteconfig6` had been corrupting `strawberry.conf` all along in a way no
fresh install can reveal.

Not done: **nothing is pushed**. GitHub authentication remains the manual
post-install step recorded on 2026-08-01, and it has not been re-established on
this machine, so session 9's five commits are local only.

## 2026-08-01 — DZGUI moves out of Steam and onto the desktop

ulu dropped the idea of a DZGUI entry inside Steam and asked for a desktop icon
beside XIVLauncher instead. Three things came out of it.

**The removal takes a manual step with it.** The Steam mechanism restored a
`shortcuts.vdf` whose only entry was DZGUI — verified by reading it, one entry,
one exec path. But `shortcuts.vdf` can only be written into
`userdata/<id>/config`, which does not exist until Steam has been logged into,
and Steam rewrites the file when it exits. That ordering is precisely what put
"set up Steam, THEN re-run stage 3" on the post-install list. A desktop file
depends on nothing but the DZGUI binary, so the requirement disappears with the
mechanism. `STEAM_SHORTCUTS_FILE` is gone from the config; the backup file
stays on the games disk, unused.

**The icon cell is `ROW,COLUMN`, and the script said otherwise.** Placing DZGUI
at `3,2` to put it right of XIVLauncher at `2,2` put it UNDERNEATH — ulu saw it
immediately. The variables in stage 4 were named `cell_col cell_row` while the
pair is in fact row-first. Harmless as long as values are only copied from a
running system (the pair is written in the order it is read), and actively
misleading the moment someone reasons about a position. Renamed, commented with
the measurement, and the config now says `2,3`.

**The icon comes out of the game, without a new package.** No `.desktop` and no
icon ship with DZGUI, and the Steam sources were all wrong-shaped: a 32x32 app
icon, a 640x360 wordmark, a 300x450 portrait capsule. The real icon sits inside
`steamapps/common/DayZ/DayZ_x64.exe` — seven icon groups, sizes up to 128x128,
all of them 32-bit DIBs rather than PNG. Reading the PE resource directory and
converting a BGRA DIB to PNG is about fifty lines of Python with only `zlib`
and `struct`, so `icoutils` was not needed. All seven 128x128 entries turned
out to be the same image.

Where it lives is the part that had to be decided rather than done: the PNG is
parked at `/mnt/Games/phoinix/dzgui-icon.png` and only the path is versioned —
the same shape as `DZGUI_PRIVATE_FILE` and `GIT_CREDENTIALS_FILE`, except that
here the reason is copyright rather than secrecy. It is Bohemia's artwork and
this repo is public. The games disk is never formatted, so it survives a
reinstall by construction. Rejected alternatives: carrying a PE parser in the
repo (fifty lines to maintain for one icon) and adding `icoutils` (a package
whose sole consumer would be a desktop icon).

Stage 3 installs it as `hicolor/128x128/apps/phoinix-dzgui.png` and substitutes
`@ICON@` in the template with `phoinix-dzgui`, or with `applications-games`
when the file is absent. A NAME, never a path, and that is deliberate: a path
to a file that failed to install renders nothing, while a name that cannot be
resolved still falls back to a generic icon.

## 2026-08-01 — The SSH key nobody noticed was gone

A sidequest — ulu asked what the three folders on the Downloads disk were for
— turned up a real hole. `~/.ssh` on the rebuilt machine contained exactly one
file, `authorized_keys`, written by stage 3 from the repo. **The private key
was never restored**, and the only copy was the rescue directory made before
the reinstall.

**Why it stayed invisible.** Incoming SSH works: `authorized_keys` is in the
repo, so the laptop can still reach the desktop and nothing looks broken. What
was missing is the machine's own identity — the outgoing direction, which
nobody exercised in the hours after the install. `REINSTALL.md` documented how
to RESCUE `~/.ssh` and never said a word about putting it back, so the step
existed in nobody's list, mine included.

Restored from `/mnt/Downloads/rescue/ssh/`, fingerprint verified identical
(`SHA256:z9vRGeFt…`, `ulutoyon@desktop`), key parses and carries no passphrase.
`authorized_keys` deliberately NOT copied back: the live one is the repo's, with
the comment sanitised, and the key material is identical anyway.

The return path is now written into `REINSTALL.md` next to the rescue that
produces it, and deliberately not scripted into stage 3 — a private key is the
last file an installer that also runs unattended in a VM should be moving
around, and a missing rescue directory must be noticed rather than skipped.

**What the same look at those folders established, by measurement rather than
assumption:**

- `rescue/` is load-bearing: besides the key it holds the only copy of the 15
  pre-reinstall transcripts, and a live `.credentials.json` at 0600.
- `backup-nvme1n1-20260730/` (20 MB) is redundant with one exception. All 7 of
  its transcripts are byte-identical inside `rescue/` — compared file by file,
  zero differences, zero files present only there. Its config captures are
  either in the repo (`kwinrc`, `kdeglobals`, `kwinoutputconfig.json`,
  `10-clock.conf`, the wireplumber state, `.zshrc`, `.p10k.zsh`), deliberately
  excluded (the stale `pipewire.conf`, `disabled-forceclock.bak`), replaced by
  explicit keys (`kscreenlockerrc`), or superseded (`.local/share/kscreen` is
  the Plasma 5 location). The exception is `.claude.json`, which
  `REINSTALL.md`'s rescue never copied and which exists nowhere else.
- `keepassxc-pre-merge-2026-07-31/` (1.4 MB) stays, per the standing note: keep
  until the database has been in daily use for a while. One day is not that.

## 2026-08-01 — The Downloads-disk backups are gone (ulu's call)

Straight after the SSH key was restored, ulu deleted all three directories:
`rescue/`, `backup-nvme1n1-20260730/` and `keepassxc-pre-merge-2026-07-31/`.
The consequences were put to him first and he took them; recorded here because
two of them outlive the decision.

**Every session transcript before 2026-08-01 is gone.** That was the archive
the soundbar's −26 dB and its reason were recovered from, months after the
knowledge had been lost — the precedent that made those files worth keeping in
the first place. There is no second copy anywhere. In practice this raises the
stakes on this log: a rationale not written down here is now unrecoverable,
where before it could be dug out of a transcript.

**The four KeePassXC conflict copies are unrecoverable.** They were judged
unlikely to have diverged (sizes grew monotonically) but that was never proven.
If an entry turns out to be missing from the live database, it is missing.

One thing resolved rather than lost: those directories held the last copies of
ulu's real name on this machine, and a live `.credentials.json` on a data disk.
Both are gone with them.

Docs corrected to match: `STATUS.md` (three references), `REINSTALL.md` (the
"done for the 2026-07-31 run" note). This log keeps its earlier entries as they
were written — they describe what was true at the time, which is the point of
an append-only log.

Also folded into `REINSTALL.md`: `~/.claude.json` joins the rescue list. It
existed only inside the 2026-07-30 backup, was never covered by the rescue
procedure, and went with it — the same shape of gap as the SSH key, found the
same afternoon.

## 2026-08-01 — One home for everything the repo uses but must not carry

ulu asked for all files that are deliberately outside the repo, yet read by it,
to live in one place: `/mnt/FilesMusic/phoinix/`. They had accumulated across
four directories on two disks, each with its own good local reason and no
overall shape — which made "what does this repo depend on that is not inside
it?" a question nobody could answer without grepping.

New config variable `PHOINIX_DATA`, and the five paths derive from it. Moved by
copy → verify → delete, so a failed compare would have kept the original:

| What | From | To |
|---|---|---|
| GitHub token | `/mnt/FilesMusic/phoinix/git-credentials` | unchanged — it was already the model |
| WireGuard configs (CH, NL) | `/mnt/FilesMusic/VPN/` | `$PHOINIX_DATA/vpn/` |
| DZGUI secret + server list | `/mnt/FilesMusic/DZGUI/dzgui-private.json` | `$PHOINIX_DATA/dzgui-private.json` |
| DayZ icon artwork | `/mnt/Games/phoinix/dzgui-icon.png` | `$PHOINIX_DATA/dzgui-icon.png` |
| XIVLauncher backup, 80 MB | `/mnt/Games/FFXIV/xlcore-backup/` | `$PHOINIX_DATA/xlcore-backup/` |

Permissions came along: both `.conf` files and `dzgui-private.json` are still
0600. Nothing outside the repo referenced the old paths — checked before
moving, because the VPN configs are imported into NetworkManager and a live
tunnel reading its source path would have broken. It does not; NM keeps its own
copy.

**FilesMusic rather than Games**, deliberately: both are data disks phoinix
never formats, but the games disk is the one that gets emptied when a library
is moved somewhere else.

**Two paths stay out, and the reasons are different in kind.**
`PLAYLIST_FILE` cannot move: the `.m3u` stores RELATIVE paths
(`Lovebites/2017 - …/01 - ….mp3`), resolved against its own directory, so
moving it away from the music root breaks all 160 entries. That is arithmetic,
not preference. `KEEPASS_DB` could move but should not: it is ulu's live
password database, opened daily by KeePassXC, and phoinix only points at it —
it is not an asset of this repo, and this repo never touches it.

Left behind on the games disk: `/mnt/Games/phoinix/shortcuts.vdf`, dead since
the Steam shortcut mechanism was dropped earlier the same day. Deliberately NOT
moved — `PHOINIX_DATA` is for what the scripts read, and nothing reads it.

One more out-of-repo path exists and is not in that directory either: the Arch
ISO `scripts/qemu-test.sh` defaults to. It is a download rather than an asset,
already overridable with `PHOINIX_ISO`, and ulu deleted the copy that was on
the Downloads disk while clearing it out.

## 2026-08-01 — mpc-qt drops out of stage 3, and no step needs a second run

ulu: remove the mpc-qt configuration entirely, he will set the player up
himself, because he does not want to run stage 3 twice.

The reason it ever needed two runs is worth keeping now that the code is gone.
mpc-qt 26.07 segfaults in `QScreen::availableGeometry()` out of `main` when
`settings.json` exists and `geometry_v2.json` does not — and the crashing run
leaves exactly that state behind, so the player never starts again. Tested three
ways in session 6: a two-key `settings.json` alone crashes, so does one paired
with an empty `geometry_v2.json`, so does a stub. The profile therefore could
not be seeded, only edited, and editing needs a profile that exists — hence
"start it once, then re-run stage 3".

Two track preferences were not worth that shape, and ulu is the one who pays
for it. Removed: the profile repair and both `jq` writes.

**What this closes is bigger than mpc-qt.** Together with the DZGUI shortcut
dropped earlier the same day, the last reason to run stage 3 twice is gone.
"Set up Steam, then re-run stage 3" and "start mpc-qt once, then re-run" were
the only two, and both existed for the same structural reason: a step that
could only act on state some application had to create first.

**Kept deliberately: the mpc-qt window rule in stage 4** (`adaptivesync=false`).
It is a different kind of setting — it needs no profile, no second run and no
cooperation from the application, and it fixes the video flicker documented
beside it. Removing it would bring back the exact symptom that drove ulu up the
wall on YouTube, on a machine where VRR must stay on for games.

Kept in `SETTINGS.md` too, though the code is gone: the contrast with
LibreOffice, where seeding was verified to work. Same question, opposite
answer, and only the measurement told them apart — that is the kind of finding
that gets re-derived expensively if it is deleted along with its code.

## 2026-08-01 — Pre-flight for the second reinstall

ulu goes straight into another reinstall. The checks from `REINSTALL.md` were
run rather than assumed, and one came back red.

- Repo pushed, `main` = `origin/main`.
- `check-drift.sh desktop`: 10 in sync, 0 drifted, 1 expected to differ (the
  wireplumber stream-properties, per-application state).
- `PHOINIX_DATA` complete, permissions intact.
- Boot stick `ARCH_202607` present, so the deleted ISO does not matter.
- **The rescue copy was missing.** Deleted earlier the same day, correctly —
  but that left `~/.ssh/id_ed25519` in exactly one place, on the partition
  stage 1 formats. Remade, fingerprint verified identical after the copy, and
  `~/.claude.json` included this time.

**The rescue copy now lives in `PHOINIX_DATA` too** (ulu, mid-operation: "den
rescue kram packst du in /mnt/FilesMusic/phoinix/"). It is not read by any
script, so it is a slightly different class from the rest of that directory —
but it is the same question for the human: what does a reinstall need that the
repo cannot hold? One place, one answer. The Downloads disk was one more place
to remember.

Also refreshed: `scripts/xlcore-backup.sh desktop`, because ulu played FFXIV
after the morning's install and the backup was from the evening before. Exactly
the trap the GameMode flag set on 2026-07-31, where an unrefreshed backup would
have restored the old value. It landed in the new location by itself —
`XLCORE_BACKUP_DIR` derives from `PHOINIX_DATA` now.

`STATUS.md` rewritten for the run: eight points, of which the interesting ones
are the retry path in the playlist import (never fired in anger), the five paths
that moved into `PHOINIX_DATA` today, and the manual SSH restore — the step
that was missed last time precisely because its absence is invisible.

## 2026-08-01 — Claude Code's local settings survive a reinstall, by ulu's call

Adding `.gitignore` for `.claude/settings.local.json` created a hole the same
minute it closed one, and ulu spotted it: the file is gitignored, so it does not
come back with the clone, and it lives in `~/phoinix/.claude/` — on `/home`,
which stage 1 formats. It was also not covered by the rescue copy, which takes
`~/.claude`, a different directory entirely. Before the .gitignore it would at
least have returned with the checkout.

Worth stating what was NOT at risk, since "then everything's gone" was the
worry: the transcripts and `~/.claude.json` are in the rescue copy. Only this
one settings file was.

**Two ways were put to him** — restore it by hand next to the SSH key, or have
stage 3 install it from `PHOINIX_DATA` like every other file in that class. The
recommendation was by hand, for a reason worth recording: the harness twice
refused to let the assistant set `bypassPermissions` itself, deliberately, and
writing it into stage 3 puts the same result one step further back. **ulu chose
automation.** His machine, his call, and the concern is recorded here and in
`config.sh` rather than re-litigated. Undoing it is deleting one variable.

**The first implementation was wrong and the test caught it inside a minute.**
It used `install -Dm644` unconditionally, which restored the data-disk copy over
the live file — destroying four permission rules Claude Code had appended during
this very session. Restored from a scratch copy taken before the test.

The fix is the pattern this repo already uses for the DZGUI config and the
KeePassXC recent-database: **seed only when absent**. An existing file is ulu's
and is newer by construction, because Claude Code appends a rule every time he
grants one, while the data-disk copy is a hand-made snapshot. Both branches were
then verified explicitly: with the file present it is left untouched (md5
compared before and after), with it absent it is restored carrying the mode.

Accepted cost, named in the script: the data-disk copy goes stale unless
refreshed by hand — exactly like `XLCORE_BACKUP_DIR`, and now listed beside it
in `REINSTALL.md`'s pre-flight.

## 2026-08-01 — The split tunnel separated packets, but not names

ulu noticed it from the outside, which is the only way this could have been
noticed at all: some sites believed he was in Switzerland while the VPN was up,
and speedtest.net proposed a different German server with the tunnel on than
with it off. The routing was never at fault. Measured on the live desktop:

| | exit |
|---|---|
| ordinary process | Vodafone, Germany |
| process in group `vpnonly` | Proton, Zurich |
| **DNS of the whole machine** | **Proton, Zurich** |

`ip rule` knew only `fwmark 0x51 → table 51`, the default route sat on
`enp8s0`, and only the marked group entered the tunnel — exactly as designed.
What had moved into the tunnel was every NAME the desktop resolved: the
WireGuard import gives the connection `DNS = 10.2.0.1` and NetworkManager turns
that into a `~` search domain, i.e. resolved's DNS DEFAULT ROUTE. The proof was
blunt — with the tunnel up, `resolvectl query --interface=enp8s0 www.speedtest.net`
answered "No appropriate name servers or networks for name found". There was no
path left for a global name to leave over ulu's own line.

**Why that reads as Switzerland.** CDNs place a client by the resolver that
asks. So the packets left via Vodafone while the lookups came out of Zurich,
and everything served from an edge network handed him Swiss nodes. Sites that
read the client IP saw Germany. That is precisely the "some sites, not all"
pattern ulu described.

**This was half-recorded, and the half that was missing is the interesting
one.** `system/NetworkManager/10-phoinix-dns.conf` said "while the tunnel is up
it is authoritative" — the decision was real, but it had been made about
TIMEOUTS (a dropped tunnel must not stall the desktop in lookup delays), and
nobody had asked what it does to geolocation while the tunnel is up. The file
now carries the correction and the reason it never looked broken.

**Fixed in two steps, ulu's choice of variant (he picked the third of four
options offered: DNS out of the tunnel AND encrypted elsewhere).**

1. The tunnel carries no resolver at all: stage 3 clears `ipv4.dns`,
   `ipv6.dns` and both `dns-search` values on every imported Proton profile.
   Clearing the SERVERS matters, not just the domain — a link with servers and
   no domain is still a candidate for the default route. Applied live with
   `nmcli device reapply`, which did NOT tear the tunnel down; qBittorrent kept
   running and kept exiting in Zurich.
2. Quad9 over TLS on the wired link, the LAN router restricted to the domain
   its own DHCP lease announces (stage 3, section 7c; printer moved to 7d).

**The arrangement looks inverted and has to be.** The obvious layout — router
on the link, Quad9 global — does not work: NetworkManager marks the wired link
as resolved's DNS default route whatever domains it is given (measured: with
`~fritz.box` as its only domain the link still reported `Default Route: yes`),
and a link holding the default route claims every name. So the link runs Quad9
and the more SPECIFIC global scope wins for the LAN domain.

**The LAN half is not optional.** Without it the LAN name does not fail, it
RESOLVES — to a stranger's host on the public internet, because that domain
exists out there. A wrong answer that works is worse than an error.

Nothing of this is stored: resolver address and LAN domain both come out of the
DHCP lease at runtime, which is also why the section cannot live in stage 2 —
there is no lease in the chroot.

**Quad9 rather than Cloudflare or dns0.eu, ulu's call.** A foundation rather
than a corporation, no client-IP logging by its own policy, malware filtering
included. The one risk is named in `config.sh`: this resolver now also answers
for qBittorrent's trackers, so a false block would look exactly like a broken
tracker. `9.9.9.10` / `dns10.quad9.net` is the same service unfiltered — the
fix is a value in `config.sh`, not a rebuild. Strict DoT (`2`), not
opportunistic: a silent fallback to port 53 would hand the ISP exactly what
this section exists to withhold.

Accepted and worth naming: the resolver answers by anycast from Frankfurt and
sends no ECS, so CDNs now place the desktop in Frankfurt instead of Mannheim.
Against Zurich that is the repair; against the ISP's own resolver it is a small
loss of precision with no practical effect.

## 2026-08-01 — The audio glitching, reopened: PipeWire has no realtime priority

STATUS said it plainly: if it still glitches at −26 dB, the level was never the
cause and the investigation reopens somewhere else entirely. ulu played FFXIV
and reported glitches live, several per hour, so this is that reopening.

**Found within minutes, and it is a real defect regardless of what it
explains.** PipeWire's own log, every start since the install:

```
mod.rt: RTKit error: org.freedesktop.DBus.Error.ServiceUnknown
mod.rt: RTKit does not give us MaxRealtimePriority, using 1
```

`rtkit` is not installed, `realtime-privileges` is not installed, `ulimit -r`
is 0, and all three `data-loop.0` threads (pipewire, wireplumber,
pipewire-pulse) run `SCHED_OTHER`. A fresh Arch does not pull `rtkit` — it is
an optional dependency of pipewire — so phoinix has been building machines
whose audio threads compete with a fully loaded game for CPU time. **`rtkit`
therefore belongs in `packages/audio.txt`.**

**It produces measurable xruns.** `pw-top` counters over an evening of FFXIV:
the game's node climbed 5 → 63, Brave 4 → 9, the sink 1 → 8. The signature that
rules out an application bug: at 18:28:03 FFXIV went 7 → 9 and Brave 4 → 6 in
the SAME sampling second while the sink stayed put. Two unrelated clients
missing one moment together is a systemic scheduling stall.

**And it does not explain what ulu hears. Two clean negatives.** At 18:49 and
again at 19:31:35 he reported a glitch and the counters had not moved for 35 s
in the first case and 10 s in the second — the second one measured four seconds
after the report, immediately after a live test had put the data threads on
`SCHED_FIFO 20`. Asked what it sounds like, he described "a distortion, very
electronic", which is not the sound of a missed buffer: an xrun makes a hole or
a click.

**What the computer sends is provably clean.** Ten minutes of the sink monitor
recorded to disk (6 ch, 48 kHz, `pw-record` against the monitor SOURCE — note
that `--target <pactl sink index>` records silence, the pactl and PipeWire
numbering spaces are not the same): peak −20.5 dBFS, zero clipping samples,
zero silent blocks. A sample-level pass over the 31 seconds around one report
found the largest step between consecutive samples at −33.7 dBFS, i.e. ~680 of
32768. Digital garbage would sit near full scale.

**A premise of the 2026-07-31 analysis no longer holds.** That entry explained
the noise with a −73 dBFS source amplified by a cranked-up bar. Today the
digital level is −20.5 dBFS peak — 50 dB higher — because the game's own sound
is on. Whatever ulu hears now, it is not that.

**Also corrected, and it matters for how the −26 dB is read:** the sink carries
`HARDWARE HW_VOLUME_CTRL DECIBEL_VOLUME`. The −26 dB is the DEVICE's own volume
control, not a digital attenuation inside PipeWire. What the machine puts on
the wire is untouched by it. `SETTINGS.md` described this differently.

**Where it stands.** The monitor recording sees what the GRAPH produces, not
what the DEVICE plays, so it can only exonerate the digital side — and it does.
Everything downstream is still open: USB transport, the Concept 12's own
electronics, the analog chain. Ruled out along the way: USB autosuspend
(`power/control` is `on`), kernel USB or ALSA errors (none this boot), a shared
bus (the device sits alone on its own controller — an earlier claim that it
shared with the Scarlett and Bluetooth was based on a truncated `lsusb -t` and
was wrong), and buffer starvation on the ALSA side (period 512/128, ring 32768
frames = 683 ms).

Not yet tried, in this order: forcing a larger quantum at runtime
(`pw-metadata -n settings 0 clock.force-quantum 1024`, reversible with `0`),
then a different cable, then the device on another machine. Also unexplained:
the ALSA period changed from 512 to 128 frames when the device was replugged
into the neighbouring port, which makes any before/after comparison across that
replug unreliable.

## 2026-08-01 — Steam launched nothing, and DZGUI waited for downloads that never started

Two failures in one evening, unrelated to each other and both worth recording
because neither is diagnosable from the symptom.

**"Compatibility tool failed", every Steam game.** The client asserted on every
launch:

```
src/clientdll/compatmanager.cpp (1386) : Assertion Failed:
Tool 1493710 "Proton Experimental" unsupported version 0.
GameAction [AppID …] : LaunchApp failed with AppError_51
```

ulu's first guess was the renamed disk paths, and it was worth checking because
the compat tools live on the games disk — but `libraryfolders.vdf` carried
`/mnt/Games/SteamLibrary` with the `contentid` matching the disk's own
`libraryfolder.vdf`, and 1493710 was in its app list. On disk the tool was
complete: `toolmanifest.vdf` version 2, `version` file present, its required
runtime (4183110, Steam Linux Runtime 4.0) installed with StateFlags 4. So:
everything correct on disk, version 0 in the running client — a client-state
problem, not an installation problem.

Fixed by quitting Steam (`steam -shutdown`), moving `appcache/appinfo.vdf`
aside — renamed, not deleted — and starting it again. Afterwards the chain
resolved and both command prefixes pointed correctly into the games disk.
**Honest limit:** restart and cache removal happened together, so which of the
two did it is not separable, and the rebuilt cache came out byte-identical in
size (2 546 102 B, 1020 apps), which argues for the running client having been
confused rather than the file on disk. Next time try the plain restart first.

**DZGUI 7 then hung for half an hour at "Steam is staging mods (step 2/2)".**
The server ulu joins requires **79 mods** and he had 10; the other 69 amount to
16.4 GiB. DZGUI subscribes each missing item over the Steam Web API
(`IPublishedFileService/Subscribe/v1`, `notify_client=1`, one second apart) and
then waits — in `managers/connection.py`, without timeout and without progress
— first for the directory to exist, then for `get_mod_dir_size()` to equal the
expected size exactly.

The subscriptions were fine: a single call reproduced by hand returned HTTP 200
with `x-eresult: 1`. The running client simply never acted on them — no entry
in `steamapps/downloading`, nothing pending in `appworkshop_221100.acf`, no CDN
transfer. Pushing the client directly with `steam +workshop_download_item
221100 <id>` (what DZGUI 6 did, deprecated in 7 in favour of the Web API) was
accepted 68 times and did nothing each time: `Update Queued → Running →
Reconfiguring → None → finished, No Error` inside the same second, because the
client checks its own stale subscription list and finds nothing to do.

**What worked: restarting Steam.** It pulls the subscription list at logon, and
the 16.4 GiB started immediately (~18 MB/s, done in ten minutes). DZGUI needs
no cancelling for this — it polls the filesystem, not the client.

Two things learned that are worth more than the fix:
- **DZGUI 7's staging step cannot distinguish "waiting" from "will wait
  forever".** No timeout, no byte counter, no list of what it is waiting for.
  A hang there means: check `steamapps/downloading` and the workshop manifest
  yourself, then restart Steam.
- Its expected sizes are a snapshot taken when the join begins. If a mod is
  updated upstream in the meantime, the equality test can never succeed. Cancel
  and re-join re-reads everything, and with all mods present it skips both
  steps.

Two upstream bugs seen in passing, both harmless here, both reproducible for
any dual-stack user: `get_local_coords()` feeds the public IP through a
dotted-quad parser, so an IPv6 answer from `ipecho.net` raises and the distance
sorting silently disappears; and `_update_mods()` sums `row[2]` for the
"required size" where the size is `row[3]` — that field is the timestamp.

One mistake of ours, recorded because it would be invisible in another run: the
helper that queued the 69 downloads read its id list with `while read` from a
file without a trailing newline and silently queued only 68.

## 2026-08-02 — rtkit granted the priority and took the sound card with it

ulu reported the glitching was frequent right then, so a second live session was
run: raw sink monitor to disk plus `pw-top` with a timestamp on every line, and
"da" from ulu whenever he heard it. Six reports over eight minutes. This entry
records what that measured, and how it ended.

**The systemic stall is confirmed, harder than yesterday.** FFXIV's node went
14 → 39 xruns in eleven minutes and Brave incremented at the SAME timestamps
every single time: 22:22:17, :18, :21, then 22:24:19, :25, then 22:25:11, :29,
:33. Eight coincidences, zero divergences. Two unrelated clients cannot miss
the same moments by accident — this is the graph stalling, not an application.
The sink's own counter stayed at 1 throughout.

**And the reports still do not sit on the stalls.** Six "da": 22:22:34 (three
in a row), 22:22:53, 22:25:28, 22:26:23, 22:26:52, 22:29:53. Only one of them
lands near an xrun — 22:26:52, with a stall 1.4 s earlier, which is within the
delay of hearing it and typing. The three at 22:22:34 sit in the middle of a
two-minute stretch with no xrun at all. That is the same negative as yesterday,
now with a bigger sample.

**A control window settles it.** For each report the six seconds before it were
scanned for the largest sample-to-sample step relative to the local signal peak,
and the same scan was run on a twenty-second stretch nobody complained about.
Report windows: ratios 0.70 to 1.11. Control window: 0.81 to 1.20. The control
is *worse*. There is no digital signature of the glitch, at all — the file
leaving the computer is clean, twice measured, in two sessions.

**The level theory dies a second time, and this time with the right model.**
Measured over 154 s: peak per second between −34 and −43 dBFS, RMS −52 dBFS,
while FFXIV's own stream sits at 100 %. Then the sink attenuates another 26 dB —
and `pactl` reports `HW_VOLUME_CTRL` for this device, so that happens *inside*
the Concept 12, after the monitor tap. The DAC therefore sees about −64 dBFS
and the bar's amplifier makes all of it back up, along with its own noise. That
is a genuinely plausible mechanism for a noise that sounds "electronic", so it
was tested: sink to 100 % at 22:28:17, ulu turning the bar down first. Nothing
changed — neither the sound nor the xrun rate (34 → 39 afterwards, same 1.7 per
minute). The volume was put back to 37 %.

**Two side findings from the same recording**, both unexplained and both parked:
of six channels only front left/right and LFE carry anything; rear left, rear
right and center are flat over 154 seconds (peak 128 of 32768). And the graph
runs at quantum 256, not the 1024 in the configuration, because FFXIV asks for
256 and the smallest request wins.

### The rtkit failure

`rtkit` had been added to `packages/audio.txt` yesterday and was still not
installed here, so it was installed now and the user audio stack restarted. It
worked exactly as documented: `data-loop.0` came up `RR 20`, `rtkit-daemon`
active. Ninety seconds later ulu wrote that the audio devices had had a stroke.

`pactl list short sinks` showed one line: `auto_null`. Every real device was
gone, FFXIV's stream was routed to sink `4294967295` — nowhere. The journal:

```
wireplumber.service: Main process exited, code=killed, status=9/KILL
wireplumber.service: Scheduled restart job, restart counter is at 23.
```

SIGKILL, two to three seconds after every start, twenty-three times. Not
systemd doing it: the unit has no watchdog and `LimitRTTIME=infinity`. Started
by hand in the foreground with the service stopped, it died just as fast, its
log ending after the harmless libcamera warning — so it is the process being
killed from outside, not a crash. WirePlumber's `data-loop.0` had `RR 1` at the
time; PipeWire's had `RR 20` and was never touched.

The most likely mechanism is `RLIMIT_RTTIME`: a realtime thread that overruns
its budget gets `SIGXCPU` and then `SIGKILL` from the kernel, which logs
nothing in userspace. Not proven — and deliberately not chased further, because
the machine was unusable while it was being chased.

**Recovery, in the order it worked:** kill the stray wireplumber, restart the
three user units, put the default sink and the 37 % back. Devices returned,
restart counter 0. ulu then removed the package himself. `rtkit` is now marked
rejected in `packages/audio.txt` with the reason, and the realtime deficit goes
back on the open list — it is real, it is measured, and the obvious fix for it
breaks this machine.

**One trap worth writing down.** `sudo systemctl --user restart pipewire` fails
with "$DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined" — `--user`
under `sudo` looks for root's session bus, which does not exist. User units are
restarted without `sudo`, always.

**And one on tooling:** this desktop has no `python-numpy`, so the analysis is
pure Python — an `array('h')` over the raw frames, a coarse pass in 1 ms blocks
at C speed, and the per-sample work confined to the windows around the reports.
Eleven minutes of six-channel audio analyse in under two seconds that way.

## 2026-08-02, later — two different faults, and the Teufel's one is invisible from here

The same evening continued, and it produced the first clean separation since the
glitching was reported. Three things were changed one at a time, and each one
answered something.

**Output moved to the Scarlett Solo (headphones), 22:47.** This test had never
been run: everything measured so far described the digital stream, and the
digital stream is clean, so the untested part was everything after it. ulu's
verdict: the crackling is there on headphones too — "but quieter and shorter,
and not so electrically distorted". That splits the problem in two. Something
the computer does reaches both devices; the "electric" character belongs to the
Concept 12 alone.

Worth recording as a side effect: on headphones the game was barely audible at
75 % because FFXIV sends at about −38 dBFS with its stream already at 100 %.
The bar's amplifier had been hiding that all along.

**`clock.force-quantum 1024`, 22:59 — wrong, and reverted at 23:00:31.** The
reasoning was sound (no realtime priority, so give the graph four times the
deadline), the result was not: ulu reported the crackling went to "almost
permanent", and reverting brought it back to occasional. Presumably because
FFXIV keeps delivering at 256 and the adapter has to convert. But the same ten
minutes produced the harder result: **not one xrun was counted while the
crackling was nearly continuous.** FFXIV stayed at 19, the sink at 2. The xruns
are real and they are not this sound. That line of investigation is closed.

**The kernel log was the thing nobody had looked at.** 123 entries that evening:

```
xhci_hcd 0000:0c:00.0: Frame ID 1917 (reg 15332, index 42) beyond range (1919, 763)
```

An isochronous audio packet the host controller could no longer schedule — the
slot was already gone. The packet is lost *below* PipeWire, which is exactly why
the digital capture is clean and no xrun is counted: PipeWire delivered on time,
the controller dropped it. The bursts cluster where the crackling was worst:
one at 22:22, four at 22:27, 66 at 22:48 (the minute the Scarlett was switched
in), 45 across 22:57–22:58, 27 at 23:17:15.

`0c:00.0` is the AMD chipset controller and carries the Scarlett, a second USB
audio device, Bluetooth and the input devices. **The Concept 12 hangs off a
different controller entirely** (ASMedia `70:00.0`), which logged nothing all
evening.

**The counter-test, 23:18:57 — switched back to the Teufel.** Since that moment
the kernel log is silent, and ulu reported the distortion twice, at 23:21:53 and
23:22:31. Nothing in the kernel either time. The xrun counter did move on this
path (27 → 31 between 23:21:02 and 23:21:48) but the second report came 43
seconds after the last one.

So the two paths fail in completely different ways:

| | Teufel (ASMedia) | Scarlett (AMD) |
|---|---|---|
| PipeWire xruns | yes | none |
| xHCI slot errors | none | yes, in bursts |
| what ulu hears | long, electric distortion | short, quiet crackle |

**The Teufel's fault is now invisible to every observable this computer has.**
Digital stream clean (twice, sample level, with a control window that scored
worse than the report windows). No xrun at the moment of the report. No kernel
message. Nothing left to read.

**Therefore the next instrument is not a counter but a microphone.** ulu has one
on the Scarlett. Recording the room while the bar plays finally captures the
artefact itself instead of its absence everywhere else, and its shape — harmonic
distortion, noise burst, or dropout — says which part of the analog chain to
suspect. That is the first measurement in this whole investigation that looks at
the thing ulu is actually complaining about.

**One mechanism is worth carrying forward, because it reconciles the two
reports.** The Concept 12 receives roughly −64 dBFS at its converter (−38 dBFS
from the game, −26 dB inside the device) and its amplifier makes all of that
back up. Any disturbance is amplified along with it. The same event that is
"short and quiet" on headphones can be "long and electric" through the bar
without being a different event. The level is not the cause — that was tested
and refuted twice — but it is plausibly the amplifier of whatever the cause is.

**Trap, recorded because it cost time twice:** `pkill -f <pattern>` kills the
invoking shell when the pattern appears in its own command line. Both times it
aborted the command that was supposed to restart a monitor, and both times the
monitor was silently gone afterwards. Use `pkill -x <name>`, or check with
`pgrep -a` after.

### Addendum, same night: ulu's observation, and the load hypothesis

Late in the session ulu said he thought we were looking in the wrong place: the
audio faults only ever appear **while a game is open**. That is sharper than
anything measured tonight, and it fits both fault types at once — the xruns
came only under game load, and so did the xHCI bursts. The split into "two
faults on two controllers" may therefore be the wrong axis.

The state during play, checked rather than assumed: GPU at 100 % busy,
`gamemoded` running and reporting active, and PipeWire at `nice 0`,
`SCHED_OTHER`, no realtime priority — competing on equal terms with a game that
is using every core. One cause would then produce both symptoms, because both
are the same thing at different layers: the PipeWire thread scheduled late is an
xrun, the USB driver queueing its packet late is `Frame ID … beyond range`.

**The test ulu runs next (his call, deferred to the morning):** music alone
through the bar for ten minutes, then the same with the game running and its
in-game volume at zero — GPU loaded, no game audio. Crackling in the second case
means system load and nothing to do with the game's audio path; a clean second
case means Wine/Proton's audio path, which is a far smaller target.

If it is the load, the road leads back to realtime priority — the thing `rtkit`
was supposed to deliver and for which it destroyed the session manager. The
alternative that was rejected on 2026-08-01 deserves a second hearing then: a
`limits.d` entry granting the user `rtprio` directly, no daemon in between. It
was rejected for applying to all of ulu's processes and needing a re-login,
which weighs differently after tonight. Not before the test — one screw was
already turned tonight without evidence (`force-quantum`) and it made things
worse.

**A rule from DESIGN.md survived a test it did not ask for.** "Never run the bar
at 100 %" — the sink was at 100 % from 22:28 to 23:18 during this session, to
test the level theory, and ulu reported no change either way. The rule stands on
its 2026-07-31 evidence; tonight neither confirms nor refutes it, and the sink
is back at 37 %.

## 2026-08-03 — two fixes that hold, and a measurement that finally sees the fault

ulu's patience ran out — "ich brauche keine romane, ich brauche einen fix" — so
this entry leads with what changed on the machine and only then explains what
was ruled out.

### The two fixes

**Realtime priority, without rtkit.** `LimitRTPRIO=95` / `LimitMEMLOCK=infinity`
/ `LimitNICE=-19` as a drop-in on `user@.service`. After the relogin: `ulimit -r`
95, `data-loop.0` at `SCHED_FIFO 88` in pipewire and 83 in wireplumber and
pipewire-pulse, `nice -11` on the rest, WirePlumber stable. **FFXIV went from
~1.7 xruns per minute to 2 in eleven minutes.**

`limits.d` cannot do this job and that is not a detail: PID 1 starts the user
manager directly, never through PAM, so `/etc/security/limits.d/` never reaches
`pipewire.service`. The file installed there on this machine has no effect and
`ulutoyon` never entered the `audio` group — the drop-in alone did all the work.

And this is why it does not repeat yesterday's disaster: rtkit demands a finite
`RLIMIT_RTTIME` and the kernel kills any realtime thread that overruns it. Over
plain rlimits PipeWire keeps `rt.time = -1` and that kill path does not exist.

**Headroom for USB audio**, `api.alsa.headroom = 2048`, plus
`api.alsa.disable-tsched = true` and `period-num = 16` (buffer 4096 frames
instead of 768). The ALSA device had been draining to within **6 frames** of
empty (`avail_max 762` of 768).

`api.alsa.period-size` must stay at **256**. Raising it to 1024 made the
crackling instant and continuous, exactly as `clock.force-quantum 1024` had the
day before: FFXIV asks for 256, and the conversion between the two is audible.
Twice reproduced, in opposite directions — this is settled.

### The crackling: solved, and it was the controller

Switched to the Scarlett for an evening and the kernel log answered: 120 entries
of `xhci_hcd 0000:0c:00.0: Frame ID … beyond range`, all on the AMD chipset
controller, all during the crackling. The Concept 12 hangs off the ASMedia
controller and it logged nothing. Since the output went back to the bar ulu
reports no crackling at all — only the distortion. **Audio devices belong on the
ASMedia controller**; the AMD one also carries Bluetooth and the input devices.

### The distortion: what it is not

Each of these was tested with the game running and ulu listening.

- **Not electrical pickup.** Everything muted, converter still running, game
  under load: silence. Nothing to hear.
- **Not a speaker.** A sine played through each of the six drivers in turn,
  eight seconds each: all six clean.
- **Not PipeWire's scheduling.** Zero xruns during it, larger buffer, tsched
  off, CPU affinity keeping the game off the two cores that take the USB
  interrupts (7 and 8 — the first attempt at this test left both of them inside
  the game's mask and was worthless).
- **Not the game's audio stream.** Moved to a null sink; the disturbance stayed.
- **Not the test tone.** It only appears on real material — YouTube, music,
  the Dalamud TTS. FFXIV itself produces almost no sound.

It is load-dependent: with the game closed the tone is clean, with it open it is
not. And ulu's own observation stands, "es fühlt sich so an, dass es irgendwann
aufhört" — the measurement below agrees with him.

### The tooling failure, because it cost the whole evening

`pw-record --target <name>` **silently falls back to the default source** when
it does not like the target. Three separate "paired" recordings were in truth
the same stream twice; one was bit-identical to the monitor's front-left
channel, 14400 of 14400 sampled values. Two conclusions were built on that and
both were wrong: that the microphone was a loopback (it is not — with the output
muted it records ulu's voice at full level), and that the speaker was provably
clean (it was never measured).

Rules from that, now in the probe's docstring: record with **`parec -d`**, and
**verify with `pw-link -l`** that the two recorders sit on different nodes
before trusting a single number. A correlation near 1.0 between "input" and
"output" is not a great result, it is the signature of this bug.

Also: the microphone is on `Mic2`, not `Mic1` — the XLR socket maps to the
second source, and `Mic1` stays at its own noise floor whatever the gain and
phantom power do.

### The measurement that works

`scripts/audio-distortion-probe.py`. Compare the microphone against the digital
signal, not by level — room, distance and gain are unknown — but by the ratio of
high-frequency to low-frequency energy, which those unknowns leave alone and
distortion does not.

Two corrections are what make it work at all. Aligning the two recordings by
cross-correlating their envelopes (−200 ms here, correlation 0.85) took the
spread of the ratio from 14.6 dB down to something usable; without it every
event drowned. And each output level gets its own baseline, because at a quiet
passage the microphone hears mostly the room and the ratio rises for reasons
that have nothing to do with the amplifier.

**The result on 372 seconds with the game running:** ten blocks where the
microphone carries 23 to 35 dB more high-frequency energy than the digital
signal accounts for at that loudness. All ten fall between 129.6 s and 202.7 s —
a 73-second window, with 129 seconds of nothing before it and 168 seconds of
nothing after. ulu had reported "3 oder 4 Vorkommnisse" in that recording.

That is not proof yet; ten events in one window could still be something else in
the room. But the method is reproducible, it runs unattended, and it needs ulu
only to confirm. If the next recordings put the excess in bounded windows again,
the bar is convicted by its own output.

## 2026-08-04 — Obsidian, and the settings question left open on purpose

ulu wants Obsidian in the build. The package part is trivial — it is in the
official `extra` repo (1.13.4), so `packages/apps.txt`, not `aur.txt`.

The part worth recording is what was NOT built. The vault will be a folder
inside one of ulu's own project repos and therefore reaches GitHub on its own;
phoinix does not have to carry it, and a copy on `FilesMusic` would only add a
second source of truth. Obsidian keeps its settings in `.obsidian/` inside each
vault, so ulu asked about sharing one configuration across several vaults — the
usual answer is a central directory with a **directory** symlink into each vault
(a per-file symlink does not survive: configuration files are typically written
to a temporary file and renamed into place, which replaces the link with a real
file).

That mechanism was designed and then dropped, because it would have been built
for a configuration that does not exist: no vault, no plugins, no theme, no
hotkeys as of today. Capturing that would restore an empty directory. It is
revisited when a second vault exists — by then it is knowable which settings
actually want to be shared, instead of guessing now.

`PHOINIX_DATA` was considered and rejected as the home for those settings. That
directory is for what must survive a reinstall and must never be in the repo —
keys, tokens, credentials. Ordinary configuration belongs in the repo, where it
is versioned, seen by `check-drift.sh`, and available on the laptop; the data
disk is desktop-only. Blurring that line costs more than it saves.

So: one package line, one post-install step (open Obsidian once, select the
vault). Same pattern as Brave Sync and the pCloud login.

## 2026-08-04 — GitHub over SSH, and an identity that cannot be forgotten

ulu is starting a second project and asked to automate "the GitHub situation".
The state it replaces: one fine-grained PAT, scoped to `uluToyon/phoinix` alone,
in `$PHOINIX_DATA/git-credentials`, wired repo-locally by stage 3. That token
cannot push anything else, so every new project would have cost a visit to
GitHub, a file on the data disk and a line in the script.

**A key costs nothing per project.** ed25519, no passphrase (ulu's call — the
key file is then the secret, exactly as the token already was, and the restore
stays a single file). It lives beside the VPN configs on the data disk; only the
path is versioned. Comment `uluToyon` rather than ssh-keygen's `user@host`,
because that comment is visible in the key list at GitHub and the machine name
has no business being there.

The host key is pinned in `config.sh` and checked with `ssh-keyscan` before
`known_hosts` is written. Without an entry the first connection asks a question
no unattended install can answer; accepting blindly would throw away the
protection the key exists for.

`IdentitiesOnly yes` is in `dotfiles/ssh_config` for a reason worth keeping:
without it ssh offers every key it can reach and GitHub closes the connection
after a few failures with "Too many authentication failures" — which reads like
a broken key and is not one.

**The second half is the identity, and it is the more valuable one.** Until
today the defence against the 2026-07-31 name leak was a repo-local identity set
by hand in each checkout — the kind of guard that is forgotten on the one
repository where it matters. `~/.config/git/config` now carries no `[user]`
section at all and instead pulls one in conditionally, when a remote points at
ulu's own GitHub account. Both spellings are listed because the condition tests
the URL as WRITTEN, not as `insteadOf` rewrites it.

Verified with four throwaway repositories:

| remote | identity |
|---|---|
| `git@github.com:uluToyon/…` | `uluToyon` |
| `https://github.com/uluToyon/…` | `uluToyon`, and the URL resolves to ssh |
| `https://github.com/fremder/…` | Author identity unknown |
| none | Author identity unknown |

The last two are the point: git refuses the commit rather than inventing an
author. And `git config --global user.name` still answers nothing, so stage 3's
existing warning about a global identity does not start crying wolf — the
conditional include is not evaluated without a repository context.

**Kept, not removed: the PAT.** It is the fallback if a key is ever missing on a
fresh machine, which would otherwise leave no way to push the commits that
record the install. It can be revoked at GitHub once SSH has been trusted for a
while.

**Two existing keys at GitHub, both identified**, neither touched:
`SHA256:wMBJ…SsSk` is the laptop's RSA key — also the one in this desktop's
`authorized_keys`, so it has a second job and stays. `SHA256:z9vR…3tt4` is this
desktop's OLD ed25519 key; its private half survives only by accident, in the
rescue snapshot of 2026-08-01, and nothing on the machine uses it. It is what
the new key replaces and can be deleted once SSH has proven itself — the rescue
copy with it.

## 2026-08-04, later — the housekeeping, and one drift that mattered

Four open items closed, one still waiting on ulu.

**The LAN DNS drop-in was finally installed**, three days after stage 3 learned
to write it. The prediction in STATUS.md had held to the letter: `fritz.box` was
answering `212.42.244.122`, a stranger's host on the public internet, because
Quad9 answers for that domain and the wired link holds the DNS default route.
After the drop-in it resolves to `192.168.178.1` in 646 µs instead of 9.2 ms —
the latency alone shows the answer now comes from the cable rather than from
Frankfurt. Public names still leave through Quad9 with `+DNSOverTLS` on the
link, so the split is intact.

**A drop-in the repo never received.** `system/wireplumber/50-phoinix-usb-headroom.conf`
was committed in its first form (headroom 2048) and then changed three more
times live — `disable-tsched`, `period-size 256` with `period-num 16`, headroom
1024 — without ever being written back. A fresh install would have got the wrong
audio configuration. Worth noting how it was found: NOT by `check-drift.sh`,
which only walks the captured files under `hosts/*/home/`. A file the repo owns
and installs is outside its reach. That is a gap in the drift check, not a
mistake it made.

**The old desktop SSH key is gone from the data disk.** `rescue/ssh/id_ed25519`
and its public half, fingerprint `SHA256:z9vR…3tt4`, deleted; `authorized_keys`
and `known_hosts` left alone. The fingerprint still appears in an old Claude
transcript inside `rescue/claude/` — that is the public identifier, and the file
was checked for private key material: none. The entry at GitHub is ulu's to
remove.

**Left open on purpose: the soundbar volume.** `check-drift.sh desktop` reports
8 in sync, 2 drifted. One difference is real — `default-routes` has the Concept
12 at `0.050120` in the repo and `0.032770` live, that is 37 % / −26.0 dB
against 32 % / −29.7 dB. The documented value is 37 %, in `SETTINGS.md` and as a
rule in `DESIGN.md`. This is precisely the case the drift check's own warning
names ("that is how the soundbar lost 2.77 dB without anyone noticing"), so it
is not resolved by picking a side quietly: ulu decides whether the 32 % were
intended. The other difference, the order of preferred sinks in `default-nodes`,
is fallout from switching outputs during yesterday's measurements and goes back
either way — both live in the same two files, so they get touched once.

**Resolved the same evening: the volume was a test leftover, ulu's call.** Set
back to 37 %, and the two state files restored from the repo with WirePlumber
stopped — it owns them at runtime and would have written its own version back
on exit. The sink now reads exactly −26.00 dB rather than the −25.91 that
`pactl … 37%` produces, because the stored value is the one the repo carries.
`check-drift.sh desktop`: **10 in sync, 0 drifted, 0 missing, 1 expected to
differ.**

## 2026-08-04, still later — the drift check learns about the repo's own files

`check-drift.sh` walked the CAPTURED tree under `hosts/<host>/home/` and nothing
else. Everything the repo authors and pushes out — both audio drop-ins, the
dotfiles, the NetworkManager and nftables stanzas, the new realtime drop-in —
was outside its reach. That gap cost something the same day: the USB audio
drop-in had been changed three times live and never written back, and the check
reported "10 in sync" while a fresh install would have received the wrong
configuration.

Now it also compares a table of repo-owned destinations, and separates the ones
installed through a substitution — nftables.conf, the desktop files, the user
units — where bytes cannot match by design and only presence is worth checking.

**The table has a guard against itself.** A list maintained by hand rots the
moment someone adds a file, which is precisely the failure being fixed. So the
script greps the stages for every `$REPO_DIR/{system,dotfiles,plasma}/…` they
reference and reports anything not in the table. Adding a file to stage 3 and
forgetting this script now shows up as an error rather than as silence.

**It found something on its first run**: 17 files instead of 10, and one drift.
`/etc/NetworkManager/conf.d/10-phoinix-dns.conf` still carried the rationale
from before 2026-08-01 — "while the tunnel is up it is authoritative" — the
explanation that turned out to be the bug, the one that had the whole desktop
resolving through Proton. The effective setting is identical on both sides,
`dns=systemd-resolved`. Only the reasoning differs, and in a repo whose premise
is that the reasoning is the valuable part, that is worth correcting rather than
shrugging at.

**The old desktop key is fully retired (2026-08-04).** Deleted from the rescue
directory and from GitHub, and authentication re-tested afterwards: still "Hi
uluToyon!". Only two keys remain in the account — the laptop's RSA key, which
also lives in this desktop's `authorized_keys` and therefore has a second job,
and the new `phoinix-desktop` key that stage 3 can restore from the data disk.

**And REINSTALL.md had to be corrected the same day.** It still told a human to
restore `~/.ssh/id_ed25519` from the rescue directory — the file deleted hours
earlier — so the checklist would have failed at exactly the point it exists for.
Its claim that "nothing restores `~/.ssh`" is also no longer true: stage 3 does,
for the GitHub key. Replaced with what actually happens now, plus a one-line
verification (`ssh -T git@github.com` must answer "Hi uluToyon!") that proves
key, permissions, host pin and identity rules together.

Recorded while checking: **the repository is public.** Verified from outside the
checkout with global and system git config disabled and prompts off —
`git ls-remote https://github.com/uluToyon/phoinix` answers. So bootstrap's
clone never needed a credential at all, and the PAT's only remaining job is a
fresh machine whose key is missing from the data disk.

## 2026-08-04, end of day — the token is gone, and the reason it was worth losing

ulu's call, against the recommendation to keep it until after the next reinstall.
He was right, and the argument only became visible while carrying it out: **the
token lived on the same data disk as the key.** The failure it was supposed to
cover — a fresh machine that cannot push — is in practice "the data disk is not
there", and that took both at once. The only case it genuinely covered was a key
that had gone missing by itself while its neighbour survived. Two permanent
secrets for one job, the second protecting almost nothing.

Checked rather than assumed, and it removes the other half of the argument:
**the repository is public.** `git ls-remote https://github.com/uluToyon/phoinix`
answers from outside the checkout with global and system git config disabled and
prompts off. Bootstrap's clone never needed a credential at all.

Removed: the file on the data disk, the repo-local `credential.helper` on the
live checkout, `GIT_CREDENTIALS_FILE` and its rationale from `config.sh`, the
wiring block from stage 3, and the rows in `SETTINGS.md`, `STATUS.md` and
`REINSTALL.md`. The stage-3 and config comments are replaced by a note of what
stood there and why it went, so nobody reinvents it in six weeks.

One contradiction fell out of it that had nothing to do with the token.
`REINSTALL.md` argued that a private key "must not be moved around by an
installer that also runs unattended in a VM" — written when the only key was a
rescue snapshot. It no longer holds: the GitHub key has a declared home in
`config.sh`, exactly like the VPN configs the same installer has always placed,
and a VM run finds nothing there and says so. Restoring a key from a hand-made
snapshot is what must stay manual; placing a key the repo knows about is
ordinary stage-3 work.

## 2026-08-06 — "zu 100%, nicht 99,9%": the two gaps, and one wrong turn

ulu asked for the split tunnel to be verified in both directions, then — after
the answer named three gaps — for them closed. This is what was measured, what
was built, and what was built wrong first.

### The verification

Both directions hold, and the evidence is the egress rather than anything the
machine says about itself: a process in `vpnonly` leaves as `62.169.136.42`
(Proton CH), everything else as `92.208.160.100`. The default route is the LAN;
the tunnel's default lives only in table 51, which is unreachable without the
mark. `mark_out` had marked 2 971 108 packets, the WireGuard exemption 2 973 368,
and the drop rule had fired 8 times at 80 bytes each — IPv6 attempts from the
group, which has no IPv6 route in the tunnel and therefore may not leave at all.

**One false alarm, mine.** `curl` reported a connection "from 192.168.178.23"
and I called it a leak before checking. That is the LOCAL socket address, which
the kernel picks at `connect()` from the main table — before the output hook
marks anything. It says nothing about the path the packet takes. The counters
and the egress address said so; the socket did not.

### Gap one: execution by name

The desktop entry was covered (same file name as the packaged one, so menu,
KRunner and magnet links all reach the launcher) and stage 3 defines a shell
alias — but an alias exists only in an interactive zsh. bash, a script, `sh -c`
or a unit all found `/usr/bin/qbittorrent` and started a client in ulu's
ordinary groups, with no kernel rule matching it. Closed with a wrapper at
`~/.local/bin/qbittorrent`, which comes first in PATH. The launcher's last line
had to become an ABSOLUTE path in the same breath, or the two would call each
other forever.

### Gap two: the names, and the wrong turn

The traffic went through the tunnel; the lookups did not. qBittorrent asks the
systemd-resolved stub like every program, and resolved — not in the group — then
asked Quad9 over the ordinary line, so every tracker name was visible there.

**The first attempt was wrong and broke resolution for the group entirely.** A
nat chain rewrote the group's DNS destination straight to `10.2.0.1`, the
resolver inside the tunnel. It cannot work: a query addressed to `127.0.0.53`
has already been given `127.0.0.1` as its SOURCE before any rule runs, and the
kernel will not route a loopback sender out of a real interface. A `masquerade`
in postrouting was added to correct it and is too late by construction — the
routing decision has happened by then. **Netfilter cannot change a source
address before routing**, so no arrangement of rules fixes this. Reverted the
same hour.

Worth keeping: it failed CLOSED. Nothing went out the wrong way; nothing went at
all.

**What works is loopback to loopback.** `dns_out` now rewrites `127.0.0.53` to
`127.0.0.61`, where a dnsmasq listens that runs with `vpnonly` as its group. The
packet never leaves the machine, so nothing is rerouted and nothing is martian.
The forwarder's own query to `10.2.0.1` gets a proper source, is marked by
`mark_out` like everything else from the group, and goes through the tunnel.
Matching the stub address exactly also keeps the forwarder's upstream traffic
out of the rule, which would otherwise rewrite its way back to itself.

Two details that cost a round each:

- `127.0.0.54` is already taken — systemd-resolved's bypass stub listens there.
- **`--no-daemon` is dnsmasq's debug mode and disables the user and group switch
  outright.** With it, dnsmasq stayed root, its queries were never marked, and
  every lookup in the group timed out. `--keep-in-foreground` is the flag
  systemd wants: foreground, but still drops privileges.

`--no-resolv` is load-bearing in the unit. Without it dnsmasq reads
`/etc/resolv.conf` and would answer over the ordinary line the moment the tunnel
dropped — a closed failure turned into a silent leak.

### Verified afterwards

`dns_out` fired on every lookup from the group; `mark_out` kept counting; the
drop rule stood at 0. Resolution from the group works and carries tunnel
latency, and it works only because `10.2.0.1` answered — an address reachable
through the tunnel and nowhere else. Egress unchanged in both directions.

### What is still not "100 %"

The guarantee is that a rule MATCHES a property of a socket, not that a path is
absent. A network namespace with the tunnel as its only interface would replace
the match with an absence, and that is the honest next step if the bar stays
where ulu put it. It costs NetworkManager's management of the tunnel, a
privileged launch, and the GUI across a namespace boundary. Not started.

## 2026-08-06, later — the namespace: from "the rule catches it" to "there is no way out"

ulu read the honest limit of the previous section — the guarantee is a rule
matching a socket's group, not the absence of a path — and said: then build the
namespace. This is that.

**The construction.** A network namespace `vpn` whose only interfaces are `lo`
and `proton0`. The ordinary line is not forbidden in there; it does not exist.
The one thing that makes it possible: a WireGuard device keeps its encrypted
socket in the namespace it was CREATED in, and keeps it when moved. So the
interface is created in the root namespace — where the normal line is, and where
the ciphertext has to go out — and then moved inside. Plaintext lives in the
namespace, ciphertext leaves over enp8s0. Built the other way round the tunnel
could not reach its own endpoint, which is the trap this design is named for.

**DNS solved itself.** `ip netns exec` bind-mounts everything in
`/etc/netns/<ns>/` over its counterpart in `/etc`, so a `resolv.conf` in there
naming only `10.2.0.1` is the only resolver anything inside can see. The dnsmasq
forwarder built two hours earlier is redundant on this path — and is kept as the
backstop for a qBittorrent that is not in the namespace.

**Entering costs root, and that is the only privileged part.**
`/usr/local/sbin/phoinix-qbt-netns` does three things: check the namespace is
there, enter it, `setpriv` straight back to `ulutoyon:vpnonly`, exec qBittorrent.
`setpriv` rather than `runuser` or `su` because it changes credentials and
nothing else — no PAM session, no shell, no environment rewriting, which is what
a GUI needs. The sudo rule is passwordless for that one command; a launcher that
stops to ask is a launcher that gets bypassed. `env_keep` is scoped to that
command and lists only display and bus variables — nothing that could steer the
root half.

**NetworkManager had to give up the tunnel**, because it cannot follow an
interface into a namespace. Nothing was lost functionally: the tunnel served
only qBittorrent anyway. What was lost is the applet click for switching
country, replaced by `scripts/vpn-switch.sh <host> ch|nl` — a symlink at
`$VPN_CONFIG_DIR/active.conf` and a restart. The profiles stay with
`autoconnect no`, as a record and as a way back.

**Verified end to end on the live machine.** Inside the namespace: egress
`62.169.136.42` (Proton), exactly one route (`default dev proton0`), and name
resolution working through `10.2.0.1`. qBittorrent afterwards:
`ip netns identify` says `vpn`, its net namespace inode differs from the
session's, it runs as `ulutoyon:vpnonly`, and `ss` inside the namespace shows an
established connection with local address `10.2.0.2` — the tunnel address.

**One thing the drift check had to learn.** `/etc/sudoers.d` is `0750 root:root`,
so a normal user cannot stat what is inside it and `! -e` called a present file
missing. It now reports "not readable without root" instead — an unverifiable
check must not look like a passing one.

**What is left, honestly.** A namespace is not a proof against a kernel bug or a
process with CAP_SYS_ADMIN. It removes the entire class of "a rule failed to
match", which is what was asked for, and that is the accurate claim.

## 2026-08-06, evening — the namespace removed, and what it cost to learn that

ulu: "mir gefällt die gesamte implementierung des split tunnels nicht. keine gui
funktionen, kein feedback, keine steuerung." He was right, and the fault is in
how the change was proposed, not only in the change.

**The estimate was wrong.** When the namespace was offered, its price was
described as "one click for switching country". It was in fact the tray icon
that says whether the tunnel is up, the toggle, the country switch, and
`proton0` being visible to ordinary network tools at all — which is why the only
thing ulu could see while torrenting was traffic on the wired connection. That
traffic was the tunnel's own ciphertext and entirely correct, but there was no
way for him to see that without typing a command. A guarantee he has to be told
about is worth less than one he can watch.

**The trade, stated properly:** the namespace buys the last sliver — removing
the class "a rule failed to match" — and costs all of the operability. That is
not a technical call, it is ulu's, and he should have been given it in those
terms. Reverted.

**What was kept**, because it closed real gaps and is independent of the
namespace: the dnsmasq forwarder that carries the group's name lookups through
the tunnel, the PATH wrapper that catches execution by name, and the launcher's
preconditions.

**One defect surfaced during the revert and is now fixed.** The forwarder does
not survive the tunnel being rebuilt: its upstream socket is bound while the
tunnel is up and stale afterwards, and dnsmasq does not notice. Measured — three
of four lookups timed out after the reconnect until the service was restarted by
hand. That matters far more here than it looks: the applet is the whole reason
this arrangement was chosen, so a construction that breaks name resolution every
time ulu uses it is a trap rather than a design. A NetworkManager dispatcher now
restarts the forwarder whenever `proton0` changes state, verified by toggling the
connection and watching the service's start timestamp move.

**Verified after the revert**, all of it: group egress `62.169.136.42` (Proton),
ordinary egress `92.208.160.100`, name resolution from the group at tunnel
latency and working immediately after a reconnect, nftables loaded, forwarder
running as `dnsmasq:vpnonly`, PATH wrapper in place, `check-drift.sh` at 18 in
sync and 0 drifted.

**The lesson worth keeping** is not about namespaces. A change that removes a
control the user relies on has to be presented as removing it, in the sentence
that asks for permission — not discovered afterwards.

## 2026-08-06, night — mpc-qt: the documented cure does not work on Wayland

ulu: "mpc-qt startet nicht." The state matched `aur.txt` exactly —
`settings.json` present, `geometry_v2.json` missing, plus a stale lock from the
crashed run. Reproduced: exit 139, and `coredumpctl` put the crash in
`QScreen::availableGeometry()` straight out of `main`, as documented.

**But the cure in that note is wrong for this machine.** It says to remove
`settings.json` and let a clean run write the profile. The clean run crashes as
well: mpc-qt 26.07 cannot bootstrap its own profile under Wayland at all, dying
before it writes `geometry_v2.json` and leaving exactly the broken state behind.
Tested with the config directory completely empty — same crash.

**What works is one run over XWayland.** `QT_QPA_PLATFORM=xcb` starts, and that
run writes all five missing files. Afterwards the ordinary Wayland start works
again, verified by running both platforms before and after:

| | empty profile | complete profile |
|---|---|---|
| Wayland | crash (139) | runs |
| XCB | runs | runs |

So the fault is not Wayland as such — it is that the bootstrap needs a screen
query that only succeeds under XCB, and once `geometry_v2.json` exists nothing
asks it again.

**A misstep of mine worth recording**: I deleted `settings.json` on the strength
of the old note before establishing that the note applied. It was backed up
first and restored byte-identical, so nothing was lost — but the backup was the
only reason. Copy before deleting, then diagnose.
