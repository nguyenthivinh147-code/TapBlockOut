#!/usr/bin/env python3
"""Background music checks against docs/AUDIO_MUSIC.md (dev only, not in the build). Needs numpy, scipy, soundfile:
  uv run --no-project --with numpy --with scipy --with soundfile python -I tools/music_check.py <cmd> ...

  report <file> --kind home|level        measures a finished loop (ogg/wav/flac) and marks each criterion ok/FAIL
  loops <source> --bpm B --min S --max S  bar-aligned loop candidates in a generated source, start on a downbeat
  seam <loop> --bpm B [--source F --start S]
                                          the wrap of a finished loop; with the source, compares it with the
                                          transition into start in the source
Exit code 1 when a report has a FAIL."""
import argparse
import json
import math
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

HOP, NFFT = 512, 2048
# docs/AUDIO_MUSIC.md section 3.2
STANDARD = {
    "home": {"lufs": (-19.0, -17.0), "lra_max": 6.0, "bpm": (95.0, 105.0), "presence_max": -20.0,
             "loop_s": (60.0, 90.0)},
    "level": {"lufs": (-21.0, -19.0), "lra_max": 4.0, "bpm": (75.0, 85.0), "presence_max": -30.0,
              "loop_s": (80.0, 150.0)},
}
COMMON = {"true_peak_max": -1.0, "bpm_jitter_max": 1.0, "phone_loss_max": 5.0, "sub_max": -12.0,
          "mono_loss_max": 3.0, "lr_corr_min": 0.3, "silence_max_s": 0.3, "size_mb_max": 1.5}


def read(path):
    x, sr = sf.read(path, dtype="float64", always_2d=True)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return sr, x


def rbj(kind, f0, q, gain_db, sr):
    """Same biquads as tools/process_audio.py (RBJ cookbook), as (b, a)."""
    w = 2 * math.pi * f0 / sr
    cw, alpha = math.cos(w), math.sin(w) / (2 * q)
    g = 10 ** (gain_db / 40)
    sa = 2 * math.sqrt(g) * alpha
    if kind == "highpass":
        b, a = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2], [1 + alpha, -2 * cw, 1 - alpha]
    else:  # highshelf
        b = [g * ((g + 1) + (g - 1) * cw + sa), -2 * g * ((g - 1) + (g + 1) * cw), g * ((g + 1) + (g - 1) * cw - sa)]
        a = [(g + 1) - (g - 1) * cw + sa, 2 * ((g - 1) - (g + 1) * cw), (g + 1) - (g - 1) * cw - sa]
    return np.array(b) / a[0], np.array(a) / a[0]


def kweight(x, sr):
    for b, a in (rbj("highshelf", 1500.0, 1 / math.sqrt(2), 4.0, sr), rbj("highpass", 38.0, 0.5, 0.0, sr)):
        x = signal.lfilter(b, a, x, axis=0)
    return x


def window_power(kw, sr, win_s, hop_s):
    win, hop = int(win_s * sr), int(hop_s * sr)
    cs = np.vstack([np.zeros((1, kw.shape[1])), np.cumsum(kw * kw, axis=0)])
    starts = np.arange(0, len(kw) - win + 1, hop)
    return starts / sr, ((cs[starts + win] - cs[starts]) / win).sum(axis=1)


def to_lufs(p):
    return -0.691 + 10 * np.log10(np.maximum(p, 1e-20))


def integrated(x, sr):
    """ITU-R BS.1770: 400 ms blocks every 100 ms, gates -70 LUFS and -10 LU."""
    _, p = window_power(kweight(x, sr), sr, 0.4, 0.1)
    p = p[to_lufs(p) >= -70]
    rel = to_lufs(p.mean()) - 10
    return float(to_lufs(p[to_lufs(p) > rel].mean()))


def lra(x, sr):
    """EBU Tech 3342: 3 s windows, gates -70 LUFS and -20 LU, 95th minus 10th percentile."""
    _, p = window_power(kweight(x, sr), sr, 3.0, 0.1)
    st = to_lufs(p)
    st = st[st > -70]
    st = st[st > to_lufs(np.mean(10 ** ((st + 0.691) / 10))) - 20]
    return float(np.percentile(st, 95) - np.percentile(st, 10))


