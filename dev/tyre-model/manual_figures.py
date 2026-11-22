#!/usr/bin/env python3
"""Draw the figures of Docs/ESC/tc-esc-engineering-manual.md.

    pip install -r dev/tyre-model/requirements.txt
    python3 dev/tyre-model/manual_figures.py

Writes SVG files to Docs/ESC/figures/. The plots run the generated FDM in
standalone JSBSim, so they show the model as it currently is; run this again
after changing it.
"""
import math

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle  # noqa: E402

import generate  # noqa: E402
from sim import KMH, SPLIT_ICE, Car, full_throttle, sine_with_dwell as sim_sine_with_dwell, slowly_increasing_steer  # noqa: E402

OUT = generate.REPO / "Docs" / "ESC" / "figures"
NO_TC = {"tc/par/enabled": 0.0}
NO_ESC = {"esc/par/enabled": 0.0}
PARAMS = {name: value for name, value, _ in generate.TC_PARAMS}
ESC_PAR = {name: value for name, value, _ in generate.ESC_PARAMS}
TYRE = {name: value for name, value, _ in generate.TYRE_PARAMS}

INK, BLUE, ORANGE, GREEN, RED, GREY, PURPLE = "#1f2933", "#2f6db3", "#d9822b", "#2e8b57", "#c0392b", "#7b8794", "#7d5ba6"
FILL = {"plant": "#eef2f7", "tc": "#e3f0e8", "abs": "#fdecd9", "driver": "#f4f4f4", "esc": "#efe6f7", "note": "#ffffff"}

plt.rcParams.update({
    "font.size": 9, "font.family": "DejaVu Sans", "svg.fonttype": "path", "axes.grid": True,
    "grid.alpha": 0.3, "axes.spines.top": False, "axes.spines.right": False, "legend.frameon": False,
})


def save(fig, name):
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / name, bbox_inches="tight")
    plt.close(fig)
    print("wrote", (OUT / name).relative_to(generate.REPO))


# --------------------------------------------------------------------------
# Block diagram helpers. Coordinates are in tenths of an inch.
# --------------------------------------------------------------------------
def canvas(width_in, height_in):
    fig, ax = plt.subplots(figsize=(width_in, height_in))
    ax.set_xlim(0, width_in * 10)
    ax.set_ylim(0, height_in * 10)
    ax.set_aspect("equal")
    ax.axis("off")
    return fig, ax


def box(ax, x, y, w, h, text, kind="plant", size=8.5, weight="normal", edge=INK):
    """A rounded box with its lower left corner at (x, y). Returns its centre."""
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3,rounding_size=0.8",
                                fc=FILL[kind], ec=edge, lw=0.9))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=size, color=INK, weight=weight,
            linespacing=1.25)
    return x + w / 2, y + h / 2


def arrow(ax, start, end, text=None, color=INK, dashed=False, rad=0.0, text_at=0.5, offset=(0, 1.2), size=7.5,
          lw=1.0):
    ax.add_patch(FancyArrowPatch(start, end, arrowstyle="-|>", mutation_scale=9, color=color, lw=lw,
                                 linestyle=(0, (4, 3)) if dashed else "-", connectionstyle="arc3,rad=%r" % rad,
                                 shrinkA=2, shrinkB=2))
    if text:
        x = start[0] + (end[0] - start[0]) * text_at + offset[0]
        y = start[1] + (end[1] - start[1]) * text_at + offset[1]
        ax.text(x, y, text, ha="center", va="bottom", fontsize=size, color=color)


