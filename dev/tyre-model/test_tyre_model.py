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
from sim import (KMH, SPLIT_ICE, WHEELS, Car, characteristic_speed, corner, full_throttle, late_slip, launch, mean,
                 moved, sine_with_dwell, sine_with_dwell_series, slowly_increasing_steer, stop)

REAR_DRIVE = {"driveline/par/front_torque_share": 0.0}
FRONT_DRIVE = {"driveline/par/front_torque_share": 1.0}
# For the tests of what the tyres themselves do when a wheel locks or spins.
NO_ABS = {"abs/par/enabled": 0.0}
NO_TC = {"tc/par/enabled": 0.0}
NO_ESC = {"esc/par/enabled": 0.0}


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
    result, rows = launch("tyre", params=NO_TC)
    assert 3.0 < result["time"] < 3.8
    # The open 50:50 centre differential gives the front axle half the torque
    # while the start moves weight rearward, so the front tyres slip past their
    # peak, lose grip there and spin up. A rear bias would hook up here but let
    # the rear spin first on a slippery road, which with nothing to catch it
    # turns the car round. Traction control stops both (tests further down).
    assert max(max(r["slip_ratio_bl"], r["slip_ratio_br"]) for r in rows) < 0.1
    assert result["max_slip"] < 1.5


def test_launch_on_a_slippery_road_spins_the_wheels_and_is_slow():
    dry, _ = launch("tyre", params=NO_TC)
    slippery, _ = launch("tyre", surface=0.3, params=NO_TC)
    assert slippery["reached"]
    assert slippery["time"] > 2.5 * dry["time"]
    assert slippery["peak_g"] < 0.4
    assert slippery["max_slip"] > 1.0
    # the standard FDM does not notice the surface at all
    assert launch("stock", surface=0.3)[0]["time"] == pytest.approx(launch("stock")[0]["time"], rel=0.01)


def test_smoke_follows_the_sliding_axle():
    car = Car("tyre", params=dict(REAR_DRIVE, **NO_TC))
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
    gentle, _ = corner("tyre", 30, 0.05, params=NO_ESC)
    assert gentle["radius"] == pytest.approx(gentle["geometric_radius"], rel=0.05)
    brisk, _ = corner("tyre", 90, 0.05, params=NO_ESC)
    assert brisk["radius"] > 1.15 * brisk["geometric_radius"]
    assert brisk["front_slip_deg"] > brisk["rear_slip_deg"]
    limit, _ = corner("tyre", 60, 0.2, params=NO_ESC)
    assert 0.85 < limit["lat_g"] < 1.02
    assert limit["noise_g"] < 0.01
    too_much_lock, _ = corner("tyre", 90, 0.4, params=NO_ESC)
    assert too_much_lock["lat_g"] < limit["lat_g"]      # over-slipped front tyres lose grip


def power_in_a_bend(params):
    """Full throttle from a steady 40 km/h bend; the largest body sideslip in deg."""
    car = Car("tyre", speed=40 * KMH, params=params)
    car.run(4.0, steer=0.2, cruise=40 * KMH)
    rows = car.run(3.0, steer=0.2, throttle=1.0)
    return max(abs(math.degrees(math.atan2(r["v"], max(r["u"], 0.1)))) for r in rows)


