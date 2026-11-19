"""Headless checks of the tyre and driveline model.

    pip install -r dev/tyre-model/requirements.txt
    python3 -m pytest dev/tyre-model

Each test drives the generated FDM in standalone JSBSim (flat ground, no
FlightGear) and checks behaviour, not exact numbers: the bounds are wide enough
that retuning a tyre parameter should not break them, and tight enough that a
broken equation will.
"""
import math

import pytest

import generate
from sim import KMH, WHEELS, Car, corner, launch, mean, moved, stop

REAR_DRIVE = {"driveline/par/front_torque_share": 0.0}
FRONT_DRIVE = {"driveline/par/front_torque_share": 1.0}


def test_generated_files_are_current():
    assert generate.stale_outputs() == [], "run dev/tyre-model/generate.py"


def test_standard_fdm_still_loads():
    car = Car("stock", settle=5.0)
    assert abs(car.fdm["velocities/u-fps"]) < 0.01
    assert car.fdm["inertia/mass-slugs"] * 14.5939 == pytest.approx(1575, rel=0.01)


def test_parked_car_sits_still_with_the_right_wheel_loads():
    car = Car("tyre", settle=5.0)
    fdm = car.fdm
    assert abs(fdm["velocities/u-fps"]) < 0.003 and abs(fdm["velocities/v-fps"]) < 0.003
    loads = [fdm["tyre/%s/load_n" % w] for w in WHEELS]
    assert sum(loads) == pytest.approx(fdm["inertia/weight-lbs"] * 4.4482216, rel=0.02)
    assert (loads[0] + loads[1]) / sum(loads) == pytest.approx(0.67, abs=0.02)   # nose heavy


def test_launch_on_a_dry_road_hooks_up():
    result, _ = launch("tyre")
    assert 3.0 < result["time"] < 3.8
    assert result["max_slip"] < 0.2


def test_launch_on_a_slippery_road_spins_the_wheels_and_is_slow():
    dry, _ = launch("tyre")
    slippery, _ = launch("tyre", surface=0.3)
    assert slippery["reached"]
    assert slippery["time"] > 2.5 * dry["time"]
    assert slippery["peak_g"] < 0.4
    assert slippery["max_slip"] > 1.0
    # the standard FDM does not notice the surface at all
    assert launch("stock", surface=0.3)[0]["time"] == pytest.approx(launch("stock")[0]["time"], rel=0.01)


def test_smoke_follows_the_sliding_axle():
    car = Car("tyre", params=REAR_DRIVE)
    car.run(1, throttle=1, brake=1, rear_brake=0)
    for wheel in ("fl", "fr"):
        assert car.fdm[f"tyre/{wheel}/smoke_norm"] == 0
    for wheel in ("bl", "br"):
        assert car.fdm[f"tyre/{wheel}/smoke_norm"] > 0.5

    car = Car("tyre", speed=20, settle=0.6)
    car.run(0.25)
    assert all(car.fdm[f"tyre/{wheel}/smoke_norm"] == 0 for wheel in WHEELS)
    car.run(0.6, brake=1, rear_brake=0)
    for wheel in ("fl", "fr"):
        assert car.fdm[f"tyre/{wheel}/omega_rad_sec"] == pytest.approx(0, abs=1e-5)
        assert car.fdm[f"tyre/{wheel}/smoke_norm"] > 0.5
    for wheel in ("bl", "br"):
        assert car.fdm[f"tyre/{wheel}/smoke_norm"] == 0


def test_side_slip_smokes_but_an_airborne_spinning_wheel_does_not():
    car = Car("tyre", speed=27, settle=0.4)
    car.run(0.4, steer=0.8)
    assert car.fdm["tyre/fl/smoke_norm"] > 0.5
    assert car.fdm["tyre/fl/fy_n"] * car.fdm["tyre/fl/vy_wheel_mps"] < -30000

    car.fdm["ic/h-agl-ft"] = 100
    assert car.fdm.run_ic()
    car.run(0.3, throttle=1)
    for wheel in WHEELS:
        assert abs(car.fdm[f"tyre/{wheel}/omega_rad_sec"]) > 10
        assert car.fdm[f"tyre/{wheel}/load_n"] == 0
        assert car.fdm[f"tyre/{wheel}/smoke_norm"] == 0


