"""Reproduce the dry tyre calibration from KIT's 'Determination of tire properties - Data.zip'.

Run with the archive path as the only argument. Requires NumPy and SciPy.
"""
import argparse
from collections import defaultdict
from io import StringIO
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from scipy.optimize import minimize_scalar

from generate import LOAD_CURVES, TEST_LOADS_N, TYRE_PARAMS


def fit_archive(archive):
    samples = defaultdict(list)
    peaks = defaultdict(list)
    radii = []
    for path in archive.namelist():
        if "/TDX W/" not in path or "_0G_" not in path:
            continue
        name = Path(path).name
        if name.startswith("KIT_SIDE_") and name.endswith(".TDX"):
            mode = "side"
        elif name.startswith("KIT_LONG_") and name.endswith((".TDB", ".TDA")):
            mode = "brake" if name.endswith(".TDB") else "drive"
        else:
            continue
        header, body = archive.read(path).decode("latin1").split("**MEASURDATA")
        values = np.loadtxt(StringIO(body.split("**END")[0]))
        load = int(values[0, 2])
        if mode == "side":
            force = values[:, 0]
            angle = values[:, 6] * 0.01  # hundredths of a degree
            # Centre each sweep on its own interpolated zero-force angle.
            i, = np.flatnonzero(np.diff(np.signbit(force)))
            zero = angle[i] - force[i] * (angle[i + 1] - angle[i]) / (force[i + 1] - force[i])
            slip = -np.tan(np.deg2rad(angle - zero))
            keep = slip != 0
        else:
            force = values[:, 1]
            slip = values[:, 5] * 0.0001  # hundredths of a percent to ratio
            keep = slip < 0 if mode == "brake" else slip > 0
            if load == 4000:
                radius_line = next(line for line in header.splitlines() if line.startswith("KROLRAD"))
                radii.append(float(radius_line.split()[-1]))
        slip_abs = np.abs(slip[keep])
        mu = np.sign(slip[keep]) * force[keep] / values[keep, 2]
        peak = np.argmax(mu)
        peaks[mode, load].append((mu[peak], slip_abs[peak]))
        samples[mode, load].append(np.column_stack((slip_abs, mu)))

    for mode in ("drive", "brake", "side"):
        for j, load in enumerate(TEST_LOADS_N):
            assert len(peaks[mode, load]) == 2
            peak_mu, peak_slip = np.mean(peaks[mode, load], axis=0)
            slip, mu = np.concatenate(samples[mode, load]).T

            def mean_square_error(c):
                b = np.tan(np.pi / (2 * c))
                prediction = peak_mu * np.sin(c * np.arctan(b * slip / peak_slip))
                return np.mean((prediction - mu)**2)

            fit = minimize_scalar(mean_square_error, bounds=(1.01, 1.99), method="bounded",
                                  options={"xatol": 1e-10})
            print(f"{mode:5s} {load:4d} N   mu={peak_mu:.6f}   slip={peak_slip:.6f}"
                  f"   C={fit.x:.6f}   RMS(F/Fz)={np.sqrt(fit.fun):.4f}")
            stored = [LOAD_CURVES[f"{mode}_{key}"][j] for key in ("peak_mu", "peak_slip", "shape")]
            np.testing.assert_allclose(stored, [peak_mu, peak_slip, fit.x], atol=0.00001, rtol=0)
    assert len(radii) == 4
    print(f"4000 N rolling radius: {np.mean(radii):.5f} m")
    radius = next(value for name, value, _ in TYRE_PARAMS if name == "radius_m")
    np.testing.assert_allclose(radius, np.mean(radii), rtol=0, atol=1e-8)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip_path", type=Path)
    with ZipFile(parser.parse_args().zip_path) as source:
        fit_archive(source)