def test_drive_layout_decides_what_full_throttle_does_in_a_corner():
    assert power_in_a_bend(dict(REAR_DRIVE, **NO_TC, **NO_ESC)) > 45.0     # power oversteer: it spins
    assert power_in_a_bend(dict(FRONT_DRIVE, **NO_TC, **NO_ESC)) < 10.0    # it pushes wide instead


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
    rows = split_grip_stop(NO_ESC, steer_against_yaw=True)
    middle = rows[len(rows) // 3]
    assert middle["brake_fl"] > 1.5 * middle["brake_fr"]         # asphalt side brakes harder
    assert middle["brake_bl"] == middle["brake_br"]             # rear pair: select low
    assert max(abs(r["heading_deg"]) for r in rows) < 10.0
    assert all(r["slip_ratio_" + w] > -0.9 for r in rows if r["u"] > 3.0 for w in WHEELS)
    # without ABS the locked wheels cannot steer and the car turns round
    locked = split_grip_stop(dict(NO_ABS, **NO_ESC), steer_against_yaw=True)
    assert max(abs(r["heading_deg"]) for r in locked) > 45.0


def test_abs_lets_split_grip_yaw_build_up_gradually():
    def heading_after_one_second(params):
        rows = split_grip_stop(params, steer_against_yaw=False)
        return abs(min(rows, key=lambda r: abs(r["t"] - rows[0]["t"] - 1.0))["heading_deg"])

    assert heading_after_one_second(NO_ESC) < 0.9 * heading_after_one_second(
        dict(NO_ESC, **{"abs/par/yaw_delay_start": 1.0}))


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


# --------------------------------------------------------------------------
# Traction control (Docs/ESC/tc-esc-engineering-manual.md, section 6)
# --------------------------------------------------------------------------
MU0 = dict((name, value) for name, value, _ in generate.TYRE_PARAMS)["mu0"]


@pytest.mark.parametrize("surface", [1.0, 0.3])
def test_traction_control_launches_faster_and_keeps_the_wheels_near_their_peak(surface):
    off = full_throttle(params=NO_TC, surface=surface)
    on = full_throttle(surface=surface)
    assert on[-1]["t"] <= 1.01 * off[-1]["t"]
    assert late_slip(on) < 1.5                        # the tyres start sliding past 1.5
    if surface < 1.0:
        assert late_slip(off) > 50.0                  # without TC the wheels spin freely
        friction_limit = 100 * KMH / (surface * MU0 * 9.80665)
        assert on[-1]["t"] < 1.15 * friction_limit
        assert on[-1]["t"] < 0.85 * off[-1]["t"]


@pytest.mark.parametrize("params", [{"driveline/par/front_torque_share": 0.3}, REAR_DRIVE])
def test_traction_control_keeps_a_rear_biased_car_straight_on_ice(params):
    off = full_throttle(params=dict(params, **NO_TC), surface=0.3, until_kmh=60, seconds=15)
    on = full_throttle(params=params, surface=0.3, until_kmh=60, seconds=15)
    assert max(abs(r["heading_deg"]) for r in off) > 90.0     # the spinning rear wheels turn it round
    assert on[-1]["u"] >= 60 * KMH
    assert max(abs(r["heading_deg"]) for r in on) < 15.0


def test_traction_control_stops_power_oversteer():
    assert power_in_a_bend(REAR_DRIVE) < 10.0


def test_differential_locks_brake_the_spinning_wheels_on_split_grip():
    off = full_throttle(params=NO_TC, grip=SPLIT_ICE, until_kmh=60, hold_heading=True)
    on = full_throttle(grip=SPLIT_ICE, until_kmh=60, hold_heading=True)
    # Without the locks the wheels on ice spin up until the motor reaches its
    # speed limit, which then cuts the torque of all four.
    assert late_slip(off, ("fr", "br")) > 50.0
    assert on[-1]["t"] < 0.4 * off[-1]["t"]
    assert late_slip(on, ("fr", "br")) < 1.6
    assert max(r["stab_brake_nm_fr"] for r in on) <= 1120.0
    assert min(r["drive_nm"] for r in on if 0.05 < r["t"] < 1.5) > 50.0
    middle = on[len(on) // 2]
    assert middle["stab_brake_nm_fr"] > 100.0 and middle["stab_brake_nm_br"] > 100.0
    assert middle["stab_brake_nm_fl"] == 0.0 and middle["stab_brake_nm_bl"] == 0.0
    # The drive force on the asphalt side pulls the car round; a driver holds it
    # (left alone it turns about 30 deg by 60 km/h, which stability control
    # is to take on).
    assert max(abs(r["heading_deg"]) for r in on) < 5.0


def test_differential_locks_engage_only_at_low_speed_and_never_against_the_brake_pedal():
    # not above 40 km/h: the motor alone takes the spinning wheels
    rows = full_throttle(car=Car("tyre", speed=50 * KMH), grip=SPLIT_ICE, seconds=2.0)
    assert max(r["stab_brake_nm_" + w] for r in rows for w in WHEELS) == 0.0
    assert any(r["tc_active"] for r in rows)
    # engaged below 40 km/h, they cut out at 80 km/h
    rows = full_throttle(grip=SPLIT_ICE, until_kmh=90)
    assert max(r["stab_brake_nm_" + w] for r in rows if r["u"] < 70 * KMH for w in WHEELS) > 500.0
    assert max(r["stab_brake_nm_" + w] for r in rows if r["u"] > 80.5 * KMH for w in WHEELS) == 0.0
    # pressing the brake pedal releases them at once (VW SSP 374)
    car = Car("tyre")
    full_throttle(car=car, grip=SPLIT_ICE, seconds=1.0)
    assert max(car.fdm[f"tyre/{w}/stab_brake_nm"] for w in WHEELS) > 100.0
    for _ in range(3):
        car.step(throttle=1.0, brake_front=0.1, brake_rear=0.1)
    assert max(car.fdm[f"tyre/{w}/stab_brake_nm"] for w in WHEELS) == 0.0


def test_hot_brake_discs_fade_the_differential_locks_out():
    def launch_with_discs_at(temp_c):
        car = Car("tyre")
        rows = []
        for _ in range(int(2.0 / car.dt)):
            for unit, g in enumerate(SPLIT_ICE):
                car.fdm[f"gear/unit[{unit}]/static-friction-factor"] = g
            for w in WHEELS:
                car.fdm[f"tyre/{w}/disc_temp_c"] = max(temp_c, car.fdm[f"tyre/{w}/disc_temp_c"])
            car.step(throttle=1.0)
            rows.append(car.sample())
        return rows

    cold, hot = launch_with_discs_at(20.0), launch_with_discs_at(600.0)
    assert max(r["stab_brake_nm_fr"] for r in cold) > 500.0
    assert max(r["stab_brake_nm_" + w] for r in hot for w in WHEELS) == 0.0
    assert hot[-1]["u"] < 0.5 * cold[-1]["u"]          # the motor alone has to hold the ice side back


def test_drag_torque_control_keeps_coast_regen_from_locking_the_driven_wheels():
    def worst_braking_slip(params):
        car = Car("tyre", speed=40 * KMH, surface=0.1, params=dict(params, **{"driveline/par/coast_regen_nm": 300.0}))
        car.run(0.5)
        worst = 0.0
        for _ in range(int(2.5 / car.dt)):
            car.step()
            worst = max(worst, max(car.fdm[f"tyre/{w}/tc_brake_slip"] for w in WHEELS))
        return worst

    assert worst_braking_slip(NO_TC) > 3.0
    assert worst_braking_slip({}) < 0.7


def test_traction_control_works_in_reverse():
    off = full_throttle(params=NO_TC, surface=0.3, until_kmh=20, direction=-1.0)
    on = full_throttle(surface=0.3, until_kmh=20, direction=-1.0)
    assert on[-1]["u"] <= -20 * KMH
    assert on[-1]["t"] < off[-1]["t"]
    assert late_slip(on) < 1.5


def test_traction_control_stays_out_of_moderate_driving():
    car = Car("tyre")
    rows = car.run(6.0, throttle=0.3)
    _, bend = corner("tyre", 60, 0.1)
    assert not any(r["tc_active"] for r in rows + bend)


@pytest.mark.parametrize("hz", [60, 240])
def test_traction_control_does_not_depend_on_the_fdm_rate(hz):
    for kw in (dict(surface=0.3), dict(grip=SPLIT_ICE, until_kmh=60)):
        reference = full_throttle(**kw)[-1]["t"]
        assert full_throttle(dt=1.0 / hz, **kw)[-1]["t"] == pytest.approx(reference, rel=0.08)


# --------------------------------------------------------------------------
# Stability control (Docs/ESC/tc-esc-engineering-manual.md, section 7)
# --------------------------------------------------------------------------
def fmvss_126_a():
    """A, the steering wheel angle for 0.3 g at 80 km/h: mean of both directions (S7.6)."""
    return round(sum(abs(slowly_increasing_steer(sign)) for sign in (1.0, -1.0)) / 2.0, 1)


def fmvss_126_failures(params):
    """Sine with dwell runs of both series that miss S5.2.1 to S5.2.3."""
    a = fmvss_126_a()
    failures = []
    for sign in (1.0, -1.0):
        for amplitude, run in sine_with_dwell_series(a, sign, params=params):
            if not run["stable"] or (amplitude >= 5.0 * a and run["lateral_1_07"] < 1.83):
                failures.append((sign, amplitude, run["yaw_1_0"], run["yaw_1_75"], run["lateral_1_07"]))
    return failures


def test_stability_control_passes_the_fmvss_126_sine_with_dwell():
    assert 15.0 < fmvss_126_a() < 25.0
    # without ESC the car turns round from 5A on
    assert len(fmvss_126_failures(NO_ESC)) > 10
    assert fmvss_126_failures({}) == []


def test_stability_control_stays_out_of_the_linear_range_and_straight_driving():
    # Bosch: up to 4 m/s^2 of lateral acceleration a car responds linearly
    for kmh in (40, 80, 120):
        u = kmh * KMH
        for ay in (2.0, 4.0):
            _, rows = corner("tyre", kmh, (2.48 / u ** 2) * ay / math.radians(45.0))
            assert not any(r["esc_active"] for r in rows)
    assert not any(r["esc_active"] for r in sine_with_dwell(2.0 * fmvss_126_a())["rows"])
    assert not any(r["esc_active"] for r in full_throttle())
    assert not any(r["esc_active"] for r in stop("tyre", pedal=1.0)[1])


def test_stability_control_slows_an_understeering_car_and_tightens_its_line():
    def steady(params):
        car = Car("tyre", speed=90 * KMH, params=params)
        tail = car.run(6.0, steer=0.4, cruise=90 * KMH)[-120:]
        speed = math.hypot(mean(tail, "u"), mean(tail, "v"))
        return speed, speed ** 2 / (mean(tail, "ny", abs) * 9.80665)

    off, on = steady(NO_ESC), steady({})
    assert on[0] < off[0] - 10 * KMH         # slower
    assert on[1] < 0.8 * off[1]              # tighter path


def test_stability_control_stops_power_oversteer_without_traction_control():
    assert power_in_a_bend(dict(REAR_DRIVE, **NO_TC)) < 15.0       # over 45 deg without ESC


def test_stability_control_holds_split_grip_yaw_without_a_driver():
    # braking: the asphalt side's pressure is let off while the car turns too much
    off = split_grip_stop(NO_ESC, steer_against_yaw=False)
    on = split_grip_stop({}, steer_against_yaw=False)
    assert max(abs(r["heading_deg"]) for r in off) > 90.0
    assert max(abs(r["heading_deg"]) for r in on) < 45.0
    held_off = split_grip_stop(NO_ESC, steer_against_yaw=True)
    held_on = split_grip_stop({}, steer_against_yaw=True)
    assert moved(held_on) < 1.03 * moved(held_off)       # with a driver it costs no stopping distance
    # accelerating: the motor torque cut takes some of the pull out (a driver holds it all)
    off = full_throttle(params=NO_ESC, grip=SPLIT_ICE, until_kmh=60)
    on = full_throttle(grip=SPLIT_ICE, until_kmh=60)
    assert max(abs(r["heading_deg"]) for r in off) > 25.0
    assert max(abs(r["heading_deg"]) for r in on) < 0.85 * max(abs(r["heading_deg"]) for r in off)
    assert on[-1]["t"] < 1.5 * off[-1]["t"]


def test_stability_control_is_off_below_20_kmh_and_in_reverse():
    car = Car("tyre", speed=15 * KMH)
    rows = car.run(3.0, steer=0.6, cruise=15 * KMH)
    assert not any(r["esc_active"] for r in rows)
    car = Car("tyre", params={"driveline/in/direction": -1.0})
    car.run(4.0, throttle=1.0)
    assert car.fdm["velocities/u-fps"] * 0.3048 < -20 * KMH
    rows = car.run(2.0, throttle=1.0, steer=0.3)
    assert not any(r["esc_active"] for r in rows)


@pytest.mark.parametrize("hz", [60, 240])
def test_stability_control_does_not_depend_on_the_fdm_rate(hz):
    a = fmvss_126_a()
    for amplitude in (5.0 * a, 270.0):
        run = sine_with_dwell(amplitude, dt=1.0 / hz)
        assert run["stable"]
        assert run["lateral_1_07"] == pytest.approx(sine_with_dwell(amplitude)["lateral_1_07"], rel=0.08)


def test_stability_control_reference_uses_this_cars_characteristic_speed():
    gradient, v_char = characteristic_speed(80.0)
    assert 0.0 < gradient < 1.0                               # nearly neutral, slightly understeering
    parameter = dict((n, v) for n, v, _ in generate.ESC_PARAMS)["v_char_mps"]
    assert parameter == pytest.approx(v_char, rel=0.1)
