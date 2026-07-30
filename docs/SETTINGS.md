# Settings inventory

Every setting phoinix puts on a machine, where it is written, and where it came
from. This is the document to read when something on the desktop behaves in a
way you did not expect, or when hopping to another distro and asking "what did
I actually have configured?".

`LOG.md` holds the *rationale* — this file holds the *inventory*. When they
disagree, the scripts win; this file is a map, not a source.

## Origin column

| Mark | Meaning |
|------|---------|
| **old** | carried over from the pre-phoinix installation (captured file) |
| **dec** | deliberately decided during a phoinix session, written by a script |
| **std** | Arch/KDE default, listed only because it matters and is easy to miss |

## How a setting gets onto the machine

Four mechanisms, in the order they run:

1. **Config variables** (`config.sh`, `hosts/<host>/config.sh`) — values the
   stage scripts read. No machine-specific value belongs in a stage script.
2. **Files written by a stage script** — `/etc` bits, boot entry, unit files.
3. **`kwriteconfig6` calls in stage 3** — the KDE settings we decide
   deliberately. Each one carries its reason as a comment next to it.
4. **Captured files** in `hosts/<host>/home/` and `dotfiles/` — reserved for
   what cannot sensibly be authored by hand: `kwinoutputconfig.json` (keyed by
   EDID hash), the wireplumber state, `p10k.zsh`.

Anything Plasma only accepts while its shell is running is stage 4, not 3.

---

## Stage 1 — disk (on the ISO)

| Setting | Value | Origin |
|---|---|---|
| Target disk | `DISK` in `hosts/<host>/config.sh`, by `/dev/disk/by-id/` | dec |
| Partition layout | ESP 1G (`ef00`) \| root 200G (`8304`) \| home rest (`8302`) | dec |
| Filesystems | FAT32 `EFI`, ext4 `archroot`, ext4 `archhome` | dec |
| Data disks | mounted by label under `/mnt/<Label>`, **never formatted** | dec |
| Data disk fstab options | `nofail,x-systemd.device-timeout=30s` | dec |
| Confirmation | disk **serial** must be typed, not `y/N` | dec |

ESP is 1G rather than 512M because several kernels plus fallback initramfs
outgrow the smaller size. The 30s device timeout is not cosmetic: 5s silently
dropped all three SATA disks on first boot.

## Stage 2 — base system (in the chroot)

| Setting | Value | Origin |
|---|---|---|
| Timezone | `Europe/Berlin`, hwclock to RTC | old |
| Generated locales | `en_US.UTF-8` **and** `de_DE.UTF-8` | dec |
| `/etc/locale.conf` | `LANG=en_US.UTF-8` — UI language | dec |
| Console keymap | `KEYMAP=de` | old |
| X11/Wayland layout | `de`, variant **`nodeadkeys`** | dec |
| Hostname | `archlinux`, plus matching `/etc/hosts` | old |
| pacman | `[multilib]` enabled, `Color`, `ParallelDownloads = 5` | dec |
| zram | `ram / 2`, zstd — instead of a swap partition | dec |
| User | `ulutoyon`, group `wheel`, login shell `/usr/bin/zsh` | dec |
| sudo | `%wheel ALL=(ALL:ALL) ALL` in `/etc/sudoers.d/10-wheel` | dec |
| Global zshrc | `compinit`, history 10000, emacs bindings | dec |
| Empty user `~/.zshrc` | suppresses `zsh-newuser-install` | dec |
| SSH | `authorized_keys` from `hosts/<host>/` | dec |
| Services | `NetworkManager`, `sshd` | dec |
| Bootloader | systemd-boot, `default arch-zen.conf`, `timeout 3` | dec |
| Kernel arg | `video=DP-2:3840x2160@144` — monitor bug | dec |
| Kernel arg | `video=DP-1:3440x1440@144` — link stability, **PROVISIONAL** | dec |
| etckeeper | `/etc` under git, persistent identity `etckeeper` | dec |

**The variant belongs in both places.** The login greeter has no user `kxkbrc`
and falls back to the X11 system config written here. Without the variant the
password would be typed on a dead-key layout, in a session that has none.

