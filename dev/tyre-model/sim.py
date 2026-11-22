"""Drive the Follow Me EV flight models headless in JSBSim, without FlightGear.

Used by test_tyre_model.py and report.py. Needs the `jsbsim` Python package.
"""
import atexit
import math
import shutil
import tempfile
from pathlib import Path

import jsbsim

from generate import OUT_FDM, OUT_SYSTEM, REPO, STOCK_FDM, generate, read_text

FT = 0.3048           # metres per foot
LBF = 4.4482216       # newtons per pound-force
G = 9.80665
KMH = 1.0 / 3.6       # m/s per km/h
WHEELS = ("fl", "fr", "bl", "br")
WHEELBASE = 2.49

# Properties the FDM reads that only exist once FlightGear has created them.
FG_SIDE_PROPS = {
    "/controls/interior/luxury/storage_cover_pos": 0.0,
    "/controls/interior/armrest_cover_pos": 0.0,
    "/controls/wiper/frontwiper/state": 0.0,
    "/controls/steering_wheel/steering_limit-deg": 900.0,
    "/controls/flight/rudder": 0.0,
    # occupant defaults from followme_e-tron-tyre-set.xml and Nasal/node_setup.nas
    "/systems/occupants/driver-kg": 60.0,
    "/systems/occupants/codriver-kg": 60.0,
    "/systems/codriver-enable": 0.0,
    # braking intents the tyre model reads (Nasal/systems/brakes.nas)
    "/controls/gear/brake-left": 0.0,
    "/controls/gear/brake-right": 0.0,
    "/controls/gear/brake-parking": 0.0,
    "/systems/BrakeController/automatic-norm": 0.0,
    "/systems/BrakeController/hold-norm": 0.0,
    "/systems/BrakeController/handbrake-norm": 0.0,
}

_test_dir = None


def tyre_aircraft_dir():
    """A scratch aircraft folder holding the tyre FDM plus two test-only forces.

    The extra forces push at the CG and stand in for a slope, which standalone
    JSBSim's flat ground cannot provide. The system file is the generated one,
    byte for byte what generate.py writes into Systems/.
    """
    global _test_dir
    if _test_dir is None:
        _test_dir = Path(tempfile.mkdtemp(prefix="followme-tyre-"))
        atexit.register(shutil.rmtree, _test_dir, ignore_errors=True)
        fdm_xml, system_xml = generate(read_text(STOCK_FDM)[0], test_forces=True)
        (_test_dir / OUT_FDM.name).write_text(fdm_xml, encoding="utf-8")
        (_test_dir / "Systems").mkdir()
        (_test_dir / "Systems" / OUT_SYSTEM.name).write_text(system_xml, encoding="utf-8")
    return _test_dir


def load(aircraft_dir, model, dt=1.0 / 120.0):
    """Load <aircraft_dir>/<model>.xml the way FlightGear does."""
    fdm = jsbsim.FGFDMExec(None)
    fdm.set_debug_level(0)
    fdm.set_aircraft_path(str(aircraft_dir))
    fdm.set_dt(dt)
    for name, value in FG_SIDE_PROPS.items():
        fdm.set_property_value(name, value)
    if not fdm.load_model(model, False):
        raise RuntimeError("JSBSim could not load %s" % model)
    return fdm


class StockDrive:
    """Python stand-in for Nasal/engine.nas driving the standard FDM.

    It repeats update_engine(): the torque for this update is the commanded
    power at the *previous* update's rpm divided by the new rpm, so the car
    pulls less while the rpm is rising quickly. In FlightGear the update runs
    off a 0.1 s Nasal timer, which fires at most once per rendered frame, so
    below 10 fps the real period is the frame time; `period` reproduces that.
    """

    max_torque = 460.0        # N m
    rated_power = 375.0       # kW
    gear = 9.73
    wheel_radius = 0.31

    def __init__(self, fdm, period=0.1):
        self.fdm = fdm
        self.period = period
        self.next_update = 0.0
        self.rpm = 100.0
        self.force_n = 0.0

    def step(self, throttle, steer):
        fdm = self.fdm
        if fdm.get_sim_time() >= self.next_update:
            self.next_update = fdm.get_sim_time() + self.period
            cmd_torque = throttle * self.max_torque
            cmd_power = min(abs(self.rpm * cmd_torque / 9549.0), self.rated_power)
            wheel_speed = abs(fdm["gear/unit[0]/wheel-speed-fps"]) * FT
            self.rpm = max(wheel_speed / self.wheel_radius * self.gear * 9.5492966, 100.0)
            self.force_n = 9549.0 * cmd_power / self.rpm * self.gear / self.wheel_radius
            angle = steer * math.radians(45.0)   # steering.nas turns the front forces
            for wheel in ("FL", "FR"):
                fdm["external_reactions/%s/x" % wheel] = math.cos(angle)
                fdm["external_reactions/%s/y" % wheel] = math.sin(angle)
        for unit, wheel in enumerate(("FL", "FR", "BL", "BR")):
            on_ground = fdm["gear/unit[%d]/compression-ft" % unit] > 0
            fdm["external_reactions/%s/magnitude" % wheel] = self.force_n / LBF / 4.0 if on_ground else 0.0


