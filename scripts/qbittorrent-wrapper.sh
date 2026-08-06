#!/usr/bin/env bash
# Installed by stage 3 as ~/.local/bin/qbittorrent, with @HOST@ substituted.
#
# Closes the last way to start an unprotected client. The desktop entry was
# already covered — hosts/<host>/home does not carry it, stage 3 writes
# ~/.local/share/applications/org.qbittorrent.qBittorrent.desktop under the
# SAME file name as the packaged one, so menu, KRunner and magnet links all
# reach the launcher. Stage 3 also defines a shell alias — but an alias exists
# only in an interactive zsh. It does nothing in bash, in a script, under
# `sh -c`, in a systemd unit or anywhere else a program is executed by name,
# and each of those would have started a client in ulu's ordinary groups with
# not one kernel rule matching it. Only qBittorrent's own "bind to proton0"
# setting stood between that and a torrent client on the open line — an
# application promising something about itself, which is exactly the assurance
# this repo does not accept anywhere else.
#
# ~/.local/bin comes before /usr/bin in PATH, so this wins. The launcher it
# calls uses the ABSOLUTE path to the real binary, or the two would call each
# other forever.
exec "$HOME/phoinix/scripts/qbittorrent-vpn.sh" "@HOST@" "$@"
