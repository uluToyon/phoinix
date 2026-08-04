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
| Mirrorlist | `reflector --country Germany --protocol https --age 12 --latest 20 --sort rate` | dec |

**The mirrorlist is sorted BEFORE pacstrap, and that position is the point.**
pacstrap copies the ISO's `/etc/pacman.d/mirrorlist` into the new system, so one
sort pays twice: for the ~1 GB pacstrap pulls, and for everything stage 3
installs later. Guarded on both ends — no reflector on the ISO, or a failed run,
falls back to the ISO's own list with a message instead of aborting an install
over a download speed. `MIRROR_COUNTRY` lives in `config.sh`.

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
| Services | `NetworkManager`, `sshd`, plus `nftables` + `systemd-resolved` on a VPN host | dec |
| Group `vpnonly` | system group, ulu is a member. Owns no files, has no sudo rights — it exists solely to be matched in the nftables output chain | dec |
| `/etc/nftables.conf` | two chains: mark the `vpnonly` group in **output** (`type route`), drop it in **postrouting** if it did not leave via `proton0`. Policy stays `accept`, so this is **not** an input firewall | dec |
| nftables drop-in | `RemainAfterExit=yes` — without it the unit reports inactive while its rules are loaded, and the qBittorrent launcher refuses forever | dec |
| DNS | `systemd-resolved`, NM set to `dns=systemd-resolved`, `/etc/resolv.conf` → stub | dec |
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

**udev rules for the Keychron devices** (`system/udev/` → `/etc/udev/rules.d/`,
decided 2026-07-31). Two files, split by provenance so the vendored one can be
refreshed without losing our edit:

| File | Covers | Origin |
|---|---|---|
| `50-qmk.rules` | bootloader ids while FLASHING (Atmel DFU, Caterina, STM32, …) | vendored from qmk_firmware, minus upstream line 71 |
| `51-keychron-launcher.rules` | raw HID of the RUNNING devices, for launcher.keychron.com | ours, one rule |

Both grant through `TAG+="uaccess"`, so logind puts an ACL on the node for the
holder of the active local session — no group, no world-readable device, access
ends at logout. Ours matches by VENDOR (`ATTRS{idVendor}=="3434"`), found on the
USB parent, so a third Keychron device needs no rule change. Upstream line 71
was dropped deliberately: it was a catch-all over *every* hidraw device on the
machine and named `GROUP="plugdev"`, which does not exist on Arch. The other 32
upstream rules use `uaccess` correctly and were kept — ulu does flash firmware.

Both devices are used WIRED here without exception (ulu). Over the 2.4 GHz
dongle the keyboard may enumerate under a different id and would need its own
line; over Bluetooth the launcher cannot reach it at all.

## Stage 3 — user system (first boot, unprivileged)

Packages, `paru` (built from source), DZGUI, then:

### Captured files, installed from the repo

| File | Content | Origin |
|---|---|---|
| `.config/kwinoutputconfig.json` | monitor layout, modes, HDR, VRR, priorities | old |
| `.config/kwinrc` | see table below | old |
| `.config/kdeglobals` | see table below | old |
| `.config/pipewire/pipewire.conf.d/10-clock.conf` | graph pinned to 48 kHz | old |
| `.local/state/wireplumber/*` | 5.1 profile pin, the −26 dB route volume. **Corrected 2026-08-01:** the sink carries `HW_VOLUME_CTRL`, so this is the *device's own* volume, not a digital attenuation — what phoinix puts on the wire is untouched by it (measured peak −20.5 dBFS during a game) | old |
| `.zshrc`, `.p10k.zsh` | zinit bootstrap, 9 plugins, tuned prompt | old |

The greeter gets its own copy of `kwinoutputconfig.json` — without it the first
login screen goes black, and the per-output `priority` in that file is also what
puts the password field on the main monitor instead of the TV.

Its config directory holds a second file, `kcminputrc`, written key by key in
the same loop (see the NumLock rows below). Anything the greeter needs lands in
`/var/lib/plasmalogin/.config/`, owned by the greeter user — stage 3 creates
that directory explicitly, because `install -D` would make it `root:root` and
the greeter could then not be written for as itself.

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
| `kcminputrc` (greeter home) | `Keyboard/NumLock` | `0` | **on** at the login screen | dec |
| `powerdevilrc` | `AC/Display/DimDisplayWhenIdle` | `false` | never dims | dec |
| `powerdevilrc` | `AC/Display/TurnOffDisplayWhenIdle` | `false` | never blanks | dec |
| `powerdevilrc` | both `…IdleTimeoutSec` | `-1` | timeouts disabled | dec |
| `powerdevilrc` | `AC/SuspendAndShutdown/AutoSuspendAction` | `0` | never suspends | dec |
| `powerdevilrc` | `AC/SuspendAndShutdown/PowerButtonAction` | `8` | **shut down** | dec |
| `kglobalshortcutsrc` | `mediacontrol/{next,playpause,previous,stop}media` | `none` | media keys left to Strawberry | dec |
| `kglobalshortcutsrc` | `services/org.kde.spectacle.desktop/_launch` | `Print` | `Meta+Shift+S` removed here… | dec |
| `kglobalshortcutsrc` | `…/RectangularRegionScreenShot` | `Meta+Shift+S⇥Meta+Shift+Print` | …and added here | dec |