def onset_env(mono):
    _, _, z = signal.stft(mono, nperseg=NFFT, noverlap=NFFT - HOP, boundary=None, padded=False)
    s = np.log1p(100 * np.abs(z))
    flux = np.concatenate([[0], np.maximum(0, np.diff(s, axis=1)).sum(axis=0)])
    flux = flux - np.convolve(flux, np.ones(21) / 21, mode="same")
    return np.maximum(flux, 0), np.abs(z)


def tempo(env, sr, lo=55.0, hi=190.0, prior=100.0):
    """Autocorrelation of the onset envelope, log-normal prior around `prior` BPM, parabolic refinement."""
    fps = sr / HOP
    e = env - env.mean()
    f = np.fft.rfft(e, 2 * len(e))
    ac = np.fft.irfft(f * np.conj(f))[:len(e)]
    ac /= ac[0] + 1e-12
    lags = np.arange(int(fps * 60 / hi), int(fps * 60 / lo) + 1)
    score = ac[lags] * np.exp(-0.5 * np.log2(60 * fps / lags / prior) ** 2)
    k = lags[np.argmax(score)]
    d = 0.5 * (ac[k - 1] - ac[k + 1]) / (ac[k - 1] - 2 * ac[k] + ac[k + 1] + 1e-12)
    return float(60 * fps / (k + d))


def bands(mono, sr):
    f, p = signal.welch(mono, sr, nperseg=8192)
    tot = p.sum()

    def rel(a, b):
        return round(float(10 * np.log10(p[(f >= a) & (f < b)].sum() / tot + 1e-20)), 1)

    return {"sub_lt60": rel(0, 60), "bass_60_250": rel(60, 250), "lowmid_250_2k": rel(250, 2000),
            "presence_2k_6k": rel(2000, 6000), "air_gt6k": rel(6000, sr / 2),
            "centroid_hz": round(float((f * p).sum() / tot))}


def longest_silence(mono, sr, thr_db=-50.0, frame_s=0.05):
    n = int(frame_s * sr)
    k = len(mono) // n
    quiet = 20 * np.log10(np.sqrt((mono[:k * n].reshape(k, n) ** 2).mean(axis=1)) + 1e-12) < thr_db
    best = run = 0
    for q in quiet:
        run = run + 1 if q else 0
        best = max(best, run)
    return best * frame_s


