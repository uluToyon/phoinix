#!/usr/bin/env bash
# bootstrap.sh — THE one command. Runs on the Arch ISO, as root.
#
#   curl -fsSL https://raw.githubusercontent.com/uluToyon/phoinix/main/scripts/bootstrap.sh | bash -s desktop
#   curl -fsSL .../bootstrap.sh | bash -s desktop v1.0     # pin to a tag
#
# Why this exists: stage 1 cannot be piped into bash on its own. It sources
# config.sh and hosts/<host>/config.sh, reads packages/pacstrap.txt and rsyncs
# the whole repo into the target for stage 2 — none of which a single piped
# file has. So the one-liner fetches THIS, and this clones the repo.
#
# It then drives the install end to end:
#   stage 1 (destructive)  ->  stage 2 (chroot)  ->  unmount  ->  reboot
# Stage 3 arms itself at the first login (set up by stage 2), stage 4 at the
# first graphical login (set up by stage 3). Human input needed: the password
# for the user account, later the sudo password. Nothing else.

set -euo pipefail

HOST="${1:?usage: bootstrap.sh <host> [git-ref]   (e.g. bootstrap.sh desktop)}"
REF="${2:-}"

REPO_URL="${PHOINIX_REPO_URL:-https://github.com/uluToyon/phoinix}"
CLONE_DIR="${PHOINIX_CLONE_DIR:-/root/phoinix}"

[[ $EUID -eq 0 ]] || { echo "ERROR: run as root (the Arch ISO logs you in as root)"; exit 1; }

# Under `curl | bash` stdin is the pipe bash is READING THIS SCRIPT FROM, and
# two separate things go wrong with it:
#   - a child that reads stdin (pacman asking "Proceed with installation?")
#     eats the script text instead of getting an answer;
#   - `exec < /dev/tty` to fix that destroys the script source itself. bash
#     then reads the rest of the "script" from the terminal and the installer
#     silently does nothing. Verified in QEMU, then reduced to:
#       printf 'echo A\nexec < /dev/null\necho B\n' | bash   # prints only A
# So: never `exec` here, redirect PER COMMAND. The shell keeps reading the
# script from the pipe, and each stage still gets a real terminal.
# The test must be an actual open in a subshell — `[[ -r /dev/tty ]]` reads the
# permission bits and says yes even where there is no controlling terminal.
TTY_IN=/dev/null
if ( : < /dev/tty ) 2>/dev/null; then
    TTY_IN=/dev/tty
fi

# ------------------------------------------------------------------ clone
command -v git >/dev/null || pacman -Sy --noconfirm git

if [[ -d "$CLONE_DIR/.git" ]]; then
    # A previous run got this far. Keep the working tree as it is — a hand-fix
    # applied after a failed stage is exactly what a re-run wants to keep.
    echo ">> $CLONE_DIR already exists, using it as-is."
else
    git clone "$REPO_URL" "$CLONE_DIR"
fi

if [[ -n "$REF" ]]; then
    git -C "$CLONE_DIR" fetch --tags origin
    git -C "$CLONE_DIR" checkout --detach "$REF"
fi

echo
echo "phoinix bootstrap"
echo "  host:   $HOST"
echo "  repo:   $CLONE_DIR ($(git -C "$CLONE_DIR" describe --always --dirty))"
echo

# ------------------------------------------------------------ stages 1 + 2
# Stage 1 is the destructive one and does its own confirming (see its header:
# the target disk is identified by /dev/disk/by-id/, which does not exist on
# the wrong machine, plus a countdown). Everything after it is re-runnable.
"$CLONE_DIR/base/stage1.sh" "$HOST" < "$TTY_IN"

# Stage 1 rsynced the repo to /mnt/root/phoinix — stage 2 runs from THAT copy,
# not from ours, so the chroot is self-contained if this shell dies.
arch-chroot /mnt /root/phoinix/base/stage2.sh "$HOST" < "$TTY_IN"

# ----------------------------------------------------------------- reboot
# A single open file under /mnt makes `umount -R` fail "target is busy" and
# stopped a whole run here — the holder was a diagnostic SSH session running
# tail -F on stage2.log, i.e. purely read access. Retry briefly (a closing
# session releases it), then NAME the holders instead of dying cryptically.
for i in 1 2 3 4 5; do
    umount -R /mnt 2>/dev/null && break
    [[ $i -lt 5 ]] && sleep 2
done
if mountpoint -q /mnt; then
    echo "ERROR: /mnt is still busy after 5 tries. Holding it open:"
    fuser -vm /mnt || true
    echo "Close whatever that is (an SSH session reading a log qualifies),"
    echo "then finish by hand:  umount -R /mnt && reboot"
    exit 1
fi

echo
echo "Stages 1 and 2 are done. Rebooting into the new system."
echo "Log in as the user you just set a password for — stage 3 starts itself."
echo
for ((i = 10; i > 0; i--)); do
    printf '\r  reboot in %2ds  (Ctrl-C to stay on the ISO) ' "$i"
    sleep 1
done
printf '\r%*s\r' 55 ''

reboot
