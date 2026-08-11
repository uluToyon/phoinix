#!/usr/bin/env bash
# greeter-screens.sh — give the login manager a screen layout that is only the
# real ones.
#
#   usage: greeter-screens.sh <host>      (asks for sudo)
#
# WHY THIS IS A SCRIPT AND NOT A LINE IN STAGE 3. Stage 3 hands the greeter a
# copy of kwinoutputconfig.json once, at install time. Every later change to the
# screen layout leaves that copy behind, and the symptom is not obvious: the
# desktop is right and only the login screen is wrong. Run this after
# rearranging monitors.
#
# WHY IT FILTERS. KWin remembers every screen COMBINATION it has ever seen. Some
# of those are learned during boots where not all outputs were up yet: every
# position sits at 0,0 in a row, and the primary is whichever screen happened to
# be ready first. At the login screen the outputs are ALSO not all initialised,
# so KWin matches one of exactly those — which is how ulu's password field ended
# up on the portrait monitor (2026-08-11).
#
# The user's own file cannot be fixed and there is no point trying: KWin holds
# the arrangements in memory and writes all of them back at logout. Pruning it
# lasted until the next reboot, measured. The greeter's copy is different — that
# KWin only ever READS it, so a filtered copy stays filtered.
#
# The filter is "the primary is PANEL_MAIN_CONNECTOR", which the host already
# declares for the panels. Nothing is invented here and nothing is discovered:
# an arrangement that does not put the main screen first is not a layout ulu
# chose.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?usage: greeter-screens.sh <host>}"

source "$REPO_DIR/config.sh"
source "$REPO_DIR/hosts/$HOST/config.sh"

SRC="$HOME/.config/kwinoutputconfig.json"

# Both names, because the greeter changed hands: plasma-login-manager runs as
# `plasmalogin`, SDDM as `sddm`, and a machine may carry either. Whichever
# exists gets the file — the same shape stage 3 uses everywhere else.
GREETER_USERS=(plasmalogin sddm)

[[ -f "$SRC" ]] || { echo "ERROR: $SRC does not exist"; exit 1; }
[[ -n "${PANEL_MAIN_CONNECTOR:-}" ]] || { echo "ERROR: PANEL_MAIN_CONNECTOR is not declared"; exit 1; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 - "$SRC" "$PANEL_MAIN_CONNECTOR" "$TMP" <<'PYEOF'
import json, sys

src, main, dst = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(src))

outputs = next((e["data"] for e in doc
                if isinstance(e, dict) and e.get("name") == "outputs"), None)
setups = next((e for e in doc
               if isinstance(e, dict) and e.get("name") == "setups"), None)
if outputs is None or setups is None:
    sys.exit("ERROR: this file has neither an 'outputs' nor a 'setups' section")

name = {i: o.get("connectorName") for i, o in enumerate(outputs)
        if isinstance(o, dict)}

kept, dropped = [], []
for s in setups["data"]:
    primary = [name.get(o.get("outputIndex")) for o in s.get("outputs", [])
               if o.get("priority") == 1]
    conns = sorted(c for c in
                   (name.get(o.get("outputIndex")) for o in s.get("outputs", []))
                   if c)
    (kept if primary == [main] else dropped).append((conns, primary))
    if primary == [main]:
        s["_keep"] = True

setups["data"] = [s for s in setups["data"] if s.pop("_keep", False)]

for conns, primary in kept:
    print(f"  keep  {len(conns)} screens {conns}  primary={primary[0]}")
for conns, primary in dropped:
    print(f"  drop  {len(conns)} screens {conns}  primary={primary[0] if primary else '—'}")

if not setups["data"]:
    sys.exit(f"ERROR: nothing left — no arrangement has {main} as its primary. "
             "Refusing to hand the greeter an empty layout, which is a black "
             "login screen.")

json.dump(doc, open(dst, "w"), indent=4)
print(f"\n{len(setups['data'])} arrangement(s) kept for the greeter.")
PYEOF

installed=0
for u in "${GREETER_USERS[@]}"; do
    home="$(getent passwd "$u" | cut -d: -f6)" || continue
    [[ -n "$home" ]] || continue

    sudo install -d -o "$u" -g "$u" -m 700 "$home/.config"
    # Keep the previous one. This runs with sudo against a file that decides
    # whether the login screen appears at all; a copy costs nothing and is the
    # difference between a mistake and a lockout.
    # `if`, not `&&`: under `set -e` a failing test at the head of an && chain
    # is the script's exit status, so the very first run on a fresh machine --
    # where there is no previous file -- would abort here.
    if sudo test -f "$home/.config/kwinoutputconfig.json"; then
        sudo cp -a "$home/.config/kwinoutputconfig.json" \
                   "$home/.config/kwinoutputconfig.json.bak"
    fi
    sudo install -m644 -o "$u" -g "$u" "$TMP" "$home/.config/kwinoutputconfig.json"
    echo "greeter: layout installed for $u (previous kept as .bak)"
    installed=$((installed + 1))
done

if (( installed == 0 )); then
    echo "ERROR: no greeter user found (${GREETER_USERS[*]}) — nothing installed"
    exit 1
fi
echo "         the password field belongs on $PANEL_MAIN_CONNECTOR — verify at the next login"