**Shortcuts: only the deviations, never the whole file.** `kglobalshortcutsrc`
is ~275 lines of largely untouched defaults and contains a
`switch-to-activity-<UUID>` entry whose id is regenerated on every install — a
wholesale capture would carry a dead reference into the repo. It also makes the
extraction easy: entries are `key=active,default,friendly`, so the file states
its own defaults and "what was actually changed" stays computable without a
before/after snapshot. Service entries are the exception, using plain
`key=shortcut`; multiple shortcuts are TAB-separated (escaped `\t`).

Deliberately left at their defaults in `mediacontrol`: `pausemedia` and both
seek shortcuts — they do not collide with Strawberry.

`NumLock=0` and `PowerButtonAction=8` are KDE enum values compiled into the
binaries and not readable from the system. Both were confirmed against the GUI
selection, not guessed.

### Application settings (stage 3)

| Application | File | Key | Value | Origin |
|---|---|---|---|---|
| Dolphin | `~/.local/share/dolphin/view_properties/global/.directory` | `Settings/HiddenFilesShown` | `true` | dec |
| Dolphin | `dolphinrc` | `General/GlobalViewProps` | `true` | dec |
| Konsole | `~/.config/autostart/org.kde.konsole.desktop` | — | starts at login | dec |
| Strawberry | `~/.config/autostart/…strawberry.desktop` | — | starts at login | dec |
| Strawberry | `strawberry.conf` | `Backend/channels_enabled` | `true` | dec |
| Strawberry | `strawberry.conf` | `Backend/channels` | `6` — stereo→5.1 **in the player only** | dec |
| Strawberry | `strawberry.conf` | `PlaylistSequence/shuffle_mode`, `repeat_mode` | `1` (shuffle all), `3` (repeat playlist) | dec |
| Strawberry | `strawberry.conf` | `MainWindow/do_not_show_sponsor_message` | `true` — otherwise shown on **every** start | dec |
| KeePassXC | `~/.config/autostart/…KeePassXC.desktop` | — | starts at login, **visible**, not minimised to tray | dec |
| KeePassXC | `keepassxc.ini` | `Browser/Enabled` | `true` | dec |
| KeePassXC | `keepassxc.ini` | `GUI/ApplicationTheme` | `dark` | dec |
| KeePassXC | `keepassxc.ini` | `GUI/TrayIconAppearance` | `monochrome-light` | dec |
| KeePassXC | `keepassxc.ini` | `Security/LockDatabaseIdle` | `false` — **deliberate**, single-user machine | dec |
| KeePassXC | `~/.cache/keepassxc/keepassxc.ini` | `General/Last*Database*` | `KEEPASS_DB`, seeded only when absent | dec |

**`keepassxc.ini` is never captured whole.** KeePassXC writes a KeeShare RSA
**private key** plus signer name into it the first time that settings page is
opened — used or not, and here it is not (the share list is empty). Individual
keys only; `[KeeShare]` is never touched.

**The database preselection is seeded state, on purpose.** The recent-database
path lives in `~/.cache`, so a fresh install has nothing to preselect whatever
the settings say. Stage 3 writes it only when `LastDatabases` is absent, so a
database opened later survives a re-run.

**`strawberry.conf` is written with `qs_set`, never `kwriteconfig6`.** It is a
QSettings file like qBittorrent's, and it carries both classes of value that
KConfig destroys: `@ByteArray` window geometry and nineteen equalizer presets
keyed `presets\N\name`. One `kwriteconfig6` call on the live system produced 38
lines of doubled-backslash junk beside the originals and re-encoded the
geometry blob (2026-08-01). A fresh install hides this — there is no file yet
to corrupt — so it only ever surfaces on a re-run, which the Steam step makes a
routine part of the workflow.

**`strawberry.conf` is never captured whole.** It holds a plain-text OAuth
access token for a streaming service. Only individual keys are written, so the
token never comes near the repo. The upmix is the reason Strawberry is in the
package set at all: it must happen inside the player, never system-wide.

**"Show hidden files" is a view property, and it hides well.** Not in
`dolphinrc`, not in `kdeglobals` — the `Show hidden files` key there belongs to
`[KFileDialog Settings]`, the open/save dialogs. It lives in the shared view
properties file above, in group **`[Settings]`**, not in `[Dolphin]` where the
other view properties sit. Source of truth for that is KDE's own schema,
`/usr/share/config.kcfg/dolphin_directoryviewpropertysettings.kcfg`. Dolphin
creates the directory but may never write the file, in which case the setting
lives only in the running process and does not survive a reinstall.

The window rule id is a fixed UUID authored here, so re-runs update the rule
instead of appending duplicates. `count` and `rules` in `[General]` list every
rule and must grow when another one is added.

### Other stage-3 settings

