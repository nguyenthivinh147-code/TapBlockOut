#!/usr/bin/env python3
"""Xu ly am thanh (chi thu vien chuan). Chay: python3 -I tools/process_audio.py <sfx|music> in.wav out.wav [...]
sfx  : mono 44.1 kHz 16-bit, cat khoang lang dau/cuoi, cat toi da max_sec, fade, can peak. Tham so: [max_sec].
music: stereo; 40 Hz high-pass and an optional low shelf, a loop cut from the source with a crossfade from the
       pre-roll, integrated loudness (LUFS) to a target with a peak cap. Options key=value: start=, len=, xfade=
       (seconds), lufs=, shelf=<gain_db>@<hz>. Without start/len the loop is the whole file after a 4 s crossfade.
In ra mot dong JSON gom thong so sau xu ly."""
import array
import json
import math
import sys
import warnings
import wave

warnings.filterwarnings("ignore")
import audioop  # noqa: E402

SR = 44100
SFX_PEAK_DB = -3.0
MUSIC_LUFS = -18.0
MUSIC_PEAK_DB = -2.0
MUSIC_HPF_HZ = 40.0
SILENCE_DB = -48.0  # so voi dinh
LOOP_XFADE_S = 4.0


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2 and w.getframerate() == SR, "can WAV 16-bit 44.1k"
        return w.getnchannels(), w.readframes(w.getnframes())


