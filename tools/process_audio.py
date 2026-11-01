#!/usr/bin/env python3
"""Xu ly am thanh (chi thu vien chuan). Chay: python3 -I tools/process_audio.py <sfx|music> in.wav out.wav [max_sec]
sfx  : mono 44.1 kHz 16-bit, cat khoang lang dau/cuoi, cat toi da max_sec, fade, can peak.
music: giu stereo, crossfade duoi vao dau de lap lien, can RMS, chan clip.
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
MUSIC_RMS_DB = -21.0
MUSIC_PEAK_DB = -2.0
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


def process_music(src, dst, _unused):
    ch, data = read_wav(src)
    frame = 2 * ch
    a = array.array("h")
    a.frombytes(data)
    n = len(a) // ch
    x = int(SR * LOOP_XFADE_S)
    m = n - x
    y = array.array("h", a[x * ch:n * ch])  # y = x[N:L]
    # trong N mau cuoi cua y, tron dan sang x[0:N] (equal-power) de y[M-1] noi lien y[0]=x[N]
    for i in range(x):
        w = i / (x - 1)
        g_old = math.cos(0.5 * math.pi * w)
        g_new = math.sin(0.5 * math.pi * w)
        for c in range(ch):
            k = (m - x + i) * ch + c
            v = a[(n - x + i) * ch + c] * g_old + a[i * ch + c] * g_new
            y[k] = max(-32768, min(32767, int(v)))
    out = y.tobytes()
    # can RMS nhung khong de dinh vuot MUSIC_PEAK_DB
    pk, rm = peak_of(out), rms_of(out)
    gain = min(10 ** (MUSIC_RMS_DB / 20) / rm, 10 ** (MUSIC_PEAK_DB / 20) / pk)
    out = scale(out, gain)
    write_wav(dst, ch, out)
    return loop_report(ch, out)


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
    max_sec = float(sys.argv[4]) if len(sys.argv) > 4 else 3.0
    res = process_sfx(src, dst, max_sec) if kind == "sfx" else process_music(src, dst, None)
    print(json.dumps(res))


if __name__ == "__main__":
    main()
