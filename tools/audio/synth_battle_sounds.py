"""Synthesizes the fight's sounds (战斗拍数 C, DECISIONS「战斗拍数 C」) into game/assets/audio/battle/.

The project's first audio: short, project-made sounds built from sines and filtered noise
with the standard library alone, so they are reproducible and carry no outside licence
(docs/production/LICENSE_PROVENANCE.md). The game loads the .wav files through
BattleSounds (game/presentation/battle/battle_sounds.gd); rerun this after changing a
recipe. 44.1 kHz, 16-bit, mono, a fixed seed.

    py -3 -X utf8 tools/audio/synth_battle_sounds.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "battle"


def _env(t: float, attack: float, decay: float) -> float:
    """A fast rise over `attack`, then an exponential fall with the time constant `decay`."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def _noise(rng: random.Random) -> float:
    return rng.uniform(-1.0, 1.0)


class LowPass:
    """One-pole low pass, the cutoff in Hz."""

    def __init__(self, cutoff: float) -> None:
        self.set(cutoff)
        self.y = 0.0

    def set(self, cutoff: float) -> None:
        x = math.exp(-2.0 * math.pi * cutoff / RATE)
        self.a = 1.0 - x
        self.b = x

    def step(self, x: float) -> float:
        self.y = self.a * x + self.b * self.y
        return self.y


class BandPass:
    """A low pass minus a lower low pass: noise with a band left."""

    def __init__(self, low: float, high: float) -> None:
        self.lo = LowPass(low)
        self.hi = LowPass(high)

    def step(self, x: float) -> float:
        return self.hi.step(x) - self.lo.step(x)


def render(seconds: float, sample) -> list[float]:
    count = int(RATE * seconds)
    out = []
    for i in range(count):
        out.append(sample(i / RATE))
    return out


def clapper(rng: random.Random) -> list[float]:
    """拍板: a woody clap — a sharp noise click and a damped 1.6 kHz knock."""
    band = BandPass(900.0, 5000.0)

    def sample(t: float) -> float:
        click = band.step(_noise(rng)) * _env(t, 0.001, 0.012) * 1.6
        knock = math.sin(2 * math.pi * 1600.0 * t) * _env(t, 0.001, 0.03) * 0.5
        body = math.sin(2 * math.pi * 420.0 * t) * _env(t, 0.002, 0.045) * 0.35
        return click + knock + body

    return render(0.09, sample)


def whoosh(rng: random.Random) -> list[float]:
    """挥空: filtered noise swelling and sweeping down (played faster for 快, slower for 重)."""
    band = BandPass(300.0, 1800.0)

    def sample(t: float) -> float:
        sweep = 2600.0 - 2000.0 * min(1.0, t / 0.16)
        band.hi.set(sweep)
        band.lo.set(max(120.0, sweep * 0.18))
        shape = math.sin(math.pi * min(1.0, t / 0.2)) ** 1.4
        return band.step(_noise(rng)) * shape * 1.8

    return render(0.2, sample)


def thud(rng: random.Random) -> list[float]:
    """命中闷响: a low thump, its pitch dropping, under a dull burst of noise."""
    low = LowPass(600.0)

    def sample(t: float) -> float:
        pitch = 70.0 + 90.0 * math.exp(-t / 0.02)
        body = math.sin(2 * math.pi * pitch * t) * _env(t, 0.002, 0.07)
        burst = low.step(_noise(rng)) * _env(t, 0.001, 0.025) * 1.2
        return body * 0.9 + burst

    return render(0.16, sample)


def crack(rng: random.Random) -> list[float]:
    """脆响, the layer a 克 hit adds: a short bright snap."""
    band = BandPass(2500.0, 9000.0)

    def sample(t: float) -> float:
        snap = band.step(_noise(rng)) * _env(t, 0.0005, 0.008) * 1.8
        ring = math.sin(2 * math.pi * 3400.0 * t) * _env(t, 0.0005, 0.012) * 0.4
        return snap + ring

    return render(0.05, sample)


def clang(rng: random.Random) -> list[float]:
    """格挡铿锵: three inharmonic metallic partials ringing out."""
    partials = [(1870.0, 1.0, 0.09), (2760.0, 0.6, 0.07), (4120.0, 0.35, 0.05), (610.0, 0.3, 0.12)]
    band = BandPass(1500.0, 7000.0)

    def sample(t: float) -> float:
        tone = sum(math.sin(2 * math.pi * f * t) * a * _env(t, 0.001, d) for f, a, d in partials) * 0.5
        strike = band.step(_noise(rng)) * _env(t, 0.0005, 0.006) * 1.2
        return tone + strike

    return render(0.28, sample)


def drum(rng: random.Random) -> list[float]:
    """低鼓, the layer under a 重 that lands: a deep drum with a dropping pitch."""
    low = LowPass(220.0)

    def sample(t: float) -> float:
        pitch = 48.0 + 70.0 * math.exp(-t / 0.05)
        body = math.sin(2 * math.pi * pitch * t) * _env(t, 0.003, 0.16)
        skin = low.step(_noise(rng)) * _env(t, 0.001, 0.03) * 0.8
        return body * 0.95 + skin

    return render(0.34, sample)


def seal(rng: random.Random) -> list[float]:
    """印章闷扣: a dull stamp — a muffled thump with a little paper noise."""
    low = LowPass(900.0)

    def sample(t: float) -> float:
        body = math.sin(2 * math.pi * (95.0 + 60.0 * math.exp(-t / 0.015)) * t) * _env(t, 0.002, 0.05)
        paper = low.step(_noise(rng)) * _env(t, 0.001, 0.02) * 0.7
        return body * 0.85 + paper

    return render(0.15, sample)


RECIPES = {
    "clapper": clapper,
    "whoosh": whoosh,
    "thud": thud,
    "crack": crack,
    "clang": clang,
    "drum": drum,
    "seal": seal,
}


def write(path: Path, samples: list[float], peak: float = 0.85) -> None:
    top = max(abs(s) for s in samples) or 1.0
    gain = peak / top
    # A short fade at the end, so no file ends on a click.
    tail = min(len(samples), int(RATE * 0.008))
    data = bytearray()
    for i, s in enumerate(samples):
        if i >= len(samples) - tail:
            s *= (len(samples) - i) / tail
        value = max(-1.0, min(1.0, s * gain))
        data += struct.pack("<h", int(value * 32767))
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(data))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, recipe in RECIPES.items():
        samples = recipe(random.Random(name))
        write(OUT / f"{name}.wav", samples)
        print(f"{name}.wav  {len(samples) / RATE:.3f} s")


if __name__ == "__main__":
    main()