| Setting | Value | Origin |
|---|---|---|
| Commit identity | `GIT_IDENTITY_NAME`/`_EMAIL` written **repo-locally** into `~/phoinix`, plus warnings for a global identity and for `GIT_AUTHOR_*` in the environment | dec |
| Shell aliases | own file `~/.config/phoinix/aliases.zsh`, sourced from `.zshrc`: `nano`→`micro`, `yay`→`paru`, `qbittorrent`→the VPN wrapper | dec |
| `environment.d/10-phoinix-locale.conf` | `LANG` + nine `LC_*` on `de_DE.UTF-8` | dec |
| `plasma-localerc` | the same, so the KCM shows the truth | dec |
| Deliberately **not** set | `LC_MESSAGES` (would translate the UI), `LC_COLLATE` (would change shell globs and `sort`) | dec |
| Default PDF handler | `brave-browser.desktop` | dec |
| Services | `bluetooth`, `cups`, `power-profiles-daemon` | dec |
| Stage-4 unit | rendered + symlinked into `plasma-workspace.target.wants` | dec |
| Playlist export unit | rendered + symlinked into `graphical-session.target.wants`; exports on session exit | dec |
| xlcore backup unit | same mechanism; backs up XIVLauncher settings + plugins on session exit | dec |
| plasmashell drop-in | `After=` kwin, `TimeoutStopSec=10s` — 40s shutdown hang | dec |
| Graphical login | enabled **last**, after everything above exists | dec |

## Stage 4 — inside the running Plasma session

Fires once, guarded by `~/.local/state/phoinix/stage4.done`.

| Setting | Value | Origin |
|---|---|---|
| Panels | rebuilt from scratch: main panel, TV clone, two clock strips | dec |
| Main panel height | `PANEL_MAIN_HEIGHT=46` | dec |
| Side strips | `DP-2:55`, `DP-3:36` | dec |
| Pinned launchers | Konsole, Dolphin, Brave, KeePassXC, Strawberry, Discord, qBittorrent, Obsidian | dec |
| Kickoff favourites | browser, System Settings, Dolphin | dec |
| Pointer acceleration | **flat profile on every pointer that supports it** | dec |
| Places sidebar order | `PLACES_ORDER` labels, resolved at runtime | dec |
| Window rule: Dolphin | size `1295,839`, Apply Initially | dec |
| Window rule: Konsole | origin of `KONSOLE_CONNECTOR`, size `1440,1262` | dec |
| Window rule: Strawberry | origin of `STRAWBERRY_CONNECTOR`, size `1920,2105`, **starts unmaximized** | dec |
| Window rule: KeePassXC | `KEEPASSXC_CONNECTOR` + `KEEPASSXC_OFFSET`, size `1920,1053` — below qBittorrent | dec |
| Window rule: FFXIV | origin **and size** of `FFXIV_CONNECTOR`; matched on class **plus title** | dec |
| Strawberry playlist | `PLAYLIST_FILE` imported as `PLAYLIST_NAME`, **Strawberry started and waited for**, import retried, result verified in the database | dec |
| Final step | `systemctl --user restart plasma-plasmashell.service` | dec |

**All window rules live in stage 4, none in stage 3.** `count` and `rules` in
`[General]` form a single shared index, so two stages writing into
`kwinrulesrc` would eventually have one drop the other's entries. Stage 4 is
also the only stage that can resolve a *position*: a rule storing `7280,0`
encodes a coordinate in the current monitor layout and silently points
elsewhere once a screen moves, so the repo stores a connector name and the
origin is computed at runtime. Rule ids are fixed UUIDs authored here, so
re-runs update rules instead of appending duplicates, and
`org.kde.KWin.reconfigure()` makes them apply without waiting for a re-login.

**The playlist import waits for a socket, not for a process, and retries.**
`strawberry --create` is an IPC message, and three separate things have to be
true for it to arrive: an instance must exist, its KDSingleApplication socket
(`/tmp/kdsingleapp-<user>-strawberry`) must be listening, and the instance must
be old enough to act on the message. Only the first two are observable. Before
the socket exists the second invocation takes itself for the first instance and
starts a whole second Strawberry — a ~60 ms window, measured. The third is not
observable at all, so the import is attempted up to four times and verified
against the database after each, and a resend happens only while the playlist
is absent, because `--create` does not merge by name.

**Strawberry's rule carries two maximize keys, and a size rule alone is not
enough without them.** Measured on the first start after the scripted reinstall
(2026-08-01): Strawberry comes up **maximized** when it has no saved geometry,
so the "Apply Initially" size lands at map time and the maximized state then
covers the whole monitor — 3840x2105, the exact maximize area of DP-2. It does
not heal itself: on exit Strawberry writes `maximized=true` into
`strawberry.conf`, so every later start repeats it until the window is resized
by hand. `maximizehoriz`/`maximizevert=false`, also Apply Initially, fix the
start state while leaving the maximize button working. Verified in the harder
case — the rule wins even against a saved `maximized=true`.

**FFXIV is the one rule that does not match on window class alone.** umu/Proton
gives every non-Steam title it launches the same `WM_CLASS`,
`steam_app_default` — no Steam AppID is set — so DZGUI's DayZ would satisfy a
class-only rule just as well and get dragged onto the ultrawide. The rule
therefore also matches the title `FINAL FANTASY XIV`, which is the only field
that separates them. Its size is taken from the connector rather than a
`*_SIZE` variable, because borderless means exactly one monitor's resolution.
And it works at all only because XIVLauncher runs the game over XWayland
(`WaylandEnabled=false`): a Wayland-native client cannot be positioned by
anyone, itself included.

**Places sidebar order comes from labels, never from the file.** KDE persists
the order of device entries as `<separator>` markers in `user-places.xbel`,
each naming its device by UDI (containing the device node) *and* filesystem
uuid — device nodes are probe-order, and the root/home UUIDs are regenerated by
every install. `hosts/<host>/config.sh` therefore stores an order of **labels**
(`archroot archhome Games FilesMusic Downloads Video`; root and home get theirs
from stage 1), which stage 4 resolves via `/dev/disk/by-label/` and `lsblk`.
Absent labels are skipped, removable media is never included, and if nothing
resolves the file is left untouched rather than emptied.

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

