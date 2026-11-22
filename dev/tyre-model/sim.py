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
        for unit, wheel in enumerate(WHEELS):
            row["jsb_slip_deg_" + wheel] = fdm["gear/unit[%d]/slip-angle-deg" % unit]
            if self.kind == "tyre":
                for key in ("slip_ratio", "slip_tan", "omega_rad_sec", "load_n", "mu", "mu_x", "mu_y", "fx_n", "fy_n"):
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
