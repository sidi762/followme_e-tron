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
import mass
from sim import KMH, WHEELS, Car, corner, launch, mean, moved, stop

REAR_DRIVE = {"driveline/par/front_torque_share": 0.0}
FRONT_DRIVE = {"driveline/par/front_torque_share": 1.0}
# For the tests of what the tyres themselves do when a wheel locks.
NO_ABS = {"abs/par/enabled": 0.0}


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
    # mass.py puts the CG near the middle of the wheelbase: battery between the axles
    _, cg, _ = mass.with_occupants()
    front_x, rear_x = 0.675, 3.155
    expected = (rear_x - cg[0]) / (rear_x - front_x)
    assert 0.45 < expected < 0.55
    assert (loads[0] + loads[1]) / sum(loads) == pytest.approx(expected, abs=0.02)


def test_occupants_add_their_weight_where_they_sit():
    car = Car("tyre", settle=1.0)
    fdm = car.fdm

    def weight_kg():
        return fdm["inertia/weight-lbs"] / 2.2046226

    def cg_m():
        return [fdm["inertia/cg-%s-in" % axis] * 0.0254 for axis in "xyz"]

    alone = weight_kg()
    assert alone == pytest.approx(mass.KERB_KG + 60.0, abs=0.1)
    assert cg_m()[1] < -0.005                       # the driver sits on the left
    fdm["/systems/occupants/driver-kg"] = 90.0
    car.run(0.1)
    assert weight_kg() == pytest.approx(alone + 30.0, abs=0.1)
    fdm["/systems/occupants/driver-kg"] = 60.0
    before = cg_m()
    fdm["/systems/codriver-enable"] = 1.0           # rear right seat
    car.run(0.1)
    assert weight_kg() == pytest.approx(alone + 60.0, abs=0.1)
    after = cg_m()
    assert after[0] > before[0] + 0.01 and after[1] > before[1] + 0.01
    car.run(2.0)
    loads = [fdm["tyre/%s/load_n" % w] for w in WHEELS]
    assert sum(loads) == pytest.approx(fdm["inertia/weight-lbs"] * 4.4482216, rel=0.02)
    assert loads[3] > loads[2]                      # rear right carries the co-driver


def test_launch_on_a_dry_road_is_quick_and_only_the_front_slips():
    result, rows = launch("tyre")
    assert 3.0 < result["time"] < 3.8
    # The open 50:50 centre differential gives the front axle half the torque
    # while the start moves weight rearward, so the front tyres slip past their
    # peak, lose grip there and spin up. A rear bias would hook up here but let
    # the rear spin first on a slippery road, which with nothing to catch it
    # turns the car round. Traction control is what should stop the spin.
    assert max(max(r["slip_ratio_bl"], r["slip_ratio_br"]) for r in rows) < 0.1
    assert result["max_slip"] < 1.5


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

    car = Car("tyre", speed=20, settle=0.6, params=NO_ABS)
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
    locked, _ = stop("tyre", pedal=1.0, params=NO_ABS)
    # Pedals found by search: each axle just short of locking.
    threshold, _ = stop("tyre", pedal=0.83, rear_pedal=0.90, params=NO_ABS)
    # The front wheels lock first; sliding, they brake less and the rear keeps rolling.
    assert locked["front_locked"]
    assert not threshold["front_locked"] and not threshold["rear_locked"]
    assert 35.0 < threshold["dist"] < 40.0
    assert locked["dist"] > 1.1 * threshold["dist"]


def test_locked_front_wheels_cannot_steer():
    locked, _ = stop("tyre", pedal=1.0, steer=0.15, params=NO_ABS)
    rolling, _ = stop("tyre", pedal=0.6, steer=0.15, params=NO_ABS)
    assert locked["yaw_dps"] < 2.0
    assert rolling["yaw_dps"] > 8.0


def test_a_locked_tyre_slides_at_three_quarters_of_its_peak_against_its_sliding():
    # NHTSA DOT HS 809 747 fig. 4.7: a production tyre on dry asphalt keeps
    # 680 of its 910 lb peak (75 %) fully locked.
    _, rows = stop("tyre", pedal=1.0, steer=0.1, params=NO_ABS)
    locked = [r for r in rows if r["slip_ratio_fl"] < -0.999 and r["u"] > 5.0]
    assert len(locked) > 100
    for r in locked:
        force = math.hypot(r["fx_n_fl"], r["fy_n_fl"])
        assert force == pytest.approx(0.75 * r["mu_x_fl"] * r["load_n_fl"], rel=0.01)
        assert math.atan2(r["fy_n_fl"], r["fx_n_fl"]) == pytest.approx(
            math.atan2(r["slip_tan_fl"], r["slip_ratio_fl"]), abs=1e-3)


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


def brake_torques(fdm, key):
    return [fdm[f"tyre/{w}/{key}"] for w in WHEELS]