# --------------------------------------------------------------------------
# Figure: channel order in one FDM frame
# --------------------------------------------------------------------------
def fig_architecture():
    fig, ax = canvas(8.6, 4.4)
    y, h, w = 21, 8, 11.5
    names = [("Occupants", "plant"), ("Traction &\nstability\ncontrol", "tc"), ("Driveline", "plant"),
             ("Brakes", "plant"), ("ABS", "abs"), ("Tyre\nfl fr bl br", "plant")]
    centres = []
    for i, (name, kind) in enumerate(names):
        centres.append(box(ax, 2 + i * 14.2, y, w, h, name, kind, size=8,
                           weight="bold" if kind == "tc" else "normal"))
    for a, b in zip(centres, centres[1:]):
        arrow(ax, (a[0] + w / 2 + 0.3, y + h / 2), (b[0] - w / 2 - 0.3, y + h / 2),
              color=GREEN if a is centres[1] else INK)
    ax.text(36.5, 17.5, "tc/motor_cap_nm,\nesc/torque_factor,\ntc/drag_factor", ha="center", fontsize=6.8, color=GREEN)
    ax.text(2, 14.5, "Channels run left to right,\nevery FDM frame (120 Hz).", fontsize=7.5, color=GREY)

    # driver inputs
    box(ax, 14, 36, 58, 5.5, "Driver and Nasal: accelerator, direction, brake pedals, handbrake, steering;"
        "\nautomatic braking (AEB, cruise, Auto Hold); TC/ESC mode (step 4)", "driver", size=7.5)
    for cx in (centres[1][0], centres[2][0], centres[3][0], centres[5][0]):
        arrow(ax, (cx, 35.4), (cx, y + h + 0.6), color=GREY)

    # brake requests from traction/stability control into ABS
    arrow(ax, (centres[1][0] + 2.5, y + h + 0.5), (centres[4][0], y + h + 0.5), None, ORANGE, rad=-0.25)
    ax.text(65.0, 30.8, "stab_brake_nm,\nesc/keep_<w>", ha="left", fontsize=7, color=ORANGE)

    # body and feedback
    box(ax, 50, 2, 34, 6.5, "JSBSim: tyre forces at the contact patches\nmove the body; struts carry the load", "plant",
        size=7.5)
    arrow(ax, (centres[5][0], y - 0.6), (centres[5][0], 9.1))
    arrow(ax, (49.6, 6.0), (centres[1][0], y - 0.6), None, GREEN, dashed=True)
    ax.text(25, 2.5, "previous frame (8.3 ms delay): wheel slip & speed, peak slip, load,\ndisc temperature, "
            "body velocities (u, v), yaw rate r, lateral accel Ny", ha="center", fontsize=6.8, color=GREEN)
    save(fig, "architecture.svg")


