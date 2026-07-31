#!/usr/bin/env bash
# strawberry-playlist-export.sh — write a Strawberry playlist back out as .m3u
#
#   usage: strawberry-playlist-export.sh <host>
#
# Strawberry exports a playlist only when you ask it to, and the export is a
# one-off snapshot: extend the playlist and the file silently stays behind.
# That breaks the one property the file is kept for — being the copy that
# survives a reinstall. This closes the gap from the other side by reading
# Strawberry's database and rewriting the file.
#
# Target file and playlist name come from hosts/<host>/config.sh
# (PLAYLIST_FILE, PLAYLIST_NAME) — the same two values stage 4 imports from.
#
# Paths are written RELATIVE to the playlist file's own directory, exactly as
# Strawberry's "Relative path" save option does, so the file keeps working when
# the disk is mounted somewhere else.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: strawberry-playlist-export.sh <host>   (e.g. desktop)}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

DB="$HOME/.local/share/strawberry/strawberry/strawberry.db"

[[ -n "${PLAYLIST_FILE:-}" ]] || { echo "ERROR: PLAYLIST_FILE not set for host $HOST"; exit 1; }
[[ -f "$DB" ]] || { echo "ERROR: no Strawberry database at $DB"; exit 1; }

BASE_DIR="$(dirname "$PLAYLIST_FILE")"

# This runs at session exit, when the data disks may already be going away.
# Writing into a missing mount point would create the file on the ROOT
# filesystem under /mnt/..., which then shadows the real disk at the next boot.
[[ -d "$BASE_DIR" ]] || { echo "WARNING: $BASE_DIR not present (disk unmounted?) — nothing exported"; exit 0; }

# Read-only: Strawberry normally has this database open. Items reference the
# collection by id rather than carrying a path, so the songs table has to be
# joined in. pi.ROWID is the playlist order — there is no position column.
rows="$(sqlite3 -separator $'\t' "file:$DB?mode=ro" "
    SELECT s.url, s.length, s.artist, s.title
    FROM playlist_items pi
    JOIN songs s ON s.ROWID = pi.collection_id
    WHERE pi.playlist = (SELECT ROWID FROM playlists WHERE name = '${PLAYLIST_NAME//\'/\'\'}')
    ORDER BY pi.ROWID;" 2>/dev/null || true)"

if [[ -z "$rows" ]]; then
    echo "WARNING: playlist '$PLAYLIST_NAME' is empty or absent — $PLAYLIST_FILE left untouched"
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '#EXTM3U\n' > "$tmp"

count=0
while IFS=$'\t' read -r url length artist title; do
    [[ -n "$url" ]] || continue
    # file:///path with percent-encoding -> plain bytes. Turning every % into
    # \x and letting printf %b decode handles UTF-8 too, since each byte is
    # encoded separately (a literal % arrives as %25 and decodes back).
    path="${url#file://}"
    path="$(printf '%b' "${path//%/\\x}")"
    # Only entries below the playlist's own directory can be relative.
    case "$path" in
        "$BASE_DIR"/*) rel="${path#"$BASE_DIR"/}" ;;
        *) rel="$path" ;;   # outside the tree: keep it absolute, still correct
    esac
    secs=$(( ${length:-0} / 1000000000 ))   # Strawberry stores nanoseconds
    printf '#EXTINF:%s,%s - %s\n%s\n' "$secs" "$artist" "$title" "$rel" >> "$tmp"
    count=$((count + 1))
done <<< "$rows"

if [[ "$count" -eq 0 ]]; then
    echo "WARNING: nothing resolved — $PLAYLIST_FILE left untouched"
    exit 0
fi

# Keep one generation back. This file is ulu's own curation, built over years;
# a bad export must never be the only thing left.
[[ -f "$PLAYLIST_FILE" ]] && cp -p "$PLAYLIST_FILE" "$PLAYLIST_FILE.bak"

install -m644 "$tmp" "$PLAYLIST_FILE"
echo "exported $count tracks from '$PLAYLIST_NAME' to $PLAYLIST_FILE"
