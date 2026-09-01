#!/usr/bin/env bash
# check-drift.sh — has the live system wandered away from what the repo carries?
#
#   usage: check-drift.sh <host>
#
# Written 2026-07-31 INSTEAD of adopting chezmoi. The dotfile question came down
# to one real benefit — noticing when a captured file and the live one stop
# agreeing — and that is this script rather than a second mechanism for getting
# configuration onto a machine. chezmoi's other selling point, per-machine
# templating, turned out to apply to nothing here: `p10k.zsh` contains no
# machine-specific value at all (its two username matches are comments about
# asdf), `zshrc` contains exactly one cosmetic `compinstall` line, and the
# laptop will never run this installer.
#
# WHY THIS EXISTS AT ALL: the repo has already been bitten. The soundbar sat
# 2.77 dB away from its documented, tested value for months — repo and live
# system disagreed and nothing said so, until the old transcripts were dug up by
# hand. A captured file is only worth what it was when it was captured.
#
# Exit status is 1 when something drifted, so this can be used as a check and
# not only read by a human.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: check-drift.sh <host>   (e.g. desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

CFG="$REPO_DIR/hosts/$HOST/home"

# Files that legitimately differ every day. Listed rather than skipped silently:
# a check that hides things is worse than one that explains them.
#   stream-properties — wireplumber records per-application volume and routing,
#   so it grows with every app that has ever played a sound. It is captured for
#   the settings it carries, not as a fingerprint of a moment.
VOLATILE=(".local/state/wireplumber/stream-properties")

# Files that are SEEDED rather than maintained: the repo decides what a fresh
# machine starts with, and ulu is free to change it afterwards without that
# counting as drift. Only the seeded part is exempt — everything else in the
# file is still compared.
#
#   default-routes — the soundbar's volume. It drifted three times in ten days
#   (2026-08-04, twice more by 2026-08-10) for the simplest possible reason: ulu
#   turns the volume knob. A repo that re-asserts a fixed level is fighting the
#   person using the machine, and a check that reports it every time trains
#   everyone to skim past the one line that might matter. His call, 2026-08-10:
#   the repo sets the initial value, running changes are ignored. What is still
#   compared here is the channel map and the mute state, which are settings.
SEEDED_ROUTES=".local/state/wireplumber/default-routes"

#   kwinoutputconfig.json — TWO exemptions live on this file. The second one,
#   added 2026-09-01: the REFRESH RATES are seeded, not maintained. ulu runs
#   DP-1 and DP-3 at 144 Hz on this machine and wants a fresh install to come up
#   at 170 and 180 instead, so the repo copy differs from the live file BY
#   DESIGN and a byte compare would report it forever. The rates are therefore
#   dropped from the structural compare — and printed underneath it instead, per
#   connector, so a change on either side is still visible. Hiding them outright
#   would hide DP-2's 144, which is not a preference but the fix that keeps a
#   fresh install from booting to a black screen.
#
#   kwinoutputconfig.json — KWin remembers every screen COMBINATION it has ever
#   seen, and re-writes all of them at logout. Some are learned during boots
#   where the outputs were not all up yet, so they accumulate on their own and
#   cannot be pruned for good (tried 2026-08-11: the pruned file was back to
#   seven arrangements after one reboot). What matters is the LAYOUT ulu chose,
#   which is the arrangements whose primary is PANEL_MAIN_CONNECTOR; the rest is
#   noise the compare has to ignore, or it reports drift after every session.
#   The greeter gets a filtered copy from scripts/greeter-screens.sh, and that
#   one does stay filtered, because its KWin only ever reads the file.
SEEDED_SCREENS=".config/kwinoutputconfig.json"

drift=0; same=0; volatile=0; missing=0; drifted=0

# stage 3 appends its alias hook to .zshrc (guarded, idempotent — see stage 3
# section 8), so the live file is SUPPOSED to have two lines the repo copy does
# not. Comparing without accounting for that would report drift on every machine
# phoinix has ever touched, i.e. always.
strip_phoinix_hook() {
    sed -e '/^# phoinix aliases (the file is generated/d' \
        -e '\|^\[\[ -f .*/phoinix/aliases\.zsh \]\] && source |d' "$1" \
    | awk 'NF { last = NR } { line[NR] = $0 } END { for (i = 1; i <= last; i++) print line[i] }'
}