class Car:
    """One car on flat ground, either FDM, with the same controls."""

    def __init__(self, kind, speed=0.0, surface=1.0, dt=1.0 / 120.0, params=None, settle=3.0,
                 nasal_period=0.1):
        assert kind in ("stock", "tyre"), kind
        self.kind = kind
        if kind == "stock":
            self.fdm = load(REPO, STOCK_FDM.stem, dt)
        else:
            self.fdm = load(tyre_aircraft_dir(), OUT_FDM.stem, dt)
        fdm = self.fdm
        for name, value in (params or {}).items():
            fdm[name] = value
        fdm["ic/lat-geod-deg"] = 0.0
        fdm["ic/long-gc-deg"] = 0.0
        fdm["ic/terrain-elevation-ft"] = 0.0
        fdm["ic/h-agl-ft"] = 0.45 / FT
        fdm["ic/psi-true-deg"] = 0.0
        fdm["ic/u-fps"] = speed / FT
        if not fdm.run_ic():
            raise RuntimeError("JSBSim could not initialise")
        fdm["ground/static-friction-factor"] = surface
        self.stock_drive = StockDrive(fdm, nasal_period) if kind == "stock" else None
        self.dt = fdm.get_delta_t()
        # let the suspension settle, holding the speed
        self.run(settle, cruise=speed if speed > 0 else None)

    def push(self, forward=0.0, right=0.0):
        """Body force as a fraction of weight: what a slope of that grade does."""
        weight = self.fdm["inertia/weight-lbs"]
        self.fdm["external_reactions/test_push_x/magnitude"] = forward * weight
        self.fdm["external_reactions/test_push_y/magnitude"] = right * weight

    def step(self, throttle=0.0, steer=0.0, brake_front=0.0, brake_rear=0.0):
        fdm = self.fdm
        fdm["fcs/steer-cmd-norm"] = steer
        # The standard FDM brakes through JSBSim's brake groups, which FlightGear
        # fills from the pedals; the tyre model reads the pedals themselves.
        fdm["fcs/left-brake-cmd-norm"] = brake_front    # LEFT group is the front axle
        fdm["fcs/right-brake-cmd-norm"] = brake_rear
        fdm["/controls/gear/brake-left"] = brake_front
        fdm["/controls/gear/brake-right"] = brake_rear
        if self.kind == "stock":
            self.stock_drive.step(throttle, steer)
        else:
            fdm["driveline/in/throttle_norm"] = throttle
        fdm.run()

    def sample(self):
        fdm = self.fdm
        row = {
            "t": fdm.get_sim_time(),
            "u": fdm["velocities/u-fps"] * FT,
            "v": fdm["velocities/v-fps"] * FT,
            "yaw_rate": fdm["velocities/r-rad_sec"],
            "ax_g": fdm["accelerations/udot-ft_sec2"] * FT / G,
            "nx": fdm["accelerations/Nx"],
            "ny": fdm["accelerations/Ny"],
            "pitch_deg": fdm["attitude/theta-deg"],
            "dist": fdm["position/distance-from-start-mag-mt"],
        }
        if self.kind == "tyre":
            row["tc_active"] = fdm["tc/active"]
            row["esc_active"] = fdm["esc/active"]
            row["drive_nm"] = fdm["driveline/drive_torque_nm"]
        for unit, wheel in enumerate(WHEELS):
            row["jsb_slip_deg_" + wheel] = fdm["gear/unit[%d]/slip-angle-deg" % unit]
            if self.kind == "tyre":
                for key in ("slip_ratio", "slip_tan", "omega_rad_sec", "load_n", "mu", "mu_x", "mu_y", "fx_n", "fy_n",
                            "tc_slip", "stab_brake_nm"):
                    row["%s_%s" % (key, wheel)] = fdm["tyre/%s/%s" % (wheel, key)]
        return row

    def run(self, seconds, throttle=0.0, steer=0.0, brake=0.0, cruise=None, until=None, rear_brake=None):
        """Advance; returns one sample per frame. `cruise` holds a speed in m/s."""
        rows = []
        for _ in range(int(round(seconds / self.dt))):
            pedal = throttle
            if cruise is not None:
                pedal = max(0.0, min(1.0, 0.4 * (cruise - self.fdm["velocities/u-fps"] * FT) + 0.02))
            self.step(pedal, steer, brake, brake if rear_brake is None else rear_brake)
            rows.append(self.sample())
            if until is not None and until(rows[-1]):
                break
        return rows