# --------------------------------------------------------------------------
# Figure: drivetrain and the traction controllers
# --------------------------------------------------------------------------
def fig_drivetrain():
    fig, ax = canvas(8.6, 6.4)
    cx = 46    # centre line of the car
    ax.add_patch(FancyBboxPatch((cx - 12, 6), 24, 52, boxstyle="round,pad=0.5,rounding_size=6", fc="#fafbfc",
                                ec=GREY, lw=1))
    ax.text(cx, 60.5, "front", ha="center", fontsize=8, color=GREY)
    wheels = {"fl": (cx - 15, 46), "fr": (cx + 11, 46), "bl": (cx - 15, 10), "br": (cx + 11, 10)}
    discs = {}
    for name, (x, y) in wheels.items():
        ax.add_patch(Rectangle((x, y), 4, 9, fc=INK, ec=INK))
        ax.text(x + 2, y - 2.2, name, ha="center", fontsize=8)
        bx = x + 6 if name.endswith("l") else x - 2
        discs[name] = (bx, y + 4.5)
    # axles and differentials
    for y in (50.5, 14.5):
        ax.plot([cx - 11, cx + 11], [y, y], color=INK, lw=1.6)
        ax.add_patch(plt.Circle((cx, y), 2.0, fc="white", ec=INK, lw=1, zorder=3))
        ax.text(cx, y, "D", ha="center", va="center", fontsize=7, zorder=4)
    for (bx, by) in discs.values():
        ax.add_patch(plt.Circle((bx, by), 1.1, fc=ORANGE, ec=INK, lw=0.6, zorder=3))
    ax.add_patch(plt.Circle((cx, 43), 2.0, fc="white", ec=INK, lw=1, zorder=3))
    ax.text(cx, 43, "C", ha="center", va="center", fontsize=7, zorder=4)
    ax.add_patch(Rectangle((cx - 4, 36), 8, 4, fc=FILL["tc"], ec=INK, lw=1, zorder=3))
    ax.text(cx, 38, "motor", ha="center", va="center", fontsize=7, zorder=4)
    ax.plot([cx, cx], [45, 48.5], color=INK, lw=1.6)
    ax.plot([cx, cx], [36, 16.5], color=INK, lw=1.6)
    ax.plot([cx, cx], [40, 41], color=INK, lw=1.6)
    ax.text(cx + 1.5, 26, "propshaft", rotation=90, va="center", fontsize=7, color=GREY)
    ax.text(cx, 0.5, "D: open axle differential (equal torque left and right)    C: open centre differential, "
            "fixed front_torque_share (0.5)\nbrake discs in orange; every wheel gets a fixed share of the motor torque",
            ha="center", fontsize=7, color=GREY)

    # controllers
    c1 = box(ax, 65, 34, 20, 9, "Propshaft speed\ncontroller (PID-like)\nweighted drive slip", "tc", size=7.5)
    arrow(ax, (65, c1[1]), (cx + 4.5, 38), "torque limit", GREEN, offset=(0, 0.8))
    c2 = box(ax, 65, 20, 20, 8, "Longitudinal lock (PI)\nfront axle vs rear axle", "tc", size=7.5)
    arrow(ax, (65, c2[1] + 1), (discs["fr"][0] + 1.2, discs["fr"][1] - 0.6), None, ORANGE, rad=-0.2)
    arrow(ax, (65, c2[1] - 1), (discs["br"][0] + 1.2, discs["br"][1] + 0.6), None, ORANGE, rad=0.2)
    ax.text(75, 15.5, "both brakes\nof one axle", ha="center", fontsize=7.5, color=ORANGE)
    c3 = box(ax, 1, 46, 20, 8, "Transversal lock, front\n(PI + hysteresis) fl vs fr", "tc", size=7.2)
    arrow(ax, (21, c3[1]), (discs["fl"][0] - 1.2, discs["fl"][1]), "one brake", ORANGE, text_at=0.4, offset=(0, 0.8))
    c4 = box(ax, 1, 10, 20, 8, "Transversal lock, rear\n(PI + hysteresis) bl vs br", "tc", size=7.2)
    arrow(ax, (21, c4[1]), (discs["bl"][0] - 1.2, discs["bl"][1]), "one brake", ORANGE, text_at=0.4, offset=(0, 0.8))
    box(ax, 1, 28, 20, 9, "all brake requests pass\nthe pump (0.15 s) and ABS,\nadded to the driver's", "abs", size=7)
    save(fig, "drivetrain.svg")


# --------------------------------------------------------------------------
# Figure: traction control signal flow
# --------------------------------------------------------------------------
def fig_signal_flow():
    fig, ax = canvas(8.6, 7.4)
    b0 = box(ax, 16, 66, 54, 5.5, "Tyre channels, previous frame: slip ratio, peak drive slip at the load,"
             "\nbraking slip, peak lateral friction, disc temperature", "plant", size=7.5)
    b1 = box(ax, 16, 55, 54, 5.5, "n_w = drive slip / peak drive slip, per wheel"
             "\n(positive while the wheel turns faster than the road in the drive direction)", "tc", size=7.5)
    arrow(ax, (b0[0], 65.4), (b1[0], 61.2))
    b2 = box(ax, 6, 40, 31, 9, "Transversal lock, per wheel (PI)\nhysteresis: engage > 0.5, hold at 1.0 -> 0.1\n"
             "capped by pump & requested wheel torque", "tc", size=7.0)
    b3 = box(ax, 44, 40, 40, 9, "Residual slip r_w = n_w minus the part\nthe lock is working on (soft saturation:\n"
             "at brake limit, hands <= wheel_limit + 0.5)", "tc", size=7.0)
    arrow(ax, (b1[0] - 10, 54.4), (b2[0], 49.6))
    arrow(ax, (b1[0] + 10, 54.4), (b3[0], 49.6))
    arrow(ax, (37.5, 44.5), (43.4, 44.5), None, GREY, dashed=True)
    b4 = box(ax, 6, 25, 31, 9, "Longitudinal lock, per axle (PI)\naxle mean of r_w, front vs rear\n"
             "(both wheels of the faster axle)", "tc", size=7.2)
    b5 = box(ax, 44, 25, 40, 9, "Propshaft slip + filtered derivative (d_time * dn/dt)\nerror = max(slip + d_time * rate - target,"
             "\nlargest wheel residual - wheel_limit), capped", "tc", size=7.0)
    arrow(ax, (b3[0] - 8, 39.4), (b4[0] + 6, 34.6))
    arrow(ax, (b3[0], 39.4), (b5[0], 34.6))
    b6 = box(ax, 44, 11, 40, 8, "Motor PID-like: integral state = torque limit\n(never above request; falls fast, rises slowly)"
             "\n-> Driveline: drive torque = min(request, limit) * esc_factor", "tc", size=7.0)
    arrow(ax, (b5[0], 24.4), (b6[0], 19.6))
    b7 = box(ax, 1, 11, 36, 8, "Pump: full-pedal torque in 0.15 s, released at once\n-> + driver's request * esc_keep -> ABS"
             " -> wheel brake", "abs", size=7.0)
    ax.plot([5.4, 2.5, 2.5], [44.5, 44.5, 20.0], color=ORANGE, lw=1.0)
    arrow(ax, (2.5, 20.4), (2.5, 19.6), None, ORANGE)
    arrow(ax, (b4[0], 24.4), (b4[0], 19.6), None, ORANGE)
    box(ax, 1, 1.5, 83, 5, "Locks only with the accelerator pressed and no brake pedal; engage below 40 km/h, cut out "
        "above 80 km/h;\nfade out between 450 and 550 °C disc temperature. EDTC cuts coast regen above 0.35 of peak "
        "braking slip.", "note", size=7)
    save(fig, "tc-signal-flow.svg")


