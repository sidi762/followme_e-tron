#!/usr/bin/env python3
"""Print the standard FDM and the tyre model side by side.

    python3 dev/tyre-model/report.py [fdm rate in Hz, default 120]

Numbers, not pass/fail: use it to see what a parameter change did.
"""
import sys

from sim import corner, launch, stop


def main():
    dt = 1.0 / float(sys.argv[1]) if len(sys.argv) > 1 else 1.0 / 120.0
    print("FDM rate %.0f Hz\n" % (1.0 / dt))

    print("0-100 km/h, full throttle")
    for surface in (1.0, 0.6, 0.3):
        a, _ = launch("stock", surface=surface, dt=dt)
        b, _ = launch("tyre", surface=surface, dt=dt)
        print("  grip x%.1f   standard %5.2f s (peak %.2f g)   tyre model %5.2f s (peak %.2f g, wheel slip up to %.2f)"
              % (surface, a["time"], a["peak_g"], b["time"], b["peak_g"], b["max_slip"]))

    print("\n100-0 km/h")
    for surface in (1.0, 0.3):
        a, _ = stop("stock", surface=surface, dt=dt)
        print("  grip x%.1f   standard, full pedal      %6.1f m  %.2f g" % (surface, a["dist"], a["decel_g"]))
        for pedal in (1.0, 0.8, 0.6, 0.4):
            b, _ = stop("tyre", pedal=pedal, surface=surface, dt=dt)
            state = "%s, %s" % ("front locked" if b["front_locked"] else "front rolling",
                                "rear locked" if b["rear_locked"] else "rear rolling")
            print("  grip x%.1f   tyre model, pedal %.1f     %6.1f m  %.2f g  (%s)"
                  % (surface, pedal, b["dist"], b["decel_g"], state))
    threshold, _ = stop("tyre", pedal=0.83, rear_pedal=0.90, dt=dt)
    print("  grip x1.0   tyre model, front .83 rear .90   %.1f m  %.2f g"
          % (threshold["dist"], threshold["decel_g"]))

    print("\nBraking from 100 km/h with 6.75 deg of steering")
    a, _ = stop("stock", steer=0.15, dt=dt)
    print("  standard, full pedal        yaw %4.1f deg/s" % a["yaw_dps"])
    for pedal in (1.0, 0.6):
        b, _ = stop("tyre", pedal=pedal, steer=0.15, dt=dt)
        print("  tyre model, pedal %.1f       yaw %4.1f deg/s" % (pedal, b["yaw_dps"]))

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