def mean(rows, key, fn=lambda x: x):
    return sum(fn(row[key]) for row in rows) / len(rows)


def moved(rows):
    return abs(rows[-1]["dist"] - rows[0]["dist"])


def launch(kind, surface=1.0, **kw):
    """Full throttle from rest to 100 km/h."""
    car = Car(kind, surface=surface, **kw)
    rows = car.run(60.0, throttle=1.0, until=lambda r: r["u"] >= 100 * KMH)
    out = {"time": rows[-1]["t"] - rows[0]["t"], "peak_g": max(r["ax_g"] for r in rows),
           "reached": rows[-1]["u"] >= 100 * KMH}
    if kind == "tyre":
        out["max_slip"] = max(r["slip_ratio_" + w] for r in rows for w in WHEELS)
    return out, rows


SPLIT_ICE = (1.0, 0.1, 1.0, 0.1)    # left wheels on asphalt, right wheels on ice


def full_throttle(params=None, surface=1.0, grip=None, until_kmh=100.0, seconds=25.0, direction=1.0,
                  hold_heading=False, dt=1.0 / 120.0, car=None):
    """Tyre model, full throttle until a speed, optionally with its own grip under each wheel.

    With hold_heading a driver keeps the heading after 0.3 s, turning the road
    wheels at most 18 deg/s and 6.75 deg. Rows carry "t" from the start and
    "heading_deg".
    """
    if car is None:
        car = Car("tyre", surface=surface, dt=dt, params=dict(params or {}, **{"driveline/in/direction": direction}))
    fdm = car.fdm
    start, heading, steer, rows = fdm.get_sim_time(), 0.0, 0.0, []
    while fdm.get_sim_time() - start < seconds and abs(fdm["velocities/u-fps"]) * FT < until_kmh * KMH:
        if grip:
            for unit, g in enumerate(grip):   # standalone JSBSim has one surface; seed each wheel's
                fdm[f"gear/unit[{unit}]/static-friction-factor"] = g
        if hold_heading and fdm.get_sim_time() - start > 0.3:
            want = max(-0.15, min(0.15, -(1.5 * heading + 0.25 * fdm["velocities/r-rad_sec"])))
            steer += max(-0.4 * car.dt, min(0.4 * car.dt, want - steer))
        car.step(throttle=1.0, steer=steer)
        row = car.sample()
        heading += row["yaw_rate"] * car.dt
        row["t"] -= start
        row["heading_deg"] = math.degrees(heading)
        rows.append(row)
    return rows


def late_slip(rows, wheels=WHEELS):
    """Largest drive slip over the tyre's peak drive slip after the first half second."""
    return max(r["tc_slip_" + w] for r in rows if r["t"] > 0.5 for w in wheels)


# FlightGear turns the steering wheel 900 deg for full rudder (Nasal/steering.nas)
# and the front wheels 45 deg (max_steer).
STEER_WHEEL_DEG = 900.0


def cruise_pedal(fdm, speed):
    """The pedal Car.run uses to hold a speed in m/s."""
    return max(0.0, min(1.0, 0.4 * (speed - fdm["velocities/u-fps"] * FT) + 0.02))