def test_each_wheel_has_its_own_brake_request():
    car = Car("tyre", speed=20.0, settle=0.5)
    fdm = car.fdm
    front_nm, rear_nm = fdm["driveline/par/brake_front_nm"], fdm["driveline/par/brake_rear_nm"]
    car.run(0.1, brake=0.4, rear_brake=0.0)
    assert brake_torques(fdm, "brake_request_nm") == pytest.approx([0.4 * front_nm, 0.4 * front_nm, 0.0, 0.0])
    car.run(0.1, brake=0.0, rear_brake=0.7)
    assert brake_torques(fdm, "brake_request_nm") == pytest.approx([0.0, 0.0, 0.7 * rear_nm, 0.7 * rear_nm])
    # automatic braking (AEB, cruise control) reaches all four wheels like the pedal
    fdm["/systems/BrakeController/automatic-norm"] = 0.5
    car.run(0.1)
    assert brake_torques(fdm, "service_brake_nm") == pytest.approx(
        [0.5 * front_nm, 0.5 * front_nm, 0.5 * rear_nm, 0.5 * rear_nm])


def test_the_handbrake_lever_locks_only_the_rear_wheels():
    car = Car("tyre", speed=50 * KMH, settle=0.5)
    fdm = car.fdm
    fdm["/systems/BrakeController/handbrake-norm"] = 1.0
    rows = car.run(1.0)
    assert brake_torques(fdm, "service_brake_nm") == [0.0] * 4    # past the hydraulics
    assert min(r["slip_ratio_bl"] for r in rows[-30:]) < -0.9
    assert min(r["slip_ratio_br"] for r in rows[-30:]) < -0.9
    assert min(r["slip_ratio_fl"] for r in rows) > -0.05
    assert rows[-1]["u"] < rows[0]["u"] - 2.0
    # held through a corner it swings the tail out
    car = Car("tyre", speed=50 * KMH, settle=0.5)
    car.run(1.5, steer=0.1, cruise=50 * KMH)
    yaw_before = abs(car.fdm["velocities/r-rad_sec"])
    car.fdm["/systems/BrakeController/handbrake-norm"] = 1.0
    rows = car.run(1.0, steer=0.1)
    assert max(abs(r["yaw_rate"]) for r in rows) > 1.5 * yaw_before


@pytest.mark.parametrize("forward", [0.2, -0.2])
def test_the_parking_brake_holds_on_a_slope_by_the_rear_wheels(forward):
    car = Car("tyre")
    car.fdm["/controls/gear/brake-parking"] = 1.0
    car.run(0.5)
    car.push(forward=forward)
    assert moved(car.run(30.0)) < 0.01
    fdm = car.fdm
    assert brake_torques(fdm, "service_brake_nm") == [0.0] * 4
    assert fdm["brakes/mechanical_rear_nm"] == pytest.approx(fdm["driveline/par/parking_nm"])


def test_the_parking_brake_switched_on_while_driving_brakes_all_four_wheels():
    car = Car("tyre", speed=60 * KMH, settle=0.5)
    fdm = car.fdm
    fdm["/controls/gear/brake-parking"] = 1.0
    rows = car.run(1.0)
    norm = fdm["driveline/par/epb_dynamic_norm"]
    assert brake_torques(fdm, "brake_request_nm") == pytest.approx([
        norm * fdm["driveline/par/brake_front_nm"]] * 2 + [norm * fdm["driveline/par/brake_rear_nm"]] * 2)
    assert fdm["brakes/mechanical_rear_nm"] == 0.0
    assert 0.4 < -mean(rows[30:], "ax_g") < 0.8
    assert max(abs(r["yaw_rate"]) for r in rows) < 0.02             # no rear lock, no spin
    car.run(5.0)
    assert abs(fdm["velocities/u-fps"]) < 0.01
    assert fdm["brakes/mechanical_rear_nm"] == pytest.approx(fdm["driveline/par/parking_nm"])
    assert fdm["brakes/service_front"] == 0.0                        # at rest the clamp takes over


def test_auto_hold_holds_on_a_slope_with_the_service_brakes():
    car = Car("tyre")
    car.fdm["/systems/BrakeController/hold-norm"] = 1.0
    car.push(forward=0.2)
    assert moved(car.run(30.0)) < 0.01
    assert min(brake_torques(car.fdm, "service_brake_nm")) > 0.0


