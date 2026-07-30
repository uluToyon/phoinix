# Installationsprotokoll

Chronologisches Protokoll der Erst-Installation und aller Entscheidungen.
Das Repo ist die Quelle der Wahrheit — dieses Protokoll ist das Sicherheitsnetz
und die Begründungs-Sammlung.

## 2026-07-30 — Session 1: Planung & Vorbereitung (per SSH vom Laptop)

**Setup:** Desktop bootet Arch-ISO (2026.07), Zugriff per SSH als root auf
192.168.178.46 (Key-Auth eingerichtet). Diese SSH-Installation ist einmalig —
künftig läuft das Skript direkt auf dem Zielrechner.

**Hardware-Inventar:**
- Ryzen 7 7800X3D, 30 GiB RAM, Radeon RX 7900 XT(X) + Raphael iGPU, UEFI 64-bit
- LAN `enp8s0` (aktiv), WLAN `wlan0`
- Zielplatte: Samsung SSD 980 1TB, Serial S649NX0T343303X (`nvme1n1`)
- Datenplatten (bleiben unangetastet): `Games` (Samsung 980 PRO 2TB, NVMe),
  `Video` (WD 5,5TB HDD), `Downloads` (OCZ 894GB SSD), `FilesMusic` (Seagate 1,8TB HDD)

**Entscheidungen (mit Begründung):**
- **ext4 statt Btrfs** — bewusst: reiner Gaming-Desktop, Snapshots würden nicht
  genutzt; das Reinstall-Skript selbst ist das Rollback. Btrfs-Nachrüstung wäre
  ohnehin nur beim Dateisystem selbst unmöglich, Rest bleibt offen.
- **Keine Verschlüsselung** — Desktop steht zuhause, einfacher curl-Workflow.
- **Getrenntes /home auf eigener Partition** — überlebt Distro-Hopping.
  Regeln: immer gleicher Benutzername (`ulutoyon`) als erster User (UID 1000),
  im fremden Installer /home nie formatieren.
- **Partitionen:** EFI 1G | root 200G ext4 | home Rest (~730G) ext4
- **zram statt Swap-Partition** — kein Hibernate-Bedarf.
- **systemd-boot** — UEFI, Single-OS, minimal.
- **Mountpunkte der Datenplatten nach Label** (`/mnt/Games`, …) statt alter
  Gerätenamen-Pfade (`/mnt/nvme0n1`) — Lektion aus DESIGN.md: keine
  entdeckten Bezeichner verewigen. Pfad-Änderung gegenüber Altsystem!
- **Direkt auf dem Desktop installieren**, QEMU-Härtung der Skripte danach.
- Hostname `archlinux`, Locale `en_US.UTF-8`, KEYMAP `de`, TZ `Europe/Berlin`
  (vom Altsystem übernommen).

**Backup vor dem Löschen** → `Downloads`-Platte, `backup-nvme1n1-20260730/`:
- `~/.claude` (19M) + `~/.claude.json` — Claude-Sessions/Projekte
- `arch-install/DESIGN.md` (jetzt in `docs/DESIGN.md` im Repo)
- Capture-Dateien lt. DESIGN.md: `kwinrc`, `.config/pipewire/`,
  `.local/state/wireplumber/` (Soundbar −26dB-Fix), `.local/share/kscreen/`
  (4-Monitor-Layout). `.xlcore/launcher.ini` existierte nicht mehr.
- Bewusst NICHT gesichert (Entscheidung ulu): restliches Home inkl.
  versteckter Spielstände/Browserprofile.

**Altes fstab** (Referenz für UUIDs): Games=78d74fc9…, Video=4eb23c82…,
Downloads=10015c7b…, FilesMusic=eaa964b8…

## Nächste Schritte
- [ ] stage1.sh auf dem Desktop ausführen (nach Review + Freigabe)
- [ ] stage2.sh schreiben & im chroot ausführen
- [ ] Reboot, stage3: yay, KDE, SDDM
- [ ] GitHub-Repo anlegen und pushen
