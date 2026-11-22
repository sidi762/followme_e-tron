#!/usr/bin/env python3
"""Synthesise Sounds/abs.wav, the cabin sound of the ABS hydraulic unit at work.

    python3 dev/sounds/make_abs_sound.py

No recording was at hand, so this builds one from what an ABS unit makes
heard in the cabin: the return pump's motor hum, the grinding pulse of its
pistons, the valves clicking as they release and rebuild, and the thump of
each pressure cycle through the pedal. Every component repeats a whole number
of times per second, so the one-second file loops without a seam. Replace the
file with a recording to do better; FlightGear only needs a mono WAV.

Standard library only.
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "Sounds" / "abs.wav"
RATE = 22050
SECONDS = 1                 # loop length; frequencies below are whole cycles per loop
MOTOR_HZ = 110              # pump motor
PISTON_HZ = 22              # pump strokes, which make the hum grind
VALVE_CLICKS_PER_S = 12     # inlet and outlet valves switching
PEDAL_THUMPS_PER_S = 6      # one pressure cycle felt through the pedal


def burst(t, start, length, freq, decay, period):
    """A decaying sine burst at `start` seconds, repeating every `period`, wrapped around the loop."""
    dt = (t - start) % period
    if dt > length:
        return 0.0
    return math.exp(-dt / decay) * math.sin(2 * math.pi * freq * dt)


def main():
    rng = random.Random(1)
    harmonics = [(k, 1.0 / k, rng.uniform(0, 2 * math.pi)) for k in range(1, 9)]
    # grinding: many whole-hertz partials with random phases sound like noise but still loop
    grind = [(f, rng.uniform(0, 2 * math.pi)) for f in range(300, 1800, 7)]
    samples = []
    for n in range(RATE * SECONDS):
        t = n / RATE
        stroke = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * PISTON_HZ * t))
        motor = sum(a * math.sin(2 * math.pi * MOTOR_HZ * k * t + p) for k, a, p in harmonics)
        noise = sum(math.sin(2 * math.pi * f * t + p) for f, p in grind) / math.sqrt(len(grind))
        clicks = sum(burst(t, i / VALVE_CLICKS_PER_S, 0.012, 2600 if i % 2 else 1900, 0.0025, 1.0)
                     * (1.0 if i % 2 else 0.7) for i in range(VALVE_CLICKS_PER_S))
        thump = sum(burst(t, i / PEDAL_THUMPS_PER_S + 0.02, 0.06, 45, 0.02, 1.0)
                    for i in range(PEDAL_THUMPS_PER_S))
        samples.append(stroke * (0.35 * motor + 0.25 * noise) + 0.8 * clicks + 1.2 * thump)
    peak = max(abs(s) for s in samples)
    frames = b"".join(struct.pack("<h", int(round(32767 * 0.7 * s / peak))) for s in samples)
    with wave.open(str(OUT), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)
    print("wrote", OUT.relative_to(OUT.parents[1]))


if __name__ == "__main__":
    main()
