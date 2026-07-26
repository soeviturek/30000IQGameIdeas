"""程序化生成 8 个占位音效（22050Hz 16-bit mono WAV），纯标准库，无需 numpy。
后续可用正式素材同名替换 res://sfx/*.wav。跑完此脚本即可删除。"""
import wave, struct, math, random, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "sfx")
os.makedirs(OUT, exist_ok=True)


def _write(name, samples):
    # 防爆音：整体软限幅 + 首尾 3ms 淡入淡出
    n = len(samples)
    fade = int(SR * 0.003)
    for i in range(n):
        s = samples[i]
        if i < fade:
            s *= i / fade
        if i > n - fade:
            s *= (n - i) / fade
        samples[i] = max(-1.0, min(1.0, s))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
    print("wrote", path, n, "samples")


def dur(t):
    return int(SR * t)


def sine(freq, t, i):
    return math.sin(2 * math.pi * freq * (i / SR))


def env(i, n, decay=4.0):
    return math.exp(-decay * i / n)


def gen_attack():
    n = dur(0.14); out = []
    for i in range(n):
        f = 900 - 500 * i / n
        s = 0.5 * math.sin(2 * math.pi * f * i / SR) + 0.4 * (random.random() * 2 - 1)
        out.append(s * env(i, n, 6.0))
    return out


def gen_hurt():
    n = dur(0.18); out = []
    for i in range(n):
        f = 320 - 160 * i / n
        sq = 1.0 if math.sin(2 * math.pi * f * i / SR) > 0 else -1.0
        out.append(0.55 * sq * env(i, n, 5.0))
    return out


def gen_levelup():
    notes = [523, 659, 784, 1047]; out = []
    seg = dur(0.11)
    for k, f in enumerate(notes):
        for i in range(seg):
            out.append(0.5 * math.sin(2 * math.pi * f * i / SR) * env(i, seg, 3.0))
    return out


def gen_kill():
    n = dur(0.1); out = []
    for i in range(n):
        f = 1200 + 400 * i / n
        out.append(0.45 * math.sin(2 * math.pi * f * i / SR) * env(i, n, 8.0))
    return out


def gen_victory():
    notes = [523, 659, 784, 1047, 1319]; out = []
    seg = dur(0.14)
    for f in notes:
        for i in range(seg):
            s = 0.4 * math.sin(2 * math.pi * f * i / SR)
            s += 0.15 * math.sin(2 * math.pi * f * 2 * i / SR)
            out.append(s * env(i, seg, 2.2))
    return out


def gen_defeat():
    n = dur(0.7); out = []
    for i in range(n):
        f = 400 * math.pow(0.5, 2.0 * i / n)
        s = 0.5 * math.sin(2 * math.pi * f * i / SR)
        s += 0.2 * math.sin(2 * math.pi * f * 1.5 * i / SR)
        out.append(s * env(i, n, 2.0))
    return out


def gen_dash():
    n = dur(0.16); out = []
    for i in range(n):
        f = 400 + 900 * i / n
        s = 0.3 * math.sin(2 * math.pi * f * i / SR) + 0.4 * (random.random() * 2 - 1)
        out.append(s * env(i, n, 7.0))
    return out


def gen_boss():
    n = dur(0.9); out = []
    for i in range(n):
        f = 70 + 8 * math.sin(2 * math.pi * 5 * i / SR)
        s = 0.6 * math.sin(2 * math.pi * f * i / SR)
        s += 0.25 * math.sin(2 * math.pi * f * 2 * i / SR)
        s += 0.1 * (random.random() * 2 - 1)
        e = min(1.0, i / (SR * 0.15)) * env(i, n, 1.2)
        out.append(s * e)
    return out


for name, fn in [
    ("attack", gen_attack), ("hurt", gen_hurt), ("levelup", gen_levelup),
    ("kill", gen_kill), ("victory", gen_victory), ("defeat", gen_defeat),
    ("dash", gen_dash), ("boss", gen_boss),
]:
    _write(name, fn())
print("DONE")