# --------------------------------------------------------------------------
# Figure: the tyre curve and TC's thresholds; reference in a bend; disc fade
# --------------------------------------------------------------------------
def fig_tc_functions():
    load = 1  # the 4000 N column of the fitted curves
    peak = generate.LOAD_CURVES["drive_peak_slip"][load]
    shape = generate.LOAD_CURVES["drive_shape"][load]
    mu = generate.LOAD_CURVES["drive_peak_mu"][load]
    slide_start, slide_ratio = TYRE["slide_start"], TYRE["slide_ratio"]

    def force(n):
        slip = n * peak
        slide = max(0.0, min(1.0, (slip - slide_start * peak) / (1.0 - slide_start * peak)))
        curve = math.sin(shape * math.atan(math.tan(math.pi / (2 * shape)) * n))
        return (1 - slide) * mu * curve + slide * slide_ratio * mu

    fig, axes = plt.subplots(1, 3, figsize=(9.2, 2.8), gridspec_kw={"width_ratios": [1.5, 1, 1]})
    ns = [i / 100 for i in range(0, 501)]
    ax = axes[0]
    ax.plot(ns, [force(n) for n in ns], color=INK)
    for x, label, color, y, side in ((PARAMS["target_slip"], "target 0.85", GREEN, 0.30, "right"),
                                     (PARAMS["wheel_limit"], "wheel limit 1.4", BLUE, 0.45, "left"),
                                     (slide_start, "sliding starts 1.5", RED, 0.62, "left")):
        ax.axvline(x, color=color, lw=1, ls="--")
        ax.text(x + (0.08 if side == "left" else -0.08), y, label, color=color, fontsize=7.5, ha=side,
                bbox={"fc": "white", "ec": "none", "pad": 0.5})
    ax.set_xlabel("drive slip / peak drive slip")
    ax.set_ylabel("drive force / load")
    ax.set_title("Drive curve at 4000 N (dry)", fontsize=9)
    ax.set_ylim(0, 1.25)

    ax = axes[1]
    us = [i / 100 for i in range(0, 101)]
    ax.plot(us, [PARAMS["target_slip"] * max(PARAMS["corner_min"], math.sqrt(max(0.0, 1 - u * u))) for u in us],
            color=GREEN)
    ax.set_xlabel("lateral acceleration / (mu g)")
    ax.set_ylabel("reference slip / peak")
    ax.set_title("Reference in a bend", fontsize=9)
    ax.set_ylim(0, 1.0)

    ax = axes[2]
    ts = list(range(0, 701, 5))
    fade, off = PARAMS["temp_fade_c"], PARAMS["temp_off_c"]
    ax.plot(ts, [max(0.0, min(1.0, (off - t) / (off - fade))) for t in ts], color=ORANGE)
    ax.set_xlabel("brake disc temperature (°C)")
    ax.set_ylabel("lock factor")
    ax.set_title("Locks fade out when hot", fontsize=9)
    fig.tight_layout()
    save(fig, "tc-functions.svg")