def write_wav(path, ch, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def db(x):
    return 20 * math.log10(x) if x > 0 else -999.0


def peak_of(data):
    return audioop.max(data, 2) / 32768.0


def rms_of(data):
    return audioop.rms(data, 2) / 32768.0 if data else 0.0


def to_mono(ch, data):
    return audioop.tomono(data, 2, 0.5, 0.5) if ch == 2 else data


def scale(data, gain):
    return audioop.mul(data, 2, gain) if gain != 1.0 else data


def trim_silence(data, ch, thresh_db, pre_ms=2, post_ms=10):
    """Cat khoang lang theo moc cua so 2 ms."""
    pk = peak_of(data)
    thr = int(32768 * pk * 10 ** (thresh_db / 20))
    frame = 2 * ch
    win = int(SR * 0.002)
    n = len(data) // frame
    first, last = 0, n
    for i in range(0, n, win):
        if audioop.max(data[i * frame:(i + win) * frame], 2) > thr:
            first = i
            break
    for i in range(((n - 1) // win) * win, -1, -win):
        if audioop.max(data[i * frame:min(n, i + win) * frame], 2) > thr:
            last = min(n, i + win)
            break
    first = max(0, first - int(SR * pre_ms / 1000))
    last = min(n, last + int(SR * post_ms / 1000))
    return data[first * frame:last * frame]


def fade(data, ch, in_s, out_s):
    a = array.array("h")
    a.frombytes(data)
    n = len(a) // ch
    fi = min(n, int(SR * in_s))
    fo = min(n, int(SR * out_s))
    for i in range(fi):
        g = math.sin(0.5 * math.pi * i / fi)
        for c in range(ch):
            a[i * ch + c] = int(a[i * ch + c] * g)
    for i in range(fo):
        g = math.cos(0.5 * math.pi * i / fo)
        k = n - fo + i
        for c in range(ch):
            a[k * ch + c] = int(a[k * ch + c] * g)
    return a.tobytes()


def process_sfx(src, dst, max_sec):
    ch, data = read_wav(src)
    data = to_mono(ch, data)
    data = trim_silence(data, 1, SILENCE_DB)
    cap = int(SR * max_sec)
    if len(data) // 2 > cap:
        data = data[:cap * 2]
    n = len(data) // 2
    data = fade(data, 1, 0.002, min(0.08, max(0.02, 0.25 * n / SR)))
    pk = peak_of(data)
    gain = 10 ** (SFX_PEAK_DB / 20) / pk if pk > 0 else 1.0
    data = scale(data, gain)
    write_wav(dst, 1, data)
    return {"channels": 1, "seconds": round(len(data) / 2 / SR, 3), "peak_db": round(db(peak_of(data)), 2),
            "rms_db": round(db(rms_of(data)), 2)}


def rbj(kind, f0, q, gain_db=0.0):
    """Biquad coefficients (b0, b1, b2, a1, a2) from the RBJ audio EQ cookbook, divided by a0."""
    w = 2 * math.pi * f0 / SR
    cw, alpha = math.cos(w), math.sin(w) / (2 * q)
    g = 10 ** (gain_db / 40)
    sa = 2 * math.sqrt(g) * alpha
    if kind == "highpass":
        b, a = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2), (1 + alpha, -2 * cw, 1 - alpha)
    elif kind == "lowshelf":
        b = (g * ((g + 1) - (g - 1) * cw + sa), 2 * g * ((g - 1) - (g + 1) * cw), g * ((g + 1) - (g - 1) * cw - sa))
        a = ((g + 1) + (g - 1) * cw + sa, -2 * ((g - 1) + (g + 1) * cw), (g + 1) + (g - 1) * cw - sa)
    else:  # highshelf
        b = (g * ((g + 1) + (g - 1) * cw + sa), -2 * g * ((g - 1) + (g + 1) * cw), g * ((g + 1) + (g - 1) * cw - sa))
        a = ((g + 1) - (g - 1) * cw + sa, 2 * ((g - 1) - (g + 1) * cw), (g + 1) - (g - 1) * cw - sa)
    return tuple(v / a[0] for v in (*b, a[1], a[2]))


def biquad(xs, coef):
    """One biquad (direct form I) over a sequence of floats."""
    b0, b1, b2, a1, a2 = coef
    x1 = x2 = y1 = y2 = 0.0
    out = array.array("d", bytes(8 * len(xs)))
    for i, x0 in enumerate(xs):
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x0, y1, y0
        out[i] = y0
    return out


def kweight(xs):
    """K-weighting of ITU-R BS.1770, with the same filters as pyloudnorm."""
    return biquad(biquad(xs, rbj("highshelf", 1500.0, 1 / math.sqrt(2), 4.0)), rbj("highpass", 38.0, 0.5))


def loudness(kws, a, b):
    """Ungated loudness (LUFS) of samples a..b of K-weighted channels."""
    p = sum(sum(v * v for v in kw[a:b]) for kw in kws) / (b - a)
    return -0.691 + 10 * math.log10(p) if p > 0 else -999.0


def lufs(chans):
    """Integrated loudness by ITU-R BS.1770: 400 ms blocks every 100 ms, absolute gate -70 LUFS, relative gate -10 LU."""
    step = SR // 10
    power = None
    for xs in chans:
        y = kweight(xs)
        sq = [sum(v * v for v in y[i:i + step]) for i in range(0, len(y) - step + 1, step)]
        blocks = [(sq[j] + sq[j + 1] + sq[j + 2] + sq[j + 3]) / (4 * step) for j in range(len(sq) - 3)]
        power = blocks if power is None else [p + q for p, q in zip(power, blocks)]
    loud = [-0.691 + 10 * math.log10(p) if p > 0 else -999.0 for p in power]
    gated = [p for p, lj in zip(power, loud) if lj >= -70.0]
    rel = -0.691 + 10 * math.log10(sum(gated) / len(gated)) - 10.0
    kept = [p for p, lj in zip(power, loud) if lj >= -70.0 and lj > rel]
    return -0.691 + 10 * math.log10(sum(kept) / len(kept))


def process_music(src, dst, opts):
    ch, data = read_wav(src)
    a = array.array("h")
    a.frombytes(data)
    n = len(a) // ch
    x = int(SR * float(opts.get("xfade", LOOP_XFADE_S)))
    s = int(SR * float(opts.get("start", LOOP_XFADE_S)))
    m = int(SR * float(opts["len"])) if "len" in opts else n - s
    if not (0 < x <= s and x < m and s + m <= n):
        sys.exit("need 0 < xfade <= start, xfade < len, start + len <= file length")
    eq = [rbj("highpass", MUSIC_HPF_HZ, 1 / math.sqrt(2))]
    if "shelf" in opts:
        gain_db, hz = opts["shelf"].split("@")
        eq.append(rbj("lowshelf", float(hz), 1 / math.sqrt(2), float(gain_db)))
    # The buffers start 4 s before the pre-roll: 1 s for the filters to settle, 3 s for the drift window.
    lo = max(0, s - x - 4 * SR)
    o = s - lo
    bufs = []
    for c in range(ch):
        ys = [v / 32768.0 for v in a[lo * ch + c:(s + m) * ch:ch]]
        for coef in eq:
            ys = biquad(ys, coef)
        bufs.append(ys)
    # Loudness drift (generated music often swells over time): a gain ramp linear in dB, 0 at start, brings the last
    # 3 s of the loop to the loudness of the 3 s before start, which is what leads into start in the source.
    kws = [kweight(ys) for ys in bufs]
    w = min(3 * SR, o)
    drift = loudness(kws, o + m - w, o + m) - loudness(kws, o - w, o)
    k = -drift * math.log(10) / 20 / m
    loop = []
    for ys in bufs:
        for i in range(len(ys)):
            ys[i] *= math.exp(k * (i - o))
        y = ys[o:o + m]
        # Over its last x samples the loop fades into the x samples before start, so its end runs on into its first
        # sample, source[start]. Equal-power gains scaled by the correlation r of the two parts: no +3 dB bump when
        # they are nearly the same audio (r = 1 gives a linear fade).
        old, new = y[m - x:m], ys[o - x:o]
        dot = sum(p * q for p, q in zip(old, new))
        norm = math.sqrt(sum(p * p for p in old) * sum(q * q for q in new))
        r = min(1.0, max(0.0, dot / norm)) if norm > 0 else 0.0
        for i in range(x):
            w = 0.5 * math.pi * i / (x - 1)
            y[m - x + i] = (old[i] * math.cos(w) + new[i] * math.sin(w)) / math.sqrt(1 + r * math.sin(2 * w))
        loop.append(y)
    level = lufs(loop)
    peak = max(max(abs(v) for v in y) for y in loop)
    gain = min(10 ** ((float(opts.get("lufs", MUSIC_LUFS)) - level) / 20), 10 ** (MUSIC_PEAK_DB / 20) / peak)
    out = array.array("h", bytes(2 * m * ch))
    for c, y in enumerate(loop):
        for i, v in enumerate(y):
            out[i * ch + c] = max(-32768, min(32767, round(v * gain * 32768)))
    out = out.tobytes()
    write_wav(dst, ch, out)
    res = loop_report(ch, out)
    res["lufs"] = round(level + 20 * math.log10(gain), 2)
    res["drift_db"] = round(drift, 2)
    return res


def loop_report(ch, data):
    """So mau cuoi/dau: do nhay tai moi noi so voi do nhay trung binh gan do."""
    a = array.array("h")
    a.frombytes(data)
    n = len(a) // ch
    seam = max(abs(a[c] - a[(n - 1) * ch + c]) for c in range(ch))
    typical = 0
    for i in range(1000, n - 1, 977):
        typical = max(typical, max(abs(a[(i + 1) * ch + c] - a[i * ch + c]) for c in range(ch)))
    return {"channels": ch, "seconds": round(n / SR, 3), "peak_db": round(db(peak_of(data)), 2),
            "rms_db": round(db(rms_of(data)), 2), "seam_step": seam, "max_step_sampled": typical}


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    kind, src, dst = sys.argv[1:4]
    if kind == "sfx":
        res = process_sfx(src, dst, float(sys.argv[4]) if len(sys.argv) > 4 else 3.0)
    else:
        res = process_music(src, dst, dict(arg.split("=", 1) for arg in sys.argv[4:]))
    print(json.dumps(res))


if __name__ == "__main__":
    main()