**Microcode is loaded, but not the way DESIGN.md expects.** The boot entry has
no `initrd /amd-ucode.img` line. It does not need one: Arch's default
`mkinitcpio.conf` carries a `microcode` hook that embeds it in the initramfs,
and the journal confirms an early update (`Updated early from: 0x0a601209`).
Do not "fix" this by adding the line — it would be redundant. `amd-ucode` is
in `pacstrap.txt`, which is what actually matters.

## Stage 3 — user system (first boot, unprivileged)

Packages, `paru` (built from source), DZGUI, then:

### Captured files, installed from the repo

| File | Content | Origin |
|---|---|---|
| `.config/kwinoutputconfig.json` | monitor layout, modes, HDR, VRR, priorities | old |
| `.config/kwinrc` | see table below | old |
| `.config/kdeglobals` | see table below | old |
| `.config/pipewire/pipewire.conf.d/10-clock.conf` | graph pinned to 48 kHz | old |
| `.local/state/wireplumber/*` | 5.1 profile pin, the −26 dB route fix | old |
| `.zshrc`, `.p10k.zsh` | zinit bootstrap, 9 plugins, tuned prompt | old |

The greeter gets its own copy of `kwinoutputconfig.json` — without it the first
login screen goes black, and the per-output `priority` in that file is also what
puts the password field on the main monitor instead of the TV.

Only the PipeWire **drop-in** is carried, never `pipewire.conf` itself: a file
of that name in `~/.config/pipewire/` shadows the packaged one completely.

### Written explicitly (`kwriteconfig6`)

| File | Key | Value | Meaning | Origin |
|---|---|---|---|---|
| `kscreenlockerrc` | `Daemon/Autolock` | `false` | no screen locking | dec |
| `kscreenlockerrc` | `Daemon/Timeout` | `0` | or the KCM shows a stale idle time | dec |
| `kxkbrc` | `Layout/Use` | `true` | Plasma applies its own layout | dec |
| `kxkbrc` | `Layout/LayoutList` | `de` | | dec |
| `kxkbrc` | `Layout/VariantList` | `nodeadkeys` | no dead keys | dec |
| `kcminputrc` | `Keyboard/NumLock` | `0` | **on** at session start | dec |
| `powerdevilrc` | `AC/Display/DimDisplayWhenIdle` | `false` | never dims | dec |
| `powerdevilrc` | `AC/Display/TurnOffDisplayWhenIdle` | `false` | never blanks | dec |
| `powerdevilrc` | both `…IdleTimeoutSec` | `-1` | timeouts disabled | dec |
| `powerdevilrc` | `AC/SuspendAndShutdown/AutoSuspendAction` | `0` | never suspends | dec |
| `powerdevilrc` | `AC/SuspendAndShutdown/PowerButtonAction` | `8` | **shut down** | dec |

`NumLock=0` and `PowerButtonAction=8` are KDE enum values compiled into the
binaries and not readable from the system. Both were confirmed against the GUI
selection, not guessed.

### Other stage-3 settings

| Setting | Value | Origin |
|---|---|---|
| Shell aliases | `nano`→`micro`, `yay`→`paru` (appended, idempotent) | dec |
| `environment.d/10-phoinix-locale.conf` | `LANG` + nine `LC_*` on `de_DE.UTF-8` | dec |
| `plasma-localerc` | the same, so the KCM shows the truth | dec |
| Deliberately **not** set | `LC_MESSAGES` (would translate the UI), `LC_COLLATE` (would change shell globs and `sort`) | dec |
| Default PDF handler | `brave-browser.desktop` | dec |
| Services | `bluetooth`, `cups`, `power-profiles-daemon` | dec |
| Stage-4 unit | rendered + symlinked into `plasma-workspace.target.wants` | dec |
| plasmashell drop-in | `After=` kwin, `TimeoutStopSec=10s` — 40s shutdown hang | dec |
| Graphical login | enabled **last**, after everything above exists | dec |

## Stage 4 — inside the running Plasma session

Fires once, guarded by `~/.local/state/phoinix/stage4.done`.