# --------------------------------------------------------------------------
# Figure: baseline sine with dwell (why ESC) & ESC comparison
# --------------------------------------------------------------------------
STEER_A = 19.7 / 900.0   # A = 19.7 deg steering wheel giving 0.3 g at 80 km/h (FMVSS 126 S7.6)


def sine_with_dwell(amplitude, floor_it_at_beta=None, params=None):
    car = Car("tyre", speed=80 * KMH, settle=1.0, params=params)
    fdm = car.fdm
    freq = 0.7
    t_q3 = 0.75 / freq
    t_end = t_q3 + 0.5 + 0.25 / freq
    start, rows, on = fdm.get_sim_time(), [], False
    while fdm.get_sim_time() - start < t_end + 3.0:
        t = fdm.get_sim_time() - start
        if t < t_q3:
            steer = amplitude * math.sin(2 * math.pi * freq * t)
        elif t < t_q3 + 0.5:
            steer = -amplitude
        elif t < t_end:
            steer = amplitude * math.sin(2 * math.pi * freq * (t - 0.5))
        else:
            steer = 0.0
        beta = math.degrees(math.atan2(fdm["velocities/v-fps"], max(abs(fdm["velocities/u-fps"]), 0.3)))
        if floor_it_at_beta is not None and abs(beta) >= floor_it_at_beta:
            on = True
        car.step(throttle=1.0 if on else 0.0, steer=steer)
        rows.append((t, steer * 45.0, math.degrees(fdm["velocities/r-rad_sec"]), beta,
                     math.degrees(fdm["esc/ref"]), fdm["tyre/fl/stab_brake_nm"], fdm["tyre/fr/stab_brake_nm"]))
    return rows, t_end


def fig_sine_with_dwell():
    coast, t_end = sine_with_dwell(6.5 * STEER_A, params=NO_ESC)
    save_run, _ = sine_with_dwell(6.5 * STEER_A, floor_it_at_beta=10.0, params=NO_ESC)
    fig, axes = plt.subplots(3, 1, figsize=(7.5, 5.6), sharex=True)
    axes[0].plot([r[0] for r in coast], [r[1] for r in coast], color=INK)
    axes[0].set_ylabel("road wheel angle (deg)")
    axes[0].set_title("Sine with dwell, 6.5A (128 deg at the steering wheel), 80 km/h, no ESC", fontsize=9)
    for rows, label, color in ((coast, "coasting (no ESC)", RED),
                               (save_run, "flooring it at 10 deg sideslip (50:50, no ESC)", GREEN)):
        axes[1].plot([r[0] for r in rows], [r[2] for r in rows], color=color, label=label)
        axes[2].plot([r[0] for r in rows], [r[3] for r in rows], color=color, label=label)
    axes[1].set_ylabel("yaw rate (deg/s)")
    axes[2].set_ylabel("sideslip (deg)")
    axes[2].set_xlabel("time (s)")
    axes[2].legend(loc="upper left", fontsize=7.5)
    for ax in axes[1:]:
        for dt, label in ((0.0, "end of steering"), (1.0, "+1.0 s: 35 %"), (1.75, "+1.75 s: 20 %")):
            ax.axvline(t_end + dt, color=GREY, lw=0.8, ls=":")
    for dt, label in ((0.0, "steering ends"), (1.0, "+1.0 s"), (1.75, "+1.75 s")):
        axes[1].text(t_end + dt + 0.03, axes[1].get_ylim()[1] * 0.9, label, fontsize=7, color=GREY)
    fig.tight_layout()
    save(fig, "sine-with-dwell-baseline.svg")


