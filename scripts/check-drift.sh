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
    if [[ "$mode" == "zshrc" ]]; then
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
    "system/phoinix-vpn-dns.service|/etc/systemd/system/phoinix-vpn-dns.service"
    "scripts/qbittorrent-wrapper.sh|$HOME/.local/bin/qbittorrent"
    "system/phoinix-vpn-netns.service|/etc/systemd/system/phoinix-vpn-netns.service"
    "system/phoinix-qbt-netns.sh|/usr/local/sbin/phoinix-qbt-netns"
    "system/sudoers.d/phoinix-vpn|/etc/sudoers.d/phoinix-vpn"
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