def test_motor_off_means_no_drive_and_a_park_lock():
    car = Car("tyre", params={"driveline/in/motor_on": 0.0})
    assert moved(car.run(3.0, throttle=1.0)) < 0.01
    car.push(forward=0.2)                       # no brakes, 20 % slope
    assert moved(car.run(30.0)) < 0.01


def test_switching_the_motor_off_at_speed_does_not_lock_the_wheels():
    car = Car("tyre", speed=20.0)
    car.fdm["driveline/in/motor_on"] = 0.0
    rows = car.run(2.0)
    assert rows[-1]["u"] > 18.0
    assert min(r["slip_ratio_" + w] for r in rows for w in WHEELS) > -0.05


def test_reverse():
    car = Car("tyre", params={"driveline/in/direction": -1.0})
    rows = car.run(3.0, throttle=0.3)
    assert -9.0 < rows[-1]["u"] < -5.0


def test_coasting_slows_the_car_like_the_standard_fdm():
    def coast_decel(kind):
        car = Car(kind, speed=60 * KMH)
        rows = car.run(3.0)
        return -mean(rows[60:], "ax_g")

    assert coast_decel("tyre") == pytest.approx(coast_decel("stock"), abs=0.01)


def test_threshold_braking_beats_locked_wheels():
    locked, _ = stop("tyre", pedal=1.0)
    # The lighter rear axle reaches the measured slip peak at a lower pedal.
    threshold, _ = stop("tyre", pedal=0.92, rear_pedal=0.82)
    assert locked["front_locked"] and locked["rear_locked"]
    assert not threshold["front_locked"] and not threshold["rear_locked"]
    assert 35.0 < threshold["dist"] < 40.0
    assert locked["dist"] > threshold["dist"] + 1.0


def test_locked_front_wheels_cannot_steer():
    locked, _ = stop("tyre", pedal=1.0, steer=0.15)
    rolling, _ = stop("tyre", pedal=0.6, steer=0.15)
    assert locked["yaw_dps"] < 2.0
    assert rolling["yaw_dps"] > 8.0


def test_forces_stay_inside_each_tyres_friction_ellipse():
    _, rows = stop("tyre", pedal=0.9, steer=0.3)
    _, more = launch("tyre", surface=0.5, params=REAR_DRIVE)
    for row in rows + more:
        for w in WHEELS:
            normal = row["load_n_" + w]
            assert math.hypot(row["fx_n_" + w] / row["mu_x_" + w],
                              row["fy_n_" + w] / row["mu_y_" + w]) <= normal * 1.0001 + 1.0


def test_each_wheel_uses_its_own_surface_for_grip_and_rolling_resistance():
    car = Car("tyre")
    fdm = car.fdm
    # Seed the held samples as FlightGear's contact callback does on mixed ground.
    # Standalone JSBSim refreshes them from uniform ground after the system runs.
    materials = [(0.525, 5.0), (0.75, 1.0), (0.7, 5.0), (1.0, 1.0)]
    for unit, (grip, rolling) in enumerate(materials):
        fdm[f"gear/unit[{unit}]/static-friction-factor"] = grip
        fdm[f"gear/unit[{unit}]/rolling_friction-factor"] = rolling
    car.step()
    for w, (grip, rolling) in zip(WHEELS, materials):
        prefix = f"tyre/{w}/"
        assert fdm[prefix + "mu_y"] == pytest.approx(grip * fdm[prefix + "side_peak_mu"])
        assert fdm[prefix + "jsb_static_mu"] == pytest.approx(fdm[prefix + "stick"] * fdm[prefix + "side_peak_mu"])
        expected_drag = fdm["tyre/par/rolling_resistance"] * rolling * fdm[prefix + "load_n"] * fdm["tyre/par/radius_m"]
        assert fdm[prefix + "brake_torque_nm"] == pytest.approx(expected_drag)