# WirePlumber's three state files need the same treatment for three reasons,
# so they share one normaliser: normalise_wp <file> <reference>.
#
#   1. default-routes is "<route>={<json>}" per line, and wireplumber rewrites
#      that JSON with the keys in whatever order it feels like — the same
#      content produced a different file three times in one afternoon.
#      Comparing bytes therefore reports drift that is not there. Each line is
#      re-serialised with sorted keys and the volume dropped, so what is left to
#      compare is the channel map and the mute state: the parts that are
#      settings rather than a knob ulu turned.
#
#   2. default-nodes carries a HISTORY beside the setting. The real default sink
#      is the unnumbered `default.configured.audio.sink`; the numbered
#      `…sink.0`, `…sink.1`, … are nodes that were configured at some point and
#      never expire. That list only grows, so it is dropped.
#
#   3. All three accumulate entries for DEVICES THAT ARE NOT IN THE CAPTURE.
#      A key whose name does not appear in the repo copy is a device that
#      turned up afterwards, and a machine growing a sound device is not this
#      repo drifting. What IS still compared is every key the capture knows —
#      including one that has gone missing on the live side, which is worth
#      hearing about.
#
# Added 2026-09-01, after all three reported drift at once and not one of them
# had a changed setting in it: the card's HDMI audio had moved from PCI
# 0000:0b:00.1 to 0000:03:00.1 and each file had simply grown the new path.
# Three files of noise around zero findings is how a check stops being read.
normalise_wp() {
    python3 - "$1" "$2" <<'PYEOF'
import json, re, sys

HISTORY = re.compile(r"^default\.configured\.audio\.(sink|source)\.\d+=")

def keyset(path):
    ks = set()
    for line in open(path):
        t = line.strip()
        if not t or t.startswith("[") or HISTORY.match(t) or "=" not in t:
            continue
        ks.add(t.split("=", 1)[0])
    return ks

known = keyset(sys.argv[2])

for line in open(sys.argv[1]):
    line = line.rstrip("\n")
    t = line.strip()
    if not t or HISTORY.match(t):
        continue
    head, sep, tail = line.partition("=")
    if sep and not t.startswith("[") and head.strip() not in known:
        continue
    if sep and tail.startswith("{"):
        try:
            obj = json.loads(tail)
            obj.pop("channelVolumes", None)
            print(head + "=" + json.dumps(obj, sort_keys=True))
            continue
        except ValueError:
            pass
    print(line)
PYEOF
}

# Reduce kwinoutputconfig.json to the arrangements that put PANEL_MAIN_CONNECTOR
# first, with the keys sorted. Everything else in the file — modes, EDID hashes,
# HDR, the output list — is still compared; only the accumulating partial
# arrangements are dropped.
normalise_screens() {
    python3 - "$1" "${PANEL_MAIN_CONNECTOR:-}" <<'PYEOF'
import json, sys
try:
    doc = json.load(open(sys.argv[1]))
except ValueError:
    sys.exit("unparseable")
main = sys.argv[2]
outs = next((e["data"] for e in doc
             if isinstance(e, dict) and e.get("name") == "outputs"), [])
name = {i: o.get("connectorName") for i, o in enumerate(outs) if isinstance(o, dict)}
for o in outs:
    if isinstance(o, dict) and isinstance(o.get("mode"), dict):
        o["mode"].pop("refreshRate", None)
for e in doc:
    if isinstance(e, dict) and e.get("name") == "setups":
        e["data"] = [s for s in e["data"]
                     if [name.get(o.get("outputIndex")) for o in s.get("outputs", [])
                         if o.get("priority") == 1] == [main]]
print(json.dumps(doc, sort_keys=True, indent=1))
PYEOF
}

# The rates the structural compare above drops, said out loud. Seeded values are
# not secret ones: the repo decides what a fresh machine starts at, ulu is free
# to run something else, and both numbers belong on screen so neither can change
# unnoticed.
report_screen_rates() {   # <repo file> <live file> <label>
    local out
    out="$(python3 - "$1" "$2" <<'PYEOF'
import json, sys

def rates(path):
    try:
        doc = json.load(open(path))
    except (OSError, ValueError):
        return None
    outs = next((e["data"] for e in doc
                 if isinstance(e, dict) and e.get("name") == "outputs"), [])
    return {o.get("connectorName"): (o.get("mode") or {}).get("refreshRate")
            for o in outs if isinstance(o, dict)}

def hz(v):
    return "-" if v is None else "%g Hz" % (v / 1000)

a, b = rates(sys.argv[1]), rates(sys.argv[2])
if a is None or b is None:
    sys.exit(0)
for conn in sorted(set(a) | set(b)):
    if a.get(conn) != b.get(conn):
        print("%s: repo seeds %s, live runs %s" % (conn, hz(a.get(conn)), hz(b.get(conn))))
PYEOF
)"
    [[ -z "$out" ]] && return
    while IFS= read -r line; do
        report volatile "$3 — $line" "refresh rate is seeded, not maintained"
    done <<< "$out"
}