def fig_esc_sine_with_dwell():
    off, t_end = sine_with_dwell(6.5 * STEER_A, params=NO_ESC)
    on, _ = sine_with_dwell(6.5 * STEER_A)
    fig, axes = plt.subplots(4, 1, figsize=(7.5, 7.2), sharex=True)
    axes[0].plot([r[0] for r in on], [r[1] for r in on], color=INK)
    axes[0].set_ylabel("road wheel (deg)")
    axes[0].set_title("FMVSS 126 sine with dwell at 6.5A (128 deg steering wheel), 80 km/h: ESC ON vs OFF", fontsize=9)

    axes[1].plot([r[0] for r in off], [r[2] for r in off], color=RED, ls="--", lw=1.0, label="without ESC")
    axes[1].plot([r[0] for r in on], [r[4] for r in on], color=GREY, ls=":", lw=1.0, label="reference yaw rate")
    axes[1].plot([r[0] for r in on], [r[2] for r in on], color=GREEN, lw=1.2, label="with ESC")
    axes[1].set_ylabel("yaw rate (deg/s)")
    axes[1].legend(loc="upper right", fontsize=7.2, ncol=3)

    axes[2].plot([r[0] for r in off], [r[3] for r in off], color=RED, ls="--", lw=1.0, label="without ESC")
    axes[2].plot([r[0] for r in on], [r[3] for r in on], color=GREEN, lw=1.2, label="with ESC")
    axes[2].set_ylabel("sideslip (deg)")
    axes[2].legend(loc="upper left", fontsize=7.5)

    axes[3].plot([r[0] for r in on], [r[5] for r in on], color=BLUE, lw=1.1, label="front left brake (N m)")
    axes[3].plot([r[0] for r in on], [r[6] for r in on], color=PURPLE, lw=1.1, label="front right brake (N m)")
    axes[3].set_ylabel("ESC brake (N m)")
    axes[3].set_xlabel("time (s)")
    axes[3].legend(loc="upper right", fontsize=7.5, ncol=2)

    for ax in axes[1:]:
        for dt in (0.0, 1.0, 1.75):
            ax.axvline(t_end + dt, color=GREY, lw=0.8, ls=":")
    for dt, label in ((0.0, "steering ends"), (1.0, "+1.0 s (<=35%)"), (1.75, "+1.75 s (<=20%)")):
        axes[1].text(t_end + dt + 0.03, axes[1].get_ylim()[1] * 0.85, label, fontsize=6.8, color=GREY)
    fig.tight_layout()
    save(fig, "esc-sine-with-dwell.svg")


# --------------------------------------------------------------------------
# Figures: launches with and without traction control
# --------------------------------------------------------------------------
def fig_low_grip_launch():
    off = full_throttle(params=NO_TC, surface=0.3)
    on = full_throttle(surface=0.3)
    limit = 100 * KMH / (0.3 * TYRE["mu0"] * 9.80665)
    fig, axes = plt.subplots(1, 2, figsize=(9.0, 3.0))
    ax = axes[0]
    ax.plot([r["t"] for r in off], [r["u"] / KMH for r in off], color=RED, label="without TC")
    ax.plot([r["t"] for r in on], [r["u"] / KMH for r in on], color=GREEN, label="with TC")
    ax.plot([0, limit], [0, 100], color=GREY, ls="--", label="friction limit (%.1f s)" % limit)
    ax.set_xlabel("time (s)")
    ax.set_ylabel("speed (km/h)")
    ax.set_title("0-100 km/h on grip x0.3", fontsize=9)
    ax.legend(fontsize=7.5)
    ax = axes[1]
    for wheel, color in (("fl", BLUE), ("fr", PURPLE), ("bl", ORANGE), ("br", GREEN)):
        ax.plot([r["t"] for r in on], [r["tc_slip_" + wheel] for r in on], color=color, lw=0.9, label=wheel)
    ax.axhline(PARAMS["target_slip"], color=GREEN, ls="--", lw=0.8)
    ax.axhline(1.5, color=RED, ls="--", lw=0.8)
    ax.text(on[-1]["t"], 1.53, "sliding starts", ha="right", fontsize=7, color=RED)
    ax.set_ylim(0, 3)
    ax.set_xlabel("time (s)")
    ax.set_ylabel("drive slip / peak, with TC")
    ax.set_title("Wheel slip with TC (without: 145-150)", fontsize=9)
    ax.legend(fontsize=7.5, ncol=4)
    fig.tight_layout()
    save(fig, "launch-low-grip.svg")