@pytest.mark.parametrize("surface", [1.0, 0.6, 0.3])
def test_abs_keeps_the_wheels_rolling_and_stops_shorter(surface):
    locked, _ = stop("tyre", pedal=1.0, surface=surface, params=NO_ABS)
    with_abs, rows = stop("tyre", pedal=1.0, surface=surface)
    assert locked["front_locked"]
    assert not with_abs["front_locked"] and not with_abs["rear_locked"]
    # NHTSA measured 10 to 17 % shorter than careful braking without ABS on dry
    # concrete and wet asphalt (SAE 1999-01-1287, table 2); locking is worse still.
    assert with_abs["dist"] < locked["dist"] / 1.12
    if surface == 1.0:
        # as short as the best split of the two pedals found by hand
        threshold, _ = stop("tyre", pedal=0.83, rear_pedal=0.90, params=NO_ABS)
        assert with_abs["dist"] < threshold["dist"] + 0.5


def test_abs_lets_the_car_steer_while_braking_hard():
    locked, _ = stop("tyre", pedal=1.0, steer=0.15, params=NO_ABS)
    with_abs, _ = stop("tyre", pedal=1.0, steer=0.15)
    assert with_abs["yaw_dps"] > 10.0
    assert with_abs["yaw_dps"] > 3.0 * locked["yaw_dps"]


def test_abs_stays_out_of_ordinary_braking():
    plain, _ = stop("tyre", pedal=0.4, params=NO_ABS)
    car = Car("tyre", speed=100 * KMH)
    rows, active = [], 0.0
    while not rows or abs(rows[-1]["u"]) >= 0.2:
        car.step(brake_front=0.4, brake_rear=0.4)
        rows.append(car.sample())
        active = max(active, car.fdm["abs/active"])
    assert active == 0.0
    assert moved(rows) == pytest.approx(plain["dist"], abs=0.01)


def test_abs_releases_coast_regen_and_leaves_the_handbrake_alone():
    car = Car("tyre", speed=60 * KMH, surface=0.3)
    car.run(0.5, brake=1.0)
    assert car.fdm["abs/active"] == 1.0
    assert car.fdm["driveline/motor_torque_nm"] == 0.0
    # the lever bypasses the hydraulics: ABS does not stop it locking the rear wheels
    car = Car("tyre", speed=60 * KMH, settle=0.5)
    car.fdm["/systems/BrakeController/handbrake-norm"] = 1.0
    car.run(0.5)
    assert car.fdm["tyre/bl/slip_ratio"] < -0.9


def split_grip_stop(params, steer_against_yaw):
    """Full braking from 80 km/h with the left wheels on asphalt and the right on ice.

    With steer_against_yaw, a driver holds the heading after 0.3 s, turning
    the wheel at most 18 deg/s and 6.75 deg at the road wheels.
    """
    grip = (1.0, 0.3, 1.0, 0.3)
    car = Car("tyre", speed=80 * KMH, params=params)
    fdm = car.fdm
    start, heading, steer, rows = fdm.get_sim_time(), 0.0, 0.0, []
    while fdm.get_sim_time() - start < 10.0 and fdm["velocities/u-fps"] * 0.3048 > 0.3:
        for unit, g in enumerate(grip):   # standalone JSBSim has one surface; seed each wheel's
            fdm[f"gear/unit[{unit}]/static-friction-factor"] = g
        if steer_against_yaw and fdm.get_sim_time() - start > 0.3:
            want = max(-0.15, min(0.15, -(1.5 * heading + 0.25 * fdm["velocities/r-rad_sec"])))
            steer += max(-0.4 * car.dt, min(0.4 * car.dt, want - steer))
        car.step(brake_front=1.0, brake_rear=1.0, steer=steer)
        row = car.sample()
        heading += row["yaw_rate"] * car.dt
        row["heading_deg"] = math.degrees(heading)
        row.update(("brake_" + w, fdm[f"tyre/{w}/service_brake_nm"]) for w in WHEELS)
        rows.append(row)
    return rows


def test_abs_on_split_grip_brakes_each_front_wheel_for_its_own_grip_and_stays_steerable():
    rows = split_grip_stop({}, steer_against_yaw=True)
    middle = rows[len(rows) // 3]
    assert middle["brake_fl"] > 1.5 * middle["brake_fr"]         # asphalt side brakes harder
    assert middle["brake_bl"] == middle["brake_br"]             # rear pair: select low
    assert max(abs(r["heading_deg"]) for r in rows) < 10.0
    assert all(r["slip_ratio_" + w] > -0.9 for r in rows if r["u"] > 3.0 for w in WHEELS)
    # without ABS the locked wheels cannot steer and the car turns round
    locked = split_grip_stop(NO_ABS, steer_against_yaw=True)
    assert max(abs(r["heading_deg"]) for r in locked) > 45.0


def test_abs_lets_split_grip_yaw_build_up_gradually():
    def heading_after_one_second(params):
        rows = split_grip_stop(params, steer_against_yaw=False)
        return abs(min(rows, key=lambda r: abs(r["t"] - rows[0]["t"] - 1.0))["heading_deg"])

    assert heading_after_one_second({}) < 0.9 * heading_after_one_second({"abs/par/yaw_delay_start": 1.0})


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
