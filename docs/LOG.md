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