def fig_split_launch():
    off = full_throttle(params=NO_TC, grip=SPLIT_ICE, until_kmh=60, hold_heading=True)
    car = Car("tyre")
    on = full_throttle(car=car, grip=SPLIT_ICE, until_kmh=60, hold_heading=True)
    fig, axes = plt.subplots(3, 1, figsize=(7.5, 6.6), sharex=False)
    ax = axes[0]
    ax.plot([r["t"] for r in off], [r["u"] / KMH for r in off], color=RED, label="without TC")
    ax.plot([r["t"] for r in on], [r["u"] / KMH for r in on], color=GREEN, label="with TC")
    ax.set_ylabel("speed (km/h)")
    ax.set_xlabel("time (s)")
    ax.set_title("0-60 km/h, left wheels on asphalt, right wheels on ice, driver holding the heading", fontsize=9)
    ax.legend(fontsize=7.5)
    ax = axes[1]
    for rows, style, tag in ((off, ":", "without TC"), (on, "-", "with TC")):
        for wheel, color in (("fr", PURPLE), ("br", ORANGE)):
            ax.plot([r["t"] for r in rows], [max(r["tc_slip_" + wheel], 0.01) for r in rows], color=color, ls=style,
                    lw=1, label="%s %s" % (wheel, tag))
    ax.set_yscale("log")
    ax.axhline(1.5, color=RED, ls="--", lw=0.8)
    ax.set_xlim(0, on[-1]["t"])
    ax.set_ylabel("drive slip / peak (log)")
    ax.legend(fontsize=7, ncol=2)
    ax = axes[2]
    t = [r["t"] for r in on]
    ax.plot(t, [r["drive_nm"] for r in on], color=GREEN, label="motor torque driven (N m)")
    ax.plot(t, [r["stab_brake_nm_fr"] for r in on], color=PURPLE, label="brake request fr (N m)")
    ax.plot(t, [r["stab_brake_nm_br"] for r in on], color=ORANGE, label="brake request br (N m)")
    ax.set_xlim(0, on[-1]["t"])
    ax.set_xlabel("time (s)")
    ax.set_ylabel("torque (N m)")
    ax.legend(fontsize=7, ncol=3, loc="lower right")
    fig.tight_layout()
    save(fig, "launch-split-grip.svg")


# --------------------------------------------------------------------------
# Figure: the driver's modes (step 4)
# --------------------------------------------------------------------------
def fig_modes():
    fig, ax = canvas(8.4, 3.2)
    box(ax, 2, 11, 17, 8, "ON\nTC + locks + ESC", "tc", size=8, weight="bold")
    box(ax, 30, 11, 20, 8, "SPORT\nmore slip, ESC later,\nno torque cut", "esc", size=7.5, weight="bold")
    box(ax, 61, 11, 21, 8, "OFF\nlocks below\n40 km/h only", "abs", size=7.5, weight="bold")
    arrow(ax, (19.6, 16.5), (29.4, 16.5), "short press", INK, offset=(0, 0.6))
    arrow(ax, (29.4, 13.5), (19.6, 13.5), "short press", INK, offset=(0, -3.2))
    arrow(ax, (50.6, 16.5), (60.4, 16.5), "hold 3 s", INK, offset=(0, 0.6))
    arrow(ax, (71.5, 19.6), (10.5, 19.6), "press", INK, rad=0.3, text_at=0.5, offset=(0, 7.4))
    arrow(ax, (10.5, 6), (10.5, 10.4), None, GREEN)
    ax.text(10.5, 3.5, "every motor start", ha="center", fontsize=7.5, color=GREEN)
    ax.text(30, 3.5, "property /controls/esc/mode (0 ON, 1 SPORT, 2 OFF), outside the FDM", ha="left",
            fontsize=7, color=GREY)
    save(fig, "modes.svg")


FIGURES = {"architecture": fig_architecture, "drivetrain": fig_drivetrain, "signal-flow": fig_signal_flow,
           "functions": fig_tc_functions, "sine-with-dwell": fig_sine_with_dwell,
           "esc-sine-with-dwell": fig_esc_sine_with_dwell, "low-grip": fig_low_grip_launch,
           "split-grip": fig_split_launch, "modes": fig_modes}


def main(argv=None):
    """Draw every figure, or only those named on the command line."""
    import sys
    names = (argv if argv is not None else sys.argv[1:]) or list(FIGURES)
    for name in names:
        FIGURES[name]()


if __name__ == "__main__":
    main()