## ProtonVPN split tunnel (stages 2 and 3)

Only qBittorrent uses the VPN; everything else keeps the normal line. And
qBittorrent can use *nothing but* the VPN — enforced by the kernel, not by the
application. Rationale in `LOG.md` 2026-07-31.

| Setting | Value | Origin |
|---|---|---|
| `VPN_CONFIG_DIR` | `$PHOINIX_DATA/vpn` — WireGuard configs, **never in the repo** (each carries a PrivateKey, which for Proton *is* the credential) | dec |
| `VPN_INTERFACE` | `proton0` — authored, not discovered. Both connections share it, so qBittorrent's binding survives switching country | dec |
| `VPN_GROUP` | `vpnonly` | dec |
| `VPN_GATEWAY` | `10.2.0.1` — Proton's in-tunnel gateway. NAT-PMP peer; **no longer the resolver** (see the DNS section below) | dec |
| Tunnel DNS | **removed 2026-08-01**: `ipv4.dns`, `ipv6.dns` and both `dns-search` cleared on every imported profile. The import used to turn Proton's `DNS =` line into a `~` search domain, i.e. resolved's DNS default route, so the whole desktop resolved through the tunnel and CDNs placed ulu in Switzerland. `LOG.md` 2026-08-01 | dec |
| NM connections | one per `.conf`, `wireguard.ip4/ip6-auto-default-route` **off**, routes confined to table 51, rule `priority 100 fwmark 0x51 table 51`, only the first autoconnects | dec |
| `VPN_MARK_APP` / `VPN_MARK_WG` / `VPN_ROUTE_TABLE` | `0x51` / `0x52` / `51` — the group's mark selects the tunnel table; WireGuard's own mark exempts its encapsulation from the drop | dec |
| qBittorrent | `Session\Interface` + `Session\InterfaceName` = `proton0` | dec |
| Launcher | `~/.local/share/applications/org.qbittorrent.qBittorrent.desktop`, copied from the packaged file with only `Exec` rewritten to `scripts/qbittorrent-vpn.sh` | dec |
| Port forwarding | **dropped 2026-07-31** (ulu's call). It needed qBittorrent's WebUI as its only delivery channel, and both servers in use refuse NAT-PMP anyway. Torrenting works without it; it costs peers | dec |

**Two lines of defence, and only one of them is the guarantee.** The interface
binding is qBittorrent promising something about itself; it does not survive a
bug, an update that resets it, or a mistyped option. The nftables rule survives
all three. Both are set, but only the second is load-bearing.

**Both failure paths close rather than open.** If the group is missing, `nft`
rejects the *whole* ruleset (it resolves group names at parse time), so
`qbittorrent-vpn.sh` checks the group **and** the service state and refuses to
launch. If the tunnel is down, qBittorrent simply has no route out.

## DNS (stages 2 and 3)

The other half of the split tunnel. The tunnel carries qBittorrent's packets
but not its lookups, so whatever resolves also sees every tracker name — from
the home address, in the clear, unless it is encrypted. Full reasoning and the
measurement that forced this in `LOG.md` 2026-08-01.

| Setting | Value | Origin |
|---|---|---|
| Backend | `systemd-resolved`, NM handed over via `/etc/NetworkManager/conf.d/10-phoinix-dns.conf` | dec |
| `DNS_SERVERS_V4/V6` | Quad9 `9.9.9.9`, `149.112.112.112`, `2620:fe::fe`, `2620:fe::9` | dec |
| `DNS_TLS_NAME` | `dns.quad9.net` — the certificate name, i.e. what makes "encrypted" mean "encrypted to the intended server". Empty switches the whole section off | dec |
| DoT mode | `connection.dns-over-tls 2` = strict. Opportunistic would fall back to port 53 silently, which is the leak this exists to close | dec |
| Wired link | `ipv4/ipv6.ignore-auto-dns yes`, Quad9 as `<ip>#<tls-name>`, `dns-search` cleared | dec |
| LAN names | `/etc/systemd/resolved.conf.d/10-phoinix-lan.conf`, generated: the DHCP-announced resolver, scoped to the DHCP-announced domain (`Domains=~<domain>`), plain port 53 | dec |
| Ethernet profile | found by TYPE (`802-3-ethernet`), never by name — NM auto-creates it and may name it differently on a fresh install | dec |

**Why the layout looks inverted.** NetworkManager marks the wired link as
resolved's DNS default route whatever domains it carries, and a link holding
the default route claims every name — so a "router on the link, Quad9 global"
arrangement never asks Quad9. Reversed, the more specific global scope wins for
the LAN domain and the link's catch-all serves everything else.

**Neither the router's address nor the LAN domain is stored** — both come out
of the DHCP lease at runtime, which is also why this cannot live in stage 2:
there is no lease in the chroot.

**The LAN half is not cosmetic.** Without it a LAN name does not fail, it
resolves to a stranger's host on the public internet.

## qBittorrent (stages 3 and 4)

Written with **`qs_set`, the shared line-oriented INI writer, never
`kwriteconfig6`**: this file is Qt's QSettings format, where the backslash in
`Session\Interface` is a group separator written as one character. KConfig
escapes it and rewrites the whole file, so it doubled every backslash —
including qBittorrent's own keys — and qBittorrent then read none of them. The
file also holds `@ByteArray` window geometry that a full-file rewriter would
re-encode.

`qs_set` sits at the top of `stage3.sh` rather than inside this section,
because the same mistake was made a second time on `strawberry.conf` while the
fix was local to qBittorrent (2026-08-01). Any QSettings file goes through it.

| Setting | Value | Origin |
|---|---|---|
| `Session\Interface`, `Session\InterfaceName` | `proton0` — first of two lines, never the guarantee | dec |
| `Session\DefaultSavePath` | `QBT_SAVE_PATH` = `/mnt/Downloads/Torrents` — a data disk, not the one a reinstall wipes | dec |
| `Session\TempPath` + `TempPathEnabled` | `/mnt/Downloads/Temp`, `true` — same disk, so completion is a rename | dec |
| `GUI/DownloadTrackerFavicon` | `false` (default true) | dec |
| `Application/GUI\Notifications\TorrentAdded` | `false` (default true) | dec |
| `LegalNotice/Accepted` | `true` — removes a dialog that greets every fresh install | dec |
| Launcher + autostart | both point at `scripts/qbittorrent-vpn.sh`, never the packaged entry | dec |
| Group switch | `newgrp` (util-linux), **not** `sg` — `sg` no longer exists on Arch | dec |
| Argument passing | file arguments travel in the environment, base64'd; never through the shell line | dec |
| Post-switch check | effective gid compared against the group's before qBittorrent is exec'd | dec |
| KWin rule (stage 4) | `QBT_CONNECTOR` + `QBT_OFFSET` + `QBT_SIZE`, resolved at runtime | dec |

**Deliberately not scripted:** `Session\Port` and `SSL\Port` (drawn fresh per
install), the `FileLogger` block, `RSS\AutoDownloader` and `OptionsDialog`
(defaults qBittorrent serialises once its dialog is opened — the same trap
Strawberry set), and `General\Locale` (ulu confirmed he never touched it).

**The window class carries a leading space.** qBittorrent reports an empty
instance name, so with `wmclasscomplete=true` the value is
`\sorg.qbittorrent.qBittorrent`. Reproduced verbatim; without it the rule
matches nothing.

## Discord (stages 3 and 4)

**Almost nothing here is scriptable, and that is the finding.** Everything ulu
configures in Discord's UI — theme, notifications, audio devices, keybinds,
privacy — lives server-side in his account and returns on login, like Brave's
sync chain. Its `settings.json` holds window bounds, a background colour and
Discord's own experiment flags: not one decision.

| Setting | Value | Origin |
|---|---|---|
| Autostart | packaged `discord.desktop` copied into `~/.config/autostart/` | dec |
| KWin rule (stage 4) | `DISCORD_CONNECTOR` + `DISCORD_OFFSET` + `DISCORD_SIZE` — lower half of the portrait monitor, beneath Konsole | dec |

**The Arch package is a bootstrapper, not the application.** `/usr/bin/discord`
is a ~40-line shell script; on first run it fetches the real client (554 MB)
from `updates.discord.com` into `~/.config/discord/app-<version>/` and execs it
from there. Two consequences worth knowing: `pacman -Syu` does **not** update
the running client, and a fresh install re-downloads half a gigabyte at first
launch.

**`SKIP_HOST_UPDATE` is deliberately NOT set.** That workaround belongs to the
era when the package shipped the app under a read-only system directory, where
a self-update could not succeed and left the client hanging. Here the app lives
in a directory it owns, so updating works — and pinning it would freeze the
client until Discord's servers refuse it, producing the very failure the
setting was meant to avoid.

## Brave (stages 3 and 4)

Like Discord, almost everything lives elsewhere: the profile comes back through
Brave Sync, and it holds `Login Data`, `Cookies`, `Web Data` and `Local State`
— never captured, never in the repo.

| Setting | Value | Origin |
|---|---|---|
| Default browser | `kdeglobals` `BrowserApplication=brave-browser.desktop` | old |
| PDF handler | `xdg-mime default brave-browser.desktop application/pdf` | dec |
| KWin rule (stage 4) | `adaptivesync=false`, `adaptivesyncrule=2` (**Force**) — VRR off for Brave windows | dec |
| Per-app volume | Brave's stream volume, in the captured wireplumber state | old |

**The VRR rule is about video, not about Brave.** ulu gets a constant slight
flicker watching video — YouTube being the case that drove it — and mpc-qt shows
the same. The likely mechanism (inferred): DP-1's VRR range is 48–170 Hz while
video runs at 24/25/30 fps, so below the range the display duplicates frames and
the refresh rate oscillates. Per-application rather than per-output on purpose:
switching VRR off at the monitor would also remove it from games, which is the
reason it is enabled at all. **Expect this rule to recur for every video
player** — mpc-qt is already known to need it.

Not the same thing as the sporadic black **flash** on DP-1 (see `STATUS.md`),
which is an instantaneous full blank with no video playing, diagnosed as DP link
retraining.

**`~/.config/brave-flags.conf` is deliberately absent.** `/usr/bin/brave` reads
it for start-up flags; ulu needs none, so there is nothing to write.

## Steam (nothing in stages 3 and 4)

The round produced **no scriptable setting at all**, and that is the entry.
Steam's durable state lives in `~/.local/share/Steam` and `~/.steam`, is bound
to the account, and includes auth tokens — never captured. Nothing appeared in
`~/.config` except Plasma bookkeeping (a notification source marked seen, and
the screen mapping for the desktop icon Steam created).

| Item | Where it stands |
|---|---|
| Library `/mnt/Games/SteamLibrary` | manual, by design — see `STATUS.md` for why |
| `~/Desktop/steam.desktop` | manual removal after first launch; no suppression flag exists |
| Gamepad | needs nothing: `xpad` binds it, `uaccess` grants the session access |
| `steam-devices`, `game-devices-udev` | correctly absent — verified with the pad switched on |

**The library carries its own identity.** `/mnt/Games/SteamLibrary/libraryfolder.vdf`
holds the `contentid` that Steam matches against, so the games survive a
reinstall as long as the folder is re-added. That is what makes the manual step
cheap rather than a re-download.

## LibreOffice (stage 3)

| Setting | Value | Origin |
|---|---|---|
| `Office.Common/Appearance` `ApplicationAppearance` | `2` = dark, chosen explicitly rather than "System" | dec |
| `Office.UI/ColorScheme` `CurrentColorScheme` | `COLOR_SCHEME_LIBREOFFICE_DARK` — follows from it, written for corroboration | dec |

**Seeded, never edited.** LibreOffice keeps everything in one
`registrymodifications.xcu`, which does not exist until it has run once — i.e.
never at stage 3 time on a fresh install. A hand-written minimal file placed
beforehand is read and kept, with LibreOffice merging its own entries around it
(verified: 516 → 767 bytes, both values intact). Stage 3 therefore writes the
file **only when it is absent**; an existing profile is ulu's and is left alone.

**Never captured whole.** That same file accumulates recently opened documents
with full paths. It also holds a `UserData` node — empty here, since ulu never
filled in the user-details page, which is the good outcome for a public repo.

Everything else in his profile is window and toolbar state (`WindowState`,
`DockPos`, `SplitWindow`, `Visible`), the registered dictionary languages, and
`UseOpenCL=false`, which is LibreOffice's own default.

## mpc-qt (stage 4 only)

haruna was evaluated and rejected 2026-07-31; mpc-qt stays.

| Setting | Value | Origin |
|---|---|---|
| KWin rule (stage 4) | `adaptivesync=false`, forced — the same VRR-and-video rule as Brave | dec |

**phoinix no longer configures mpc-qt (ulu, 2026-08-01).** It used to write
two track preferences and repair a broken profile; both are gone, and the
reason is the SHAPE of the step rather than the settings.

mpc-qt 26.07 segfaults in `QScreen::availableGeometry()` out of `main`
whenever `settings.json` exists and `geometry_v2.json` does not, and the
crashing run leaves exactly that state behind, so it never starts again.
Tested three ways: a two-key `settings.json` alone crashes, and so does one
paired with an empty or stub `geometry_v2.json`. So the profile could not be
SEEDED — settings could only be written into one that already existed, which
meant "start mpc-qt once, then run stage 3 again". ulu is not willing to run
stage 3 twice and configures the player himself.

Worth keeping even though the code is gone: the contrast with LibreOffice,
where seeding was verified to work. Same question, opposite answer, and only
the measurement told them apart.

`keys_v2.json` (46 KB of key bindings) is deliberately not captured — ulu
changed none of it.

## Printer (stage 3)

Samsung SCX-4300 over USB, print only. Verified end to end on 2026-07-31: queue
created, test page printed, paper confirmed by ulu.

| Setting | Value | Origin |
|---|---|---|
| `PRINTER_NAME` | `SCX-4300` | dec |
| `PRINTER_DRIVER` | `drv:///splix-samsung.drv/scx4300.ppd` — splix, "Samsung SCX-4300, 2.0.0" | dec |
| `PRINTER_MATCH` | `SCX-4300` — what stage 3 looks for in `lpinfo -v` | dec |
| `PRINTER_OPTIONS` | `PageSize=A4` (the driver defaults to Letter), `printer-is-shared=false` | dec |
| Default destination | this printer, being the only one | dec |

**The device URI is resolved at runtime, never stored.** CUPS builds it as
`usb://Samsung/SCX-4300%20Series?serial=<serial>&interface=1` — it carries the
printer's serial number, which is a discovered identifier and hardware ID both.
Stage 3 finds it with `lpinfo -v`, the same pattern as monitors, disks and mice.
The driver string, by contrast, comes from the splix package and is identical
everywhere, so that one is configuration.

**No root needed.** CUPS accepts administration from the `wheel` group on Arch;
`lpadmin` ran unprivileged. Verified, not assumed.

**Known expiry date.** `lpadmin` warns: *"Printer drivers are deprecated and
will stop working in a future version of CUPS."* CUPS 3 drops PPD-based drivers,
which is exactly what splix is, and this 2007 device does not speak IPP
Everywhere. When Arch moves to CUPS 3 this queue stops working, and the fallback
is a local IPP-Everywhere adapter or a print server in front. Recorded so the
failure is not a mystery when it arrives.

## DZGUI (stage 3)

DayZ launcher, fetched as an upstream tarball rather than a package (see
`aur.txt`). Config lives in `~/.config/dzgui/config.json` — note the name:
DZGUI 7 uses `dzgui`, not the `dztui` recorded during the package rounds.

| Setting | Value | Origin |
|---|---|---|
| `DZGUI_PRIVATE_FILE` | `$PHOINIX_DATA/dzgui-private.json`, mode 0600 — **path only**, never the contents | dec |
| `DZGUI_NAME` | `uluToyon` | dec |
| the rest | `client=steam`, `start_tab=1`, `fullscreen=false`, `use_miles=false`, Steam path derived from `$HOME` | dec |

**The private file holds two things that must never enter a public repo**: the
Steam Web API key (a hard secret) and ulu's server list (which says where he
plays). Both must also survive a reinstall, so they sit on a data disk phoinix
never touches — the same anchor pattern as the WireGuard configs and the
Strawberry playlist.