report() {   # <state> <path> [detail]
    case "$1" in
        same)     same=$((same + 1)) ;;
        volatile) volatile=$((volatile + 1)); printf '  ~ %s\n      %s\n' "$2" "$3" ;;
        missing)  missing=$((missing + 1)); drift=1; printf '  ! %s\n      %s\n' "$2" "$3" ;;
        drift)    drifted=$((drifted + 1)); drift=1; printf '  D %s\n      %s\n' "$2" "$3" ;;
    esac
}

check_pair() {   # <repo file> <live file> <label> <mode>
    local src="$1" dst="$2" label="$3" mode="${4:-plain}"

    [[ -f "$src" ]] || { report missing "$label" "not in the repo: $src"; return; }
    [[ -f "$dst" ]] || { report missing "$label" "not on the system: $dst"; return; }

    local a b
    if [[ "$mode" == "screens" ]]; then
        a="$(normalise_screens "$src" | sha256sum | cut -d' ' -f1)"
        b="$(normalise_screens "$dst" | sha256sum | cut -d' ' -f1)"
    elif [[ "$mode" == "wpstate" ]]; then
        a="$(normalise_wp "$src" "$src" | sha256sum | cut -d' ' -f1)"
        b="$(normalise_wp "$dst" "$src" | sha256sum | cut -d' ' -f1)"
    elif [[ "$mode" == "zshrc" ]]; then
        a="$(sha256sum < "$src" | cut -d' ' -f1)"
        b="$(strip_phoinix_hook "$dst" | sha256sum | cut -d' ' -f1)"
    else
        a="$(sha256sum < "$src" | cut -d' ' -f1)"
        b="$(sha256sum < "$dst" | cut -d' ' -f1)"
    fi

    if [[ "$a" == "$b" ]]; then
        report same "$label"
    else
        report drift "$label" "$(diff <(cat "$src") <(cat "$dst") | grep -c '^[<>]' || true) changed lines — diff \"$src\" \"$dst\""
    fi
}

echo "drift check — $HOST"
echo