def report(path, kind):
    sr, x = read(path)
    mono = x.mean(axis=1)
    std = dict(COMMON, **STANDARD[kind])
    lufs = integrated(x, sr)
    sos = signal.butter(4, [300, 8000], btype="bandpass", fs=sr, output="sos")
    env, _ = onset_env(mono)
    bpm = tempo(env, sr, prior=sum(std["bpm"]) / 2)
    fps, w = sr / HOP, int(20 * sr / HOP)
    local = [tempo(env[i:i + w], sr, bpm * 0.85, bpm * 1.15, bpm) for i in range(0, len(env) - w + 1, w // 2)]
    b = bands(mono, sr)
    m = {
        "loop_s": round(len(x) / sr, 3),
        "size_mb": round(os.path.getsize(path) / 1e6, 2),
        "lufs": round(lufs, 2),
        "true_peak_db": round(20 * math.log10(np.abs(signal.resample_poly(x, 4, 1, axis=0)).max()), 2),
        "lra": round(lra(x, sr), 2),
        "bpm": round(bpm, 2),
        "bpm_jitter": round(max(abs(v - bpm) for v in local), 2) if local else 0.0,
        "phone_loss": round(lufs - integrated(signal.sosfilt(sos, x, axis=0), sr), 2),
        "presence": b["presence_2k_6k"],
        "sub": b["sub_lt60"],
        "mono_loss": round(lufs - integrated(np.stack([mono, mono], axis=1), sr), 2),
        "lr_corr": round(float(np.corrcoef(x[:, 0], x[:, 1])[0, 1]), 3),
        "silence_s": round(longest_silence(mono, sr), 2),
    }
    checks = {
        "loop_s": std["loop_s"][0] <= m["loop_s"] <= std["loop_s"][1],
        "size_mb": m["size_mb"] <= std["size_mb_max"],
        "lufs": std["lufs"][0] <= m["lufs"] <= std["lufs"][1],
        "true_peak_db": m["true_peak_db"] <= std["true_peak_max"],
        "lra": m["lra"] <= std["lra_max"],
        "bpm": std["bpm"][0] <= m["bpm"] <= std["bpm"][1],
        "bpm_jitter": m["bpm_jitter"] <= std["bpm_jitter_max"],
        "phone_loss": m["phone_loss"] <= std["phone_loss_max"],
        "presence": m["presence"] <= std["presence_max"],
        "sub": m["sub"] <= std["sub_max"],
        "mono_loss": m["mono_loss"] <= std["mono_loss_max"],
        "lr_corr": m["lr_corr"] >= std["lr_corr_min"],
        "silence_s": m["silence_s"] < std["silence_max_s"],
    }
    for k, v in m.items():
        print(f"{'ok  ' if checks[k] else 'FAIL'} {k:13} {v}")
    print("bands", json.dumps(b))
    return all(checks.values())


def features(x, sr):
    mono = x.mean(axis=1)
    env, mag = onset_env(mono)
    freqs = np.fft.rfftfreq(NFFT, 1 / sr)
    sel = (freqs >= 55) & (freqs <= 4000)
    pc = np.round(12 * np.log2(freqs[sel] / 440.0) + 69).astype(int) % 12
    chroma = np.stack([(mag[sel][pc == p] ** 2).sum(axis=0) for p in range(12)])
    chroma /= np.linalg.norm(chroma, axis=0, keepdims=True) + 1e-12
    edges = np.geomspace(60, 12000, 17)
    timbre = np.stack([np.log10((mag[(freqs >= edges[i]) & (freqs < edges[i + 1])] ** 2).sum(axis=0) + 1e-10)
                       for i in range(16)])
    return env, chroma, timbre, freqs, mag


def grid(env, sr, bpm, mag, freqs):
    """Beat phase (frames) and which beat of four is the downbeat (strongest low-band onset)."""
    fps = sr / HOP
    period = fps * 60 / bpm
    phases = [env[np.round(ph + np.arange((len(env) - ph) // period) * period).astype(int)].sum()
              for ph in range(int(period))]
    phase = int(np.argmax(phases))
    low = np.log1p(100 * mag[freqs < 200]).sum(axis=0)
    low = np.maximum(0, np.diff(low, prepend=low[0]))
    pos = np.zeros(4)
    for j in range(int((len(env) - phase) / period)):
        i = int(round(phase + j * period))
        pos[j % 4] += low[max(0, i - 2):i + 3].max()
    return phase, period, int(np.argmax(pos))


def loops(path, bpm, lmin, lmax, top):
    """Pairs (start, end) on downbeats, a whole number of bars apart, where the music around start and around end
    (2 s before, 4 s after) matches best: chroma, band levels and onset pattern. The end may move a quarter beat
    to absorb tempo drift, then to the sample where the waveform after it matches the 250 ms after start best."""
    sr, x = read(path)
    env, chroma, timbre, freqs, mag = features(x, sr)
    phase, period, down = grid(env, sr, bpm, mag, freqs)
    fps, bar = sr / HOP, 4 * period
    before, after = int(2 * fps), int(4 * fps)
    q = int(period / 4)
    res = []
    for j in range(down, int((len(env) - phase) / period), 4):
        a = int(round(phase + j * period))
        if a - before < 0 or a / fps < 3:
            continue
        for k in range(int(np.ceil(lmin * fps / bar)), int(lmax * fps / bar) + 1):
            b0 = int(round(phase + j * period + k * bar))
            if b0 + q + after > len(env) or (b0 + q) / fps > len(env) / fps - 3:
                continue
            best = None
            for b in range(b0 - q, b0 + q + 1):
                c = float((chroma[:, a - before:a + after] * chroma[:, b - before:b + after]).sum(axis=0).mean())
                t = float(1 - np.abs(timbre[:, a - before:a + after] - timbre[:, b - before:b + after]).mean())
                r = float(np.corrcoef(env[a - before:a + after], env[b - before:b + after])[0, 1])
                score = 0.45 * c + 0.25 * t + 0.3 * r
                if best is None or score > best["score"]:
                    best = {"score": score, "start_f": a, "end_f": b, "bars": k,
                            "chroma": round(c, 3), "timbre": round(t, 3), "rhythm": round(r, 3)}
            best["score"] = round(best["score"], 4)
            res.append(best)
    res.sort(key=lambda v: -v["score"])
    mono = x.mean(axis=1)
    w, r = int(0.25 * sr), int(0.03 * sr)
    out = []
    for v in res[:top]:
        a, b = v.pop("start_f") * HOP, v.pop("end_f") * HOP
        ref = mono[a:a + w]
        corr = [(float(np.dot(ref, mono[b + d:b + d + w]) /
                       (np.linalg.norm(ref) * np.linalg.norm(mono[b + d:b + d + w]) + 1e-12)), d)
                for d in range(-r, r + 1) if b + d + w <= len(mono)]
        cbest, d = max(corr)
        out.append(dict(v, start=round(a / sr, 5), len=round((b + d - a) / sr, 5), wave_corr=round(cbest, 3)))
    print(json.dumps({"bpm": bpm, "beat_phase_s": round(phase / fps, 3), "downbeat": down,
                      "bar_s": round(bar / fps, 4), "top": out}, indent=1))


def seam(path, bpm, source, start):
    """Loudness (1 s windows), onset strength and beat phase (16 beats) on both sides of the wrap."""
    sr, x = read(path)
    y = np.concatenate([x[-20 * sr:], x[:20 * sr]])

    def around(z, t):
        tt, p = window_power(kweight(z, sr), sr, 1.0, 0.1)
        c, st = tt + 0.5, to_lufs(p)
        return round(float(st[(c > t - 2.5) & (c < t - 0.5)].mean()), 2), round(float(st[(c > t + 0.5) & (c < t + 3)].mean()), 2)

    env, _ = onset_env(y.mean(axis=1))
    fps = sr / HOP
    period = fps * 60 / bpm
    j = int(20 * fps)

    def phase_of(a, b):
        """Beat phase (frames, modulo the period) of env[a:b], every phase summing the same number of beats."""
        n = int((b - a) / period) - 1
        ph = np.argmax([env[np.round(a + p + np.arange(n) * period).astype(int)].sum() for p in range(int(period))])
        return int(round(a + ph) % period)

    out = {
        "sample_step": round(float(np.abs(x[0] - x[-1]).max()), 4),
        "p99_9_step": round(float(np.percentile(np.abs(np.diff(x, axis=0)).max(axis=1), 99.9)), 4),
        "loud_before_after": around(y, 20.0),
        "beat_phase_before_after": [phase_of(j - int(16 * period), j), phase_of(j, j + int(16 * period))],
    }
    if source:
        _, s = read(source)
        out["source_loud_before_after"] = around(s, start)
        # Onset at the wrap against the onset at start in the source, each relative to its file's mean: about 1 when
        # the wrap adds no hit of its own.
        senv, _ = onset_env(s.mean(axis=1))
        i = int(start * fps)
        loop_rel = env[j - 3:j + 4].max() / onset_env(x.mean(axis=1))[0].mean()
        out["onset_vs_source"] = round(float(loop_rel / (senv[i - 3:i + 4].max() / senv.mean())), 2)
    print(json.dumps(out))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["report", "loops", "seam"])
    ap.add_argument("file")
    ap.add_argument("--kind", choices=["home", "level"])
    ap.add_argument("--bpm", type=float)
    ap.add_argument("--min", type=float, default=60.0)
    ap.add_argument("--max", type=float, default=90.0)
    ap.add_argument("--top", type=int, default=6)
    ap.add_argument("--source")
    ap.add_argument("--start", type=float, default=0.0)
    a = ap.parse_args()
    if a.cmd == "report" and a.kind is None:
        ap.error("report needs --kind")
    if a.cmd != "report" and a.bpm is None:
        ap.error(a.cmd + " needs --bpm")
    if a.cmd == "report":
        sys.exit(0 if report(a.file, a.kind) else 1)
    if a.cmd == "loops":
        loops(a.file, a.bpm, a.min, a.max, a.top)
    else:
        seam(a.file, a.bpm, a.source, a.start)


if __name__ == "__main__":
    main()