def characteristic_speed(kmh=80.0, lateral=(1.0, 2.0, 3.0, 4.0), params=None):
    """Steady turns at a held speed in the linear range (up to 4 m/s^2).

    Fits the road wheel angle less the kinematic L/R against the lateral
    acceleration; the slope is the understeer gradient K, and the
    characteristic speed is sqrt(L / K). Returns (K in deg/g, v_char in m/s).
    """
    from generate import STOCK_FDM, read_text, read_vehicle, wheelbase
    length = wheelbase(read_vehicle(read_text(STOCK_FDM)[0])[2])
    u = kmh * KMH
    points = []
    for ay in lateral:
        steer = (length / u ** 2) * ay / math.radians(45.0)     # what a neutral car would need
        rows = Car("tyre", speed=u, params=params).run(8.0, steer=steer, cruise=u)[-180:]
        yaw, speed = mean(rows, "yaw_rate"), mean(rows, "u")
        points.append((yaw * speed, math.radians(steer * 45.0) - length * yaw / speed))
    n = len(points)
    sx, sy = sum(a for a, _ in points), sum(d for _, d in points)
    sxx, sxy = sum(a * a for a, _ in points), sum(a * d for a, d in points)
    gradient = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return math.degrees(gradient) * G, math.sqrt(length / gradient) if gradient > 0 else float("inf")


def slowly_increasing_steer(sign=1.0, kmh=80.0, rate_dps=13.5, until_g=0.5, params=None, dt=1.0 / 120.0):
    """FMVSS 126 S7.6: steering wheel turned at 13.5 deg/s at a held 80 km/h up to about 0.5 g.

    Returns A, the steering wheel angle in deg giving 0.3 g, from a linear fit of
    steering wheel angle against lateral acceleration between 0.1 and 0.375 g.
    """
    car = Car("tyre", speed=kmh * KMH, params=params, dt=dt)
    fdm, wheel, points = car.fdm, 0.0, []
    while abs(fdm["accelerations/Ny"]) < until_g and wheel < STEER_WHEEL_DEG:
        wheel += rate_dps * car.dt
        car.step(throttle=cruise_pedal(fdm, kmh * KMH), steer=sign * wheel / STEER_WHEEL_DEG)
        points.append((abs(fdm["accelerations/Ny"]), wheel))
    fit = [(g, w) for g, w in points if 0.1 <= g <= 0.375]
    n = len(fit)
    sx, sy = sum(g for g, _ in fit), sum(w for _, w in fit)
    sxx, sxy = sum(g * g for g, _ in fit), sum(g * w for g, w in fit)
    slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return (sy - slope * sx) / n + slope * 0.3


def sine_with_dwell(amplitude_deg, sign=1.0, kmh=80.0, params=None, dt=1.0 / 120.0, throttle_at_beta=None):
    """FMVSS 126 S7.9: 0.7 Hz sine of the steering wheel with a 500 ms dwell at its
    second peak, coasting from 80 km/h. sign 1 turns right first.

    Returns a dict with the rows and the S5.2 measures: yaw rate 1.0 s and 1.75 s
    after the steering ends over the first yaw rate peak after the steering
    reverses, and the lateral displacement 1.07 s after the steering begins (at
    5 deg of steering wheel angle). With throttle_at_beta the driver floors the
    accelerator once the sideslip reaches that many degrees.
    """
    car = Car("tyre", speed=kmh * KMH, params=params, dt=dt, settle=1.0)
    fdm = car.fdm
    freq = 0.7
    t_reverse = 0.5 / freq
    t_dwell = 0.75 / freq
    t_end = t_dwell + 0.5 + 0.25 / freq
    start, heading, lateral, floor_it, rows = fdm.get_sim_time(), 0.0, 0.0, False, []
    while fdm.get_sim_time() - start < t_end + 2.5:
        t = fdm.get_sim_time() - start
        if t < t_dwell:
            wheel = amplitude_deg * math.sin(2 * math.pi * freq * t)
        elif t < t_dwell + 0.5:
            wheel = -amplitude_deg
        elif t < t_end:
            wheel = amplitude_deg * math.sin(2 * math.pi * freq * (t - 0.5))
        else:
            wheel = 0.0
        u, v = fdm["velocities/u-fps"] * FT, fdm["velocities/v-fps"] * FT
        beta = math.degrees(math.atan2(v, max(abs(u), 0.3)))
        floor_it = floor_it or (throttle_at_beta is not None and abs(beta) >= throttle_at_beta)
        car.step(throttle=1.0 if floor_it else 0.0, steer=sign * wheel / STEER_WHEEL_DEG)
        row = car.sample()
        heading += row["yaw_rate"] * car.dt
        lateral += (row["u"] * math.sin(heading) + row["v"] * math.cos(heading)) * car.dt
        row.update(t=t, wheel_deg=sign * wheel, beta_deg=beta, lateral_m=lateral)
        rows.append(row)

    def at(time):
        return min(rows, key=lambda r: abs(r["t"] - time))

    t_begin = next(r["t"] for r in rows if abs(r["wheel_deg"]) >= 5.0)
    second = [r for r in rows if t_reverse <= r["t"] <= t_end and r["yaw_rate"] * sign < 0]
    # A car that keeps turning the first way has no second peak: it has spun.
    peak = max(second, key=lambda r: abs(r["yaw_rate"]))["yaw_rate"] if second else float("nan")
    yaw_1_0 = at(t_end + 1.0)["yaw_rate"] / peak
    yaw_1_75 = at(t_end + 1.75)["yaw_rate"] / peak
    lateral = abs(at(t_begin + 1.07)["lateral_m"] - at(t_begin)["lateral_m"])
    return {"rows": rows, "t_begin": t_begin, "t_end": t_end, "peak_yaw": peak,
            "yaw_1_0": yaw_1_0, "yaw_1_75": yaw_1_75, "lateral_1_07": lateral,
            # S5.2.1 and S5.2.2; a missing peak (NaN) fails them
            "stable": bool(yaw_1_0 <= 0.35 and yaw_1_75 <= 0.20),
            "max_beta": max(abs(r["beta_deg"]) for r in rows)}