| Setting | Value | Origin |
|---|---|---|
| Panels | rebuilt from scratch: main panel, TV clone, two clock strips | dec |
| Main panel height | `PANEL_MAIN_HEIGHT=46` | dec |
| Side strips | `DP-2:55`, `DP-3:36` | dec |
| Pinned launchers | Konsole, Dolphin, Brave, KeePassXC, Strawberry, Discord, qBittorrent | dec |
| Kickoff favourites | browser, System Settings, Dolphin | dec |
| Pointer acceleration | **flat profile on every pointer that supports it** | dec |
| Final step | `systemctl --user restart plasma-plasmashell.service` | dec |

**Pointer acceleration is a rule, not a device setting.** This is a gaming PC,
so no mouse gets acceleration — the profile is applied to *every* pointer KWin
reports, not to one chosen device. That is also the only way to script it
cleanly: KDE stores the profile per device in a group built from vendor id,
product id and device name (`[Libinput][13364][53321][Keychron Keychron M6 8K]`).
Writing that literally would put three discovered identifiers in the repo,
cover exactly one mouse, and silently do nothing after a mouse change. Stage 4
asks KWin at runtime instead and sets the D-Bus property; KWin builds the group
name and persists it to `kcminputrc` on its own.

Screens are matched by **geometry**, never by index — Plasma numbers screens in
detection order. A disconnected monitor yields `-1` and its panel is skipped
instead of landing on the wrong screen. Widgets are addressed by **type**,
never by id: applet numbers and the activity UUID are regenerated per install.

The default launcher list and the default Kickoff favourites both ship entries
for Discover and Kontact, neither of which is installed here. Writing both keys
explicitly is what retires those defaults — they live compressed inside the
applet's Qt resource and cannot be patched any other way.

---

## What the captured KDE files actually contain

### `kwinrc` — six blocks, nothing more

| Entry | Meaning | Origin |
|---|---|---|
| `Compositing/VrrPolicy=1` | Adaptive Sync = **Automatic** | old |
| `EdgeBarrier/EdgeBarrier=0`, `CornerBarrier=false` | pointer resistance at screen edges and corners **off** | old |
| `Effect-overview/BorderActivate=9` | Overview triggered by **no** screen corner (9 = none) | old |
| `Desktops/*` | one virtual desktop, one row, plus its UUID | old |
| `Tiling/*` ×4 | custom 25/50/25 tile layout, padding 4, one per screen | old |
| `Xwayland/Scale=1` | no scaling for X11 apps | old |

### `kdeglobals`

| Entry | Meaning | Origin |
|---|---|---|
| `KDE/AnimationDurationFactor=0` | **all animations off** | old |
| `KDE/LookAndFeelPackage` | `org.kde.breezedark.desktop` | old |
| `KDE/contrast=4`, `frameContrast=0.2` | UI contrast strength | old |
| `General/BrowserApplication` | `brave-browser.desktop` | old |
| `Sounds/Enable=false` | **system sounds off** | old |
| `PreviewSettings/*` | no thumbnails for remote folders | old |
| `KFileDialog Settings/*` | detail-tree view, sorting, sidebar width 140, hidden files off | old |
| `Colors:*`, `ColorEffects:*`, `WM/*` | the Breeze Dark scheme written out — a block, not individual choices | old |

---

## Known gaps and open items

- **`kglobalshortcutsrc` is not managed.** Custom KDE shortcuts (including
  Spectacle) are still to be configured, then captured.
- **`kwinoutputconfig.json` is a provisional state**, carrying the 144 Hz
  experiment on DP-1. See `STATUS.md`.
- **Console keymap has no variant.** `KEYMAP=de` means the text console keeps
  dead keys while X11 and Plasma do not. Deliberate for now — on the vconsole
  the no-dead-key layout is a different keymap *name* (`de-latin1-nodeadkeys`),
  not a variant. Change it only if the console ever starts mattering.
- **`~/.config/pipewire/pipewire.conf` on the live system** is a stale copy
  shadowing the packaged config. Excluded from the repo; deleting it on the
  live machine is still pending.
