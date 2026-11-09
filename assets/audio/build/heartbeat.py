"""Low-health heartbeat loop (numpy + wave, no AI model).

A 1.0 s mono 16-bit loop at 44100 Hz: a "lub-dub", two low thumps 0.14 s apart (sine
bodies sliding down in pitch, fast attack, ~80 ms exponential decay, a low-passed noise
click on each, the second at 70% level), peak -3 dBFS, then silence so it loops cleanly.
The client plays it looped and speeds it up as health drops (Config.Audio.LowHealth,
src/client/LowHealthFX.luau).

    uv run --with numpy python -I assets/audio/build/heartbeat.py [out.wav]

Writes assets/audio/heartbeat.wav by default (git-ignored); upload it under the group and
put the id in Config.Audio.LowHealth.HeartbeatId and assets/audio/ASSET_IDS.md.
"""

import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
LENGTH = 1.0  # seconds; the loop
GAP = 0.14  # seconds between lub and dub
START = 0.02  # seconds of lead silence before the lub
PEAK_DB = -3.0
SEED = 7


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole low-pass, run twice for a softer slope."""
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = signal
    for _ in range(2):
        filtered = np.empty_like(out)
        acc = 0.0
        for i, x in enumerate(out):
            acc += alpha * (x - acc)
            filtered[i] = acc
        out = filtered
    return out


def thump(freq_start: float, freq_end: float, rng: np.random.Generator) -> np.ndarray:
    """One heart sound: a pitch-dropping sine body plus a short dull click."""
    duration = 0.32
    t = np.arange(int(duration * RATE)) / RATE
    attack = 1.0 - np.exp(-t / 0.004)
    decay = np.exp(-t / 0.080)
    freq = freq_end + (freq_start - freq_end) * np.exp(-t / 0.05)
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    body = np.sin(phase) + 0.25 * np.sin(2.0 * phase)
    click_env = np.exp(-t / 0.012) * attack
    click = lowpass(rng.standard_normal(t.size), 500.0) * click_env
    click /= max(np.max(np.abs(click)), 1e-9)
    return body * attack * decay + 0.35 * click


def build() -> np.ndarray:
    rng = np.random.default_rng(SEED)
    out = np.zeros(int(LENGTH * RATE))
    for offset, level, f0, f1 in ((START, 1.0, 70.0, 55.0), (START + GAP, 0.7, 68.0, 58.0)):
        sound = thump(f0, f1, rng) * level
        at = int(offset * RATE)
        end = min(at + sound.size, out.size)
        out[at:end] += sound[: end - at]
    # Fade the last 20 ms to zero so the wrap is click-free.
    fade = int(0.02 * RATE)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)
    out *= 10 ** (PEAK_DB / 20.0) / np.max(np.abs(out))
    return out


def write(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(samples * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def main() -> None:
    default = Path(__file__).resolve().parent.parent / "heartbeat.wav"
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    samples = build()
    write(path, samples)
    peak = 20.0 * np.log10(np.max(np.abs(samples)))
    print(f"wrote {path} ({samples.size / RATE:.2f} s, peak {peak:.1f} dBFS)")


if __name__ == "__main__":
    main()
