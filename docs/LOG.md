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