**Seeded, and here it earns its keep.** Without a config the first run opens a
wizard that demands a Steam Web API key, i.e. a trip to steamcommunity.com and
32 characters typed by hand after every reinstall. With the file in place the
wizard does not run — **confirmed by ulu, who saw the server browser and no
wizard at all**, on top of the measurement that DZGUI accepted the seeded config
unchanged and added no field of its own. Seeded **only when absent** —
an existing config is ulu's, and DZGUI writes his server list into it as he
plays.

**Steam integration does not work, and fails silently.** DZGUI's wizard offers
to add itself to Steam; it cannot, because `Shortcuts._load_shortcuts()` opens
an existing `shortcuts.vdf` for reading and Steam only creates that file once a
non-Steam game has been added by hand. The exception is swallowed
(`except Exception: logger.critical(e)`) and the wizard page is, in its author's
own comment, *"best-effort, permissive even on failure"* — so it reports success
and does nothing. Workaround, and the one ulu took: add it once via Steam's *Add a Non-Steam
Game*, pointing at `~/Applications/dzgui/dzgui`.

**The resulting shortcut is backed up rather than recreated.**
`STEAM_SHORTCUTS_FILE` points at a copy on the games disk, and stage 3 restores
it into `userdata/<id>/config/` — but only once Steam has a place for it, since
that directory exists solely after a login. On a fresh install stage 3 says so
and the second run (after logging in) does the work. It never overwrites an
existing file, and it refuses while Steam is running, because Steam rewrites
this file when it exits. Backing up rather than generating also means any later
non-Steam game comes along by itself.

