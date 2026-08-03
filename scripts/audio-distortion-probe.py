#!/usr/bin/env python3
"""Measure what the loudspeakers add that the computer never sent.

Two recordings of the same minutes: the digital signal leaving the machine, and
a microphone in front of the speaker. Everything in the microphone that the
digital signal does not account for was produced after the computer — by the
USB link, the converter, the amplifier or the drivers.

Why the comparison is a BALANCE and not a level: room response, microphone
gain and distance are unknown, but they are CONSTANT. Distortion is not — it
adds harmonics, so it raises the ratio of high-frequency to low-frequency
energy in the microphone without changing anything in the output. That ratio
is therefore the signal to look for, and it survives an unknown room.

Two corrections are not optional, both learned the hard way on 2026-08-03:

  * ALIGNMENT. The microphone hears the room, delayed and smeared by
    reverberation, while the monitor is the sample of this instant. Unaligned,
    the spread of the ratio was 14.6 dB and swallowed every event. The delay is
    found by cross-correlating the envelopes; it also proves the two recordings
    belong together at all.
  * LEVEL MATCHING. At a quiet passage the microphone hears mostly the room, so
    the ratio rises for a reason that has nothing to do with distortion. Each
    output level therefore gets its own baseline, and an event has to stand out
    against blocks of the SAME loudness.

Recording (do NOT use `pw-record --target`: it silently falls back to the
default source, which cost an entire evening on 2026-08-03 — three separate
"paired" recordings turned out to be the same stream twice; verify with
`pw-link -l` that the two recorders sit on different nodes):

  parec -d <sink>.monitor --format=s16le --rate=48000 --channels=6 \
        --file-format=wav mon.wav &
  parec -d <mic-source> --format=s16le --rate=48000 --channels=1 \
        --file-format=wav mic.wav &

Usage: audio-distortion-probe.py mic.wav mon.wav [monitor-channels]
"""
import array
import math
import statistics
import sys

SR = 48000
BLK = 4800                     # 100 ms — long enough to average out reverb
SPLIT = 4000                   # Hz, boundary between "low" and "high"
FLOOR = -45.0                  # dBFS, below this the output is not usable
SIGMA = 3.0                    # threshold in standard deviations

db = lambda v: -99.0 if v <= 0 else 20 * math.log10(v / 32768)


class HighPass:
    """Two cascaded one-pole sections, state preserved across chunks."""

    def __init__(self, fc):
        rc = 1 / (2 * math.pi * fc)
        self.a = rc / (rc + 1 / SR)
        self.py = [0.0, 0.0]
        self.px = [0.0, 0.0]

    def run(self, x):
        for stage in (0, 1):
            a, py, px = self.a, self.py[stage], self.px[stage]
            out = [0.0] * len(x)
            for i, v in enumerate(x):
                py = a * (py + v - px)
                px = v
                out[i] = py
            self.py[stage], self.px[stage] = py, px
            x = out
        return x


def envelopes(path, channels):
    """[(rms_total, rms_above_SPLIT)] per block. Streams; never loads the file."""
    fh = open(path, 'rb')
    fh.seek(44)                                   # WAV header
    hp = HighPass(SPLIT)
    out = []
    while True:
        raw = fh.read(BLK * channels * 2 * 40)
        if not raw:
            break
        a = array.array('h')
        a.frombytes(raw[:len(raw) // (2 * channels) * 2 * channels])
        if channels > 1:
            mono = [float(sum(a[i:i + channels])) for i in range(0, len(a), channels)]
        else:
            mono = [float(v) for v in a]
        high = hp.run(mono)
        for i in range(0, len(mono) - BLK + 1, BLK):
            lo, hi = mono[i:i + BLK], high[i:i + BLK]
            out.append((math.sqrt(sum(v * v for v in lo) / BLK),
                        math.sqrt(sum(v * v for v in hi) / BLK)))
    return out


def find_lag(mic, mon, span=30):
    """Blocks the microphone lags behind the monitor, by envelope correlation."""
    n = min(len(mic), len(mon))
    lm = [db(v[0]) for v in mic[:n]]
    lo = [db(v[0]) for v in mon[:n]]
    am = [v - statistics.mean(lm) for v in lm]
    ao = [v - statistics.mean(lo) for v in lo]
    den = math.sqrt(sum(v * v for v in am)) * math.sqrt(sum(v * v for v in ao))
    if den == 0:
        return 0, 0.0
    best = (0, -2.0)
    for lag in range(-span, span + 1):
        if lag >= 0:
            s = sum(am[i + lag] * ao[i] for i in range(n - lag))
        else:
            s = sum(am[i] * ao[i - lag] for i in range(n + lag))
        c = s / den
        if c > best[1]:
            best = (lag, c)
    return best


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    mic = envelopes(sys.argv[1], 1)
    mon = envelopes(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 6)

    lag, corr = find_lag(mic, mon)
    print(f"Versatz {lag * BLK / SR * 1000:+.0f} ms, Korrelation {corr:.3f}")
    if corr < 0.4:
        print("WARNUNG: zu geringe Korrelation — hört das Mikrofon diesen Ausgang "
              "wirklich? Bei Korrelation nahe 1.0 sind es zwei Mitschnitte "
              "DERSELBEN Quelle, das ist der klassische Aufnahmefehler.")
    if lag < 0:
        mon = mon[-lag:]
    else:
        mic = mic[lag:]

    n = min(len(mic), len(mon))
    rows = [(i, db(mon[i][0]), db(mic[i][1]) - db(mon[i][1]))
            for i in range(n)
            if mic[i][1] > 0 and mon[i][1] > 0 and db(mon[i][0]) > FLOOR]
    if not rows:
        sys.exit("Kein verwertbares Ausgangssignal.")

    bins = {}
    for i, level, ratio in rows:
        bins.setdefault(int(level // 5) * 5, []).append((i, ratio))

    print(f"\n{len(rows)} Blöcke à {BLK/SR*1000:.0f} ms mit hörbarem Ausgang")
    print("Pegel        n   Median  Streuung")
    baseline = {}
    for k in sorted(bins):
        vals = [r for _, r in bins[k]]
        if len(vals) < 20:
            continue
        baseline[k] = (statistics.median(vals), statistics.pstdev(vals))
        print(f" {k:4d}..{k+5:4d} {len(vals):4d}  {baseline[k][0]:+6.1f}  {baseline[k][1]:6.1f}")

    events = []
    for k, entries in bins.items():
        if k not in baseline:
            continue
        med, sd = baseline[k]
        for i, ratio in entries:
            if ratio > med + SIGMA * sd:
                events.append((i * BLK / SR, ratio - med, k))
    events.sort()

    print(f"\nHochtonüberschuss über {SIGMA:.0f} Streuungen: {len(events)} Blöcke")
    for t, excess, k in events:
        print(f"  {t:8.2f}s  +{excess:5.1f} dB  (Ausgangspegel {k}..{k+5} dBFS)")
    if events:
        span = events[-1][0] - events[0][0]
        print(f"\nZeitfenster {events[0][0]:.1f}s bis {events[-1][0]:.1f}s ({span:.0f}s). "
              "Häufen sie sich in einem Fenster, ist es ein Anfall und kein Rauschen.")


main()