# The captured tree, walked rather than listed by hand: a file added to
# hosts/<host>/home/ is then covered without anybody remembering to come here.
if [[ "${CAPTURED_CONFIGS:-0}" == 1 && -d "$CFG" ]]; then
    while IFS= read -r src; do
        rel="${src#"$CFG"/}"
        is_volatile=0
        for v in "${VOLATILE[@]}"; do [[ "$rel" == "$v" ]] && is_volatile=1; done
        if [[ "$is_volatile" == 1 ]]; then
            report volatile "~/$rel" "expected to differ — per-application state, not a setting"
        elif [[ "$rel" == "$SEEDED_ROUTES" ]]; then
            check_pair "$src" "$HOME/$rel" "~/$rel (volume seeded, not maintained)" wpstate
        elif [[ "$rel" == "$SEEDED_SCREENS" ]]; then
            check_pair "$src" "$HOME/$rel" "~/$rel (only the chosen arrangements)" screens
            report_screen_rates "$src" "$HOME/$rel" "~/$rel"
        elif [[ "$rel" == .local/state/wireplumber/* ]]; then
            check_pair "$src" "$HOME/$rel" "~/$rel (settings, not the device history)" wpstate
        else
            check_pair "$src" "$HOME/$rel" "~/$rel"
        fi
    done < <(find "$CFG" -type f | sort)
fi

check_pair "$REPO_DIR/dotfiles/zshrc"    "$HOME/.zshrc"    "~/.zshrc (minus the phoinix hook)" zshrc
check_pair "$REPO_DIR/dotfiles/p10k.zsh" "$HOME/.p10k.zsh" "~/.p10k.zsh"

# ---------------------------------------------------------------------------
# Files the REPO owns and the stages install verbatim.
#
# Added 2026-08-04, after this script did not catch the one drift that mattered
# that day: `system/wireplumber/50-phoinix-usb-headroom.conf` had been changed
# three times on the live machine and never written back, and a fresh install
# would have received the wrong audio configuration. The walk above only covers
# the CAPTURED tree under hosts/<host>/home/ — a file the repo authors and
# pushes out was outside its reach entirely.
REPO_OWNED=(
    "dotfiles/gitconfig|$HOME/.config/git/config"
    "dotfiles/ssh_config|$HOME/.ssh/config"
    "system/wireplumber/50-phoinix-usb-headroom.conf|$HOME/.config/wireplumber/wireplumber.conf.d/50-phoinix-usb-headroom.conf"
    "system/user/plasma-plasmashell.service.d/phoinix-shutdown.conf|$HOME/.config/systemd/user/plasma-plasmashell.service.d/phoinix-shutdown.conf"
    "system/user@.service.d/10-phoinix-realtime.conf|/etc/systemd/system/user@.service.d/10-phoinix-realtime.conf"
    "system/nftables.service.d/phoinix-remain.conf|/etc/systemd/system/nftables.service.d/phoinix-remain.conf"
    "system/NetworkManager/10-phoinix-dns.conf|/etc/NetworkManager/conf.d/10-phoinix-dns.conf"
    "system/applications/gpu-screen-recorder-ui.desktop|$HOME/.config/autostart/gpu-screen-recorder-ui.desktop"
    "system/zram-generator.conf|/etc/systemd/zram-generator.conf"
)

# Installed through a substitution, so the live file is SUPPOSED to differ —
# comparing bytes would report drift forever. Their presence is still checked:
# a missing one is a stage that did not run.
REPO_TEMPLATED=(
    "system/nftables.conf|/etc/nftables.conf"
    "system/applications/phoinix-monitor-switch.desktop|$HOME/.local/share/applications/phoinix-monitor-switch.desktop"
    "system/applications/phoinix-dzgui.desktop|$HOME/.local/share/applications/phoinix-dzgui.desktop"
    "system/user/phoinix-stage4.service|$HOME/.config/systemd/user/phoinix-stage4.service"
    "system/user/phoinix-playlist-export.service|$HOME/.config/systemd/user/phoinix-playlist-export.service"
    "system/user/phoinix-xlcore-backup.service|$HOME/.config/systemd/user/phoinix-xlcore-backup.service"
    "plasma/panels.js|"
    "system/NetworkManager/dispatcher.d/50-phoinix-vpn-dns|/etc/NetworkManager/dispatcher.d/50-phoinix-vpn-dns"
    "hosts/desktop/home/.config/kwinoutputconfig.json|/var/lib/plasmalogin/.config/kwinoutputconfig.json"
    "system/phoinix-vpn-dns.service|/etc/systemd/system/phoinix-vpn-dns.service"
    "scripts/qbittorrent-wrapper.sh|$HOME/.local/bin/qbittorrent"
)

for entry in "${REPO_OWNED[@]}"; do
    rel="${entry%%|*}"; dst="${entry#*|}"
    if [[ -f "$dst" && ! -r "$dst" ]]; then
        report volatile "$rel" "on the system but not readable without root — check by hand"
    else
        check_pair "$REPO_DIR/$rel" "$dst" "$rel"
    fi
done

for entry in "${REPO_TEMPLATED[@]}"; do
    rel="${entry%%|*}"; dst="${entry#*|}"
    [[ -n "$dst" ]] || continue          # panels.js is fed to plasmashell, never landed
    if [[ ! -f "$REPO_DIR/$rel" ]]; then
        report missing "$rel" "not in the repo"
    elif [[ ! -x "$(dirname "$dst")" ]]; then
        # /etc/sudoers.d is 0750 root:root — a normal user cannot even stat what
        # is inside it, and `! -e` would call a present file missing. Said out
        # loud rather than skipped: an unverifiable check must not look like a
        # passing one.
        report volatile "$rel" "$(dirname "$dst") is not readable without root — check by hand"
    elif [[ ! -e "$dst" ]]; then
        report missing "$rel" "installed nowhere: $dst is absent — did that stage run?"
    else
        report volatile "$rel" "templated at install — bytes cannot match by design"
    fi
done

# Does the table still cover what the stages actually install? Without this the
# list above rots the moment someone adds a file, which is exactly the failure
# it was written to fix.
uncovered=()
while IFS= read -r rel; do
    [[ -f "$REPO_DIR/$rel" ]] || continue
    covered=0
    for entry in "${REPO_OWNED[@]}" "${REPO_TEMPLATED[@]}"; do
        [[ "${entry%%|*}" == "$rel" ]] && covered=1
    done
    [[ "$rel" == dotfiles/zshrc || "$rel" == dotfiles/p10k.zsh ]] && covered=1
    [[ "$covered" == 0 ]] && uncovered+=("$rel")
done < <(grep -rhoE '\$REPO_DIR/(system|dotfiles|plasma)/[A-Za-z0-9._@/-]+' "$REPO_DIR"/base/*.sh \
         | sed 's|^\$REPO_DIR/||' | sort -u)

if (( ${#uncovered[@]} )); then
    drift=1
    printf '  ! the stages install files this check does not know about:\n'
    printf '      %s\n' "${uncovered[@]}"
    printf '      Add them to REPO_OWNED or REPO_TEMPLATED in this script.\n'
fi

# nss-resolve must stay OUT of the hosts line on a VPN host.
#
# A check rather than a file comparison, because the repo does not own
# /etc/nsswitch.conf: stage 2 edits the packaged file in place, since it is a
# pacman backup file and a repo copy would freeze upstream's other lines out
# forever.
#
# It is checked at all because the coupling is invisible. With `resolve` back in
# that line every nftables rule still loads, every counter still looks healthy,
# egress is still Proton — and the group's NAME lookups leave past the tunnel
# again with nothing to show for it. That was the true state from 2026-08-06
# until it was measured on 2026-09-01. A `.pacnew` from a `filesystem` update is
# how it comes back, so that is checked too.
if [[ -n "${VPN_CONFIG_DIR:-}" ]]; then
    if [[ ! -r /etc/nsswitch.conf ]]; then
        report volatile "/etc/nsswitch.conf (hosts: no nss-resolve)" \
            "not readable here — check by hand"
    elif grep -qE '^[[:space:]]*hosts:.*\bresolve\b' /etc/nsswitch.conf; then
        report drift "/etc/nsswitch.conf (hosts: no nss-resolve)" \
            "nss-resolve is back: the group's DNS never reaches dns_out and leaves past the tunnel — remove 'resolve' from the hosts line"
    else
        report same "/etc/nsswitch.conf (hosts: no nss-resolve)"
    fi
    if [[ -e /etc/nsswitch.conf.pacnew ]]; then
        report drift "/etc/nsswitch.conf.pacnew" \
            "a package update left a .pacnew — merge it, and keep 'resolve' out of the hosts line"
    fi
fi

# authorized_keys, compared by KEY MATERIAL only. The repo's copy deliberately
# carries a sanitised comment (`ulu@laptop`) where the live file has whatever
# ssh-keygen wrote — CLAUDE.md forbids a real name or address in any repo file,
# and a leak of exactly that kind once reached 35 commits. Comparing whole lines
# would therefore report drift forever and train everyone to ignore this check;
# comparing field 2 still catches what matters, which is a key that exists on
# one side and not the other. Found missing from this script on 2026-07-31,
# while checking that SSH would survive the reinstall.
keys_repo="$REPO_DIR/hosts/$HOST/authorized_keys"
if [[ -f "$keys_repo" && -f "$HOME/.ssh/authorized_keys" ]]; then
    a="$(awk '{print $2}' "$keys_repo" | sort | sha256sum | cut -d' ' -f1)"
    b="$(awk '{print $2}' "$HOME/.ssh/authorized_keys" | sort | sha256sum | cut -d' ' -f1)"
    if [[ "$a" == "$b" ]]; then
        report same "authorized_keys (key material)"
    else
        report drift "authorized_keys (key material)" \
            "a key exists on one side only — compare: awk '{print \$2}' on both files"
    fi
elif [[ -f "$keys_repo" ]]; then
    report volatile "authorized_keys" "none on this system to compare against"
else
    report missing "authorized_keys" "not in the repo: $keys_repo"
fi

echo
printf '  %d in sync, %d drifted, %d missing, %d expected to differ\n' \
    "$same" "$drifted" "$missing" "$volatile"
if [[ "$drift" == 1 ]]; then
    echo
    echo "  Something above no longer matches the repo. Decide which side is right:"
    echo "  copy the live file back into the repo, or re-run stage 3 to push the"
    echo "  repo's version out. Do not leave it disagreeing — that is how the"
    echo "  soundbar lost 2.77 dB without anyone noticing."
fi
exit "$drift"