## Desktop icon (stages 3 and 4)

One icon on an otherwise empty desktop, and deliberately so — Steam's was
deleted, this one is kept.

| Setting | Value | Origin |
|---|---|---|
| `XIVLAUNCHER_DESKTOP` | `/usr/share/applications/XIVLauncher-RB.desktop` | dec |
| `DESKTOP_ICONS` | `XIVLauncher-RB.desktop:2,2` and `phoinix-monitor-switch.desktop:4,4` — basename plus column,row in the Folder View grid | dec |
| `MONITOR_SWITCH` | `34R83Q:6:8`, `27R83U:6:8`, `XZ322QU V3:15:17` — model, desktop input, laptop input (VCP 0x60) | carried |
| `MONITOR_SWITCH_REF` | `XZ322QU V3` — the only panel that reports its input truthfully | dec |

**A symlink, not a copy** — which is what KDE itself creates when an entry is
dragged from the menu, and it keeps the launcher's own `.desktop` as the single
source for icon, categories and `StartupWMClass`.

**The position needs three keys and two runtime lookups.** Plasma stores it in
`plasma-org.kde.plasma.desktop-appletsrc` as `positions`, `changedPositions` and
`sortMode=-1` (manual sorting; without it the other two are ignored), keyed by
**screen resolution** and living in a containment whose number and activity UUID
are generated per install. Stage 4 resolves the resolution from
`PANEL_MAIN_CONNECTOR` and finds the containment by matching Plasma's own
`lastResolution` — never by a hard-coded number.