def sine_with_dwell_series(a_deg, sign=1.0, params=None, dt=1.0 / 120.0):
    """FMVSS 126 S7.9.2-S7.9.4: 1.5A upwards in steps of 0.5A to the larger of 6.5A
    and 270 deg (300 deg if 6.5A would pass it). Returns [(amplitude, result)]."""
    last = 300.0 if 6.5 * a_deg > 300.0 else max(6.5 * a_deg, 270.0)
    amplitudes, k = [], 3
    while k * 0.5 * a_deg < last:
        amplitudes.append(k * 0.5 * a_deg)
        k += 1
    amplitudes.append(last)
    return [(amplitude, sine_with_dwell(amplitude, sign, params=params, dt=dt)) for amplitude in amplitudes]


def stop(kind, pedal=1.0, surface=1.0, steer=0.0, speed=100 * KMH, rear_pedal=None, **kw):
    """Brake to rest from `speed`."""
    car = Car(kind, speed=speed, surface=surface, **kw)
    rows = car.run(60.0, brake=pedal, rear_brake=rear_pedal, steer=steer, until=lambda r: abs(r["u"]) < 0.2)
    start = rows[0]["u"]
    core = [r for r in rows if 0.25 * start < r["u"] < 0.9 * start] or rows
    out = {"dist": moved(rows), "decel_g": -mean(core, "ax_g"), "lat_g": mean(core, "ny", abs),
           "yaw_dps": math.degrees(mean(core, "yaw_rate", abs))}
    if kind == "tyre":
        out["front_locked"] = min(r["slip_ratio_" + w] for r in core for w in ("fl", "fr")) < -0.9
        out["rear_locked"] = min(r["slip_ratio_" + w] for r in core for w in ("bl", "br")) < -0.9
    return out, rows


def corner(kind, speed_kmh, steer, hold=10.0, **kw):
    """Step steer at a held speed; steady-state values from the last 1.5 s."""
    car = Car(kind, speed=speed_kmh * KMH, **kw)
    rows = car.run(hold, steer=steer, cruise=speed_kmh * KMH)
    tail = rows[-int(1.5 / car.dt):]
    u, yaw = mean(tail, "u"), mean(tail, "yaw_rate")
    lat = mean(tail, "ny")
    out = {"lat_g": abs(lat), "radius": abs(u / yaw) if abs(yaw) > 1e-6 else float("inf"),
           "geometric_radius": WHEELBASE / math.tan(math.radians(abs(steer) * 45.0)),
           "noise_g": (sum((r["ny"] - lat) ** 2 for r in tail) / len(tail)) ** 0.5}
    for axle, pair in (("front", ("fl", "fr")), ("rear", ("bl", "br"))):
        if kind == "tyre":
            out[axle + "_slip_deg"] = abs(math.degrees(math.atan(
                sum(mean(tail, "slip_tan_" + w) for w in pair) / 2.0)))
        else:
            out[axle + "_slip_deg"] = abs(sum(mean(tail, "jsb_slip_deg_" + w) for w in pair) / 2.0)
    return out, rows