def test_cornering_has_a_grip_limit_and_understeers_towards_it():
    gentle, _ = corner("tyre", 30, 0.05)
    assert gentle["radius"] == pytest.approx(gentle["geometric_radius"], rel=0.05)
    brisk, _ = corner("tyre", 90, 0.05)
    assert brisk["radius"] > 1.15 * brisk["geometric_radius"]
    assert brisk["front_slip_deg"] > brisk["rear_slip_deg"]
    limit, _ = corner("tyre", 60, 0.2)
    assert 0.85 < limit["lat_g"] < 1.02
    assert limit["noise_g"] < 0.01
    too_much_lock, _ = corner("tyre", 90, 0.4)
    assert too_much_lock["lat_g"] < limit["lat_g"]      # over-slipped front tyres lose grip


def test_drive_layout_decides_what_full_throttle_does_in_a_corner():
    def body_slip(params):
        car = Car("tyre", speed=40 * KMH, params=params)
        car.run(4.0, steer=0.2, cruise=40 * KMH)
        rows = car.run(3.0, steer=0.2, throttle=1.0)
        return max(abs(math.degrees(math.atan2(r["v"], max(r["u"], 0.1)))) for r in rows)

    assert body_slip(REAR_DRIVE) > 45.0     # power oversteer: it spins
    assert body_slip(FRONT_DRIVE) < 10.0    # it pushes wide instead


@pytest.mark.parametrize("forward,right", [(0.10, 0.0), (0.0, 0.10), (0.30, 0.0), (0.0, 0.30), (-0.2, 0.2)])
def test_parked_on_the_brakes_holds_on_a_slope(forward, right):
    car = Car("tyre")
    car.push(forward, right)
    assert moved(car.run(30.0, brake=1.0)) < 0.01


def test_released_on_a_slope_it_rolls_downhill_but_not_sideways():
    car = Car("tyre", params={"driveline/par/coast_regen_nm": 0.0})
    car.push(forward=0.10)
    freewheeling = car.run(5.0)[-1]["u"]
    assert 3.8 < freewheeling < 4.4                # (0.10 - rolling resistance) g for 5 s
    car = Car("tyre")
    car.push(forward=0.10)
    assert 2.0 < car.run(5.0)[-1]["u"] < freewheeling - 0.5    # coast regen holds it back
    car = Car("tyre")
    car.push(right=0.10)
    assert moved(car.run(30.0)) < 0.01


def test_hill_start_does_not_roll_back():
    car = Car("tyre")
    car.push(forward=-0.15)
    assert moved(car.run(5.0, brake=1.0)) < 0.01
    rows = car.run(3.0, throttle=0.5)
    assert min(r["u"] for r in rows) > -0.05
    assert rows[-1]["u"] > 5.0


def test_braking_to_rest_ends_at_rest():
    car = Car("tyre", speed=10.0)
    rows = car.run(6.0, brake=0.5)
    assert max(abs(r["u"]) for r in rows[-120:]) < 0.002


@pytest.mark.parametrize("params", [{}, REAR_DRIVE, FRONT_DRIVE])
def test_pulling_away_at_full_steering_lock(params):
    car = Car("tyre", params=params)
    car.run(2.0, brake=1.0, steer=0.9)
    rows = car.run(12.0, throttle=0.06, steer=0.9)
    assert rows[-1]["u"] > 0.3
    assert 2.8 < abs(rows[-1]["u"] / rows[-1]["yaw_rate"]) < 3.7     # geometric radius is 2.9 m


@pytest.mark.parametrize("hz", [60, 240])
def test_results_do_not_depend_on_the_fdm_rate(hz):
    dt = 1.0 / hz
    for wheel_inertia in (2.1, 0.9):
        params = {"tyre/par/wheel_inertia_kgm2": wheel_inertia}
        for run, key in ((lambda **kw: launch("tyre", surface=0.6, **kw), "time"),
                         (lambda **kw: stop("tyre", pedal=1.0, **kw), "dist"),
                         (lambda **kw: corner("tyre", 60, 0.2, **kw), "lat_g")):
            reference = run(params=params)[0][key]
            assert run(dt=dt, params=params)[0][key] == pytest.approx(reference, rel=0.08)