**plasmashell is stopped around the write**, because it caches this file and
writes it back when it exits — the same trap the Kickoff favourites hit.

Two things only a real run showed: `kwriteconfig6` reads `-1` as an option, so
`sortMode` needs a `--` separator; and the presence of `changedPositions` at all
is what proves ulu moved the icon rather than accepting a default placement.

## XIVLauncher / Dalamud (stage 3)

`~/.xlcore` is ~2.7 GB and almost all of it rebuilds itself. What does not is
about 80 MB, kept next to the game on the games disk
(`XLCORE_BACKUP_DIR = $PHOINIX_DATA/xlcore-backup`) and written by
`scripts/xlcore-backup.sh`. Only the path is versioned.

**The backup runs itself, since 2026-07-31.** `phoinix-xlcore-backup.service`
is a user unit of the same shape as the playlist export — oneshot,
`RemainAfterExit`, the real work in `ExecStop` — so it fires when the graphical
session goes down. It exists because stage 3 *restores* `launcher.ini` from
this directory, which makes an unrefreshed backup actively harmful rather than
merely stale: a live change gets reverted by the next reinstall. That nearly
took ulu's `GameModeEnabled=true` with it on the day the unit was written.

| Carried | Why |
|---|---|
| `launcher.ini` | launcher settings: Proton/DXVK/Dalamud, paths, `CurrentAccountId` |
| `accounts.json` | **credential** — account name and last OTP; 0600, never the repo |
| `dalamudConfig.json` | the plugin **profile** (10 plugins with enabled state) and the **third-party repo list** |
| `dalamudUI.ini` | Dalamud window layout |
| `pluginConfigs/` | per-plugin settings, **minus** `Browsingway/` |
| `installedPlugins/` | the plugin binaries, ~79 MB |

