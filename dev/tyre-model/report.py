#!/usr/bin/env python3
"""Print the standard FDM and the tyre model side by side.

    python3 dev/tyre-model/report.py [fdm rate in Hz, default 120]

Numbers, not pass/fail: use it to see what a parameter change did.
"""
import sys

from sim import (SPLIT_ICE, corner, full_throttle, late_slip, launch, sine_with_dwell_series, slowly_increasing_steer,
                 stop)

NO_ABS = {"abs/par/enabled": 0.0}
NO_TC = {"tc/par/enabled": 0.0}
NO_ESC = {"esc/par/enabled": 0.0}


def stability_control(dt):
    a = round(sum(abs(slowly_increasing_steer(sign, dt=dt)) for sign in (1.0, -1.0)) / 2.0, 1)
    print("\nStability control: FMVSS 126 sine with dwell at 80 km/h, A = %.1f deg of steering wheel" % a)
    for name, params in (("without ESC", NO_ESC), ("with ESC", {})):
        runs = [(amp, r) for sign in (1.0, -1.0) for amp, r in sine_with_dwell_series(a, sign, params=params, dt=dt)]
        failing = [amp for amp, r in runs if not r["stable"] or (amp >= 5 * a and r["lateral_1_07"] < 1.83)]
        spun = sum(1 for _, r in runs if r["peak_yaw"] != r["peak_yaw"])
        measured = [r for _, r in runs if r["peak_yaw"] == r["peak_yaw"]]
        print("  %-12s %2d of %d runs fail (%d spun without a second yaw peak); yaw rate after 1.0 s up to"
              " %4.0f %% of its peak, after 1.75 s %4.0f %%; lateral move at least %.2f m; sideslip up to %.1f deg"
              % (name, len(failing), len(runs), spun, 100 * max(r["yaw_1_0"] for r in measured),
                 100 * max(r["yaw_1_75"] for r in measured),
                 min(r["lateral_1_07"] for amp, r in runs if amp >= 5 * a), max(r["max_beta"] for _, r in runs)))


def traction_control(dt):
    print("\nTraction control, full throttle (slip: drive slip over the tyre's peak slip, after 0.5 s)")
    cases = (("0-100 km/h, dry, 50:50", dict()),
             ("0-100 km/h, grip x0.3", dict(surface=0.3)),
             ("0-60 km/h, grip x0.3, 30:70", dict(surface=0.3, until_kmh=60,
                                                 params={"driveline/par/front_torque_share": 0.3})),
             ("0-60 km/h, right wheels on ice", dict(grip=SPLIT_ICE, until_kmh=60, hold_heading=True)))
    for label, kw in cases:
        params = kw.pop("params", {})
        line = "  %-32s" % label
        for name, extra in (("without TC", NO_TC), ("with TC", {})):
            rows = full_throttle(params=dict(params, **extra), dt=dt, **kw)
            line += "  %s %5.2f s%s, slip up to %6.2f, heading %6.1f deg" % (
                name, rows[-1]["t"], "" if abs(rows[-1]["u"]) * 3.6 >= kw.get("until_kmh", 100) - 0.5 else " (not reached)",
                late_slip(rows), max((abs(r["heading_deg"]) for r in rows), default=0.0))
        print(line)


def main():
    dt = 1.0 / float(sys.argv[1]) if len(sys.argv) > 1 else 1.0 / 120.0
    print("FDM rate %.0f Hz\n" % (1.0 / dt))

    print("0-100 km/h, full throttle")
    for surface in (1.0, 0.6, 0.3):
        a, _ = launch("stock", surface=surface, dt=dt)
        b, _ = launch("tyre", surface=surface, dt=dt)
        print("  grip x%.1f   standard %5.2f s (peak %.2f g)   tyre model %5.2f s (peak %.2f g, wheel slip up to %.2f)"
              % (surface, a["time"], a["peak_g"], b["time"], b["peak_g"], b["max_slip"]))

    traction_control(dt)
    stability_control(dt)

    print("\n100-0 km/h")
    for surface in (1.0, 0.3):
        a, _ = stop("stock", surface=surface, dt=dt)
        print("  grip x%.1f   standard, full pedal      %6.1f m  %.2f g" % (surface, a["dist"], a["decel_g"]))
        for pedal, params in ((1.0, NO_ABS), (1.0, {}), (0.8, {}), (0.6, {}), (0.4, {})):
            b, _ = stop("tyre", pedal=pedal, surface=surface, dt=dt, params=params)
            state = "%s, %s" % ("front locked" if b["front_locked"] else "front rolling",
                                "rear locked" if b["rear_locked"] else "rear rolling")
            print("  grip x%.1f   tyre model, pedal %.1f %s %6.1f m  %.2f g  (%s)"
                  % (surface, pedal, "no ABS" if params else "      ", b["dist"], b["decel_g"], state))
    threshold, _ = stop("tyre", pedal=0.83, rear_pedal=0.90, dt=dt, params=NO_ABS)
    print("  grip x1.0   tyre model, no ABS, front .83 rear .90   %.1f m  %.2f g"
          % (threshold["dist"], threshold["decel_g"]))

    print("\nBraking from 100 km/h with 6.75 deg of steering")
    a, _ = stop("stock", steer=0.15, dt=dt)
    print("  standard, full pedal        yaw %4.1f deg/s" % a["yaw_dps"])
    for pedal, params in ((1.0, NO_ABS), (1.0, {}), (0.6, {})):
        b, _ = stop("tyre", pedal=pedal, steer=0.15, dt=dt, params=params)
        print("  tyre model, pedal %.1f %s yaw %4.1f deg/s" % (pedal, "no ABS" if params else "      ", b["yaw_dps"]))

    print("\nSteady cornering, speed held (radius in m, slip angles in deg)")
    print("  km/h steer  geometric |  standard: g  radius front  rear |  tyre model: g  radius front  rear")
    for kmh in (30, 60, 90):
        for steer in (0.05, 0.1, 0.2, 0.4):
            a, _ = corner("stock", kmh, steer, dt=dt)
            b, _ = corner("tyre", kmh, steer, dt=dt)
            print("  %4d %5.2f  %9.1f |        %5.2f %7.1f %5.1f %5.1f |          %5.2f %7.1f %5.1f %5.1f"
                  % (kmh, steer, a["geometric_radius"], a["lat_g"], a["radius"], a["front_slip_deg"],
                     a["rear_slip_deg"], b["lat_g"], b["radius"], b["front_slip_deg"], b["rear_slip_deg"]))


if __name__ == "__main__":
    main()