| Not carried | Size | Why |
|---|---|---|
| `protonprefix` | 954 MB | rebuilt on demand |
| `pluginConfigs/Browsingway/` | 623 MB | `dependencies` + `cef-cache`; its settings are the 2.8 KB `Browsingway.json` beside it |
| `dalamud`, `runtime`, `dalamudAssets` | 680 MB | downloaded by Dalamud itself |
| `ffxivConfig` | — | **already lives on the games disk**; `GameConfigPath` points there, so it survives by construction |

**The binaries are carried deliberately.** `dalamudConfig.json` alone would be
enough *if* Dalamud reinstalls from the profile and the three third-party repos
are still online years from now — the first was never verified and the second is
outside anyone's control. 79 MB on a disk this repo never formats is the cheaper
insurance. Shrinking to 284 KB later is easy; the reverse is not.

**The backup deletes as well as adds** (`rsync --delete`), so a plugin removed
in Dalamud disappears from the backup too. Without that it would only ever grow
and would reinstate things deliberately got rid of.

**The real directory is `~/.local/share/dev.goats.xivlauncher`.** `~/.xlcore`
is only a compatibility symlink XIVLauncher-RB creates beside it — reading
through it works, writing into it does not: a restore that creates a plain
`~/.xlcore` directory shadows the link with files the launcher never reads.
Both scripts therefore name the XDG path.

**Restore is per file and per tree, never wholesale**: anything already there
belongs to a launcher that has run since.

**Seeding is verified (2026-07-31).** The live directory was moved aside, the
80 MB restored into an empty one, and XIVLauncher came up fully configured —
account, settings, all ten plugins — and carried through into the game, with
Dalamud re-downloading its framework around the restored config. The restored
directory was then kept and the original deleted.

## Git and GitHub (stage 3)

Two problems, one section. GitHub has to be reachable from a rebuilt machine
without a manual login, and no commit of ulu's may ever carry his real name.
Both are solved for *every* repository on the machine, not only for this
checkout — a project cloned next year has to be right without anyone
remembering. Rationale in `LOG.md` 2026-08-04.

| Setting | Value | Origin |
|---|---|---|
| `SSH_GITHUB_KEY` | `$PHOINIX_DATA/ssh/github_ed25519` — ed25519, no passphrase, **never in the repo**; only the path is versioned | dec |
| Key comment | `uluToyon`, not `user@host` — the comment is visible in the key list at GitHub | dec |
| `~/.ssh/config` | `dotfiles/ssh_config`, mode 0600: `github.com` bound to that key, `IdentitiesOnly yes` | dec |
| `GITHUB_HOST_KEY_FP` | `SHA256:+DiY3wvv…UvCOqU`, checked against `ssh-keyscan` before `known_hosts` is written | dec |
| `~/.config/git/config` | `dotfiles/gitconfig` — **no global `[user]`**; identity via `includeIf` | dec |
| Identity condition | remote matching `github.com/uluToyon` (ssh, ssh://, https) → `identity-github` | dec |
| `~/.config/git/identity-github` | generated from `GIT_IDENTITY_NAME` / `GIT_IDENTITY_EMAIL`, so `config.sh` stays the only source | dec |
| `url.insteadOf` | `https://github.com/uluToyon/` → `git@github.com:uluToyon/` | dec |
| `init.defaultBranch` | `main` | dec |
| `pull.rebase` | `true` — merge commits from a routine pull say nothing | dec |
| `push.default` | `simple` | dec |
| ~~`GIT_CREDENTIALS_FILE`~~ | the fine-grained PAT — **retired 2026-08-04**, revoked and deleted. It sat on the same disk as the key, so it never covered the failure that matters | dec |

**The refusal is the feature.** A repository with no remote, or someone else's
remote, gets no identity at all and git declines to commit — instead of quietly
inventing an author, which is how 35 commits once acquired ulu's real name.
Verified 2026-08-04 with four throwaway repositories: ssh remote → `uluToyon`,
https remote → `uluToyon` (and rewritten to ssh), a stranger's repository →
"Author identity unknown", no remote → the same.

**Why a key and not another token.** A fine-grained token is scoped to the
repositories it names, so every new project cost a visit to GitHub, a file on
the data disk and a line in the script. The key costs nothing per project.

## Known gaps and open items

- ~~`kglobalshortcutsrc` is not managed.~~ Done 2026-07-31 — media keys and
  Spectacle are written as deviations. Any future shortcut change is found the
  same way: compare field 1 against field 2 in that file.
- **`kwinoutputconfig.json` is a provisional state**, carrying the 144 Hz
  experiment on DP-1. See `STATUS.md`.
- **Console keymap has no variant.** `KEYMAP=de` means the text console keeps
  dead keys while X11 and Plasma do not. Deliberate for now — on the vconsole
  the no-dead-key layout is a different keymap *name* (`de-latin1-nodeadkeys`),
  not a variant. Change it only if the console ever starts mattering.
- **`~/.config/pipewire/pipewire.conf` on the live system** is a stale copy
  shadowing the packaged config. Excluded from the repo; deleting it on the
  live machine is still pending.
