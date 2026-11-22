#!/usr/bin/env python3
"""Generate the tyre-model variant of the Follow Me EV flight model.

Reads   followme_e-tron.xml               (the standard FDM, never modified)
Writes  followme_e-tron-tyre.xml          the same FDM with JSBSim's wheel
                                          friction switched off and tyre forces
                                          fed in through <external_reactions>
        Systems/tyre-model.xml            the JSBSim <system> that computes
                                          those forces and the wheel speeds

Both outputs are plain JSBSim XML and are committed, so FlightGear needs
nothing from this directory. Run this script again after changing the model
below or the standard FDM:

    python3 dev/tyre-model/generate.py            # rewrite the two files
    python3 dev/tyre-model/generate.py --check    # fail if they are out of date

See README.md in this directory for what the model does and why.
"""
import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import mass
from jsbexpr import INDENT, fcs_function, names

REPO = Path(__file__).resolve().parents[2]
STOCK_FDM = REPO / "followme_e-tron.xml"
OUT_FDM = REPO / "followme_e-tron-tyre.xml"
OUT_SYSTEM = REPO / "Systems" / "tyre-model.xml"
SYSTEM_FILE = "tyre-model"

G = 9.80665

# --------------------------------------------------------------------------
# Parameters. Each becomes a JSBSim property that can be changed while the
# simulator runs (FlightGear: /fdm/jsbsim/tyre/par/... and .../driveline/par/...).
# Dry force measurements, fit procedure and limits are documented in README.md.
# --------------------------------------------------------------------------
TYRE_PARAMS = [
    ("mu0", 1.0935, "dry longitudinal peak at 4000 N; scales all three measured curves"),
    ("rolling_resistance", 0.0087, "Pilot Sport 4 S rolling resistance proxy, 8.7 kg/t"),
    ("radius_m", 0.31205, "mean kinematic rolling radius of the four KIT 4000 N longitudinal runs"),
    ("wheel_inertia_kgm2", 2.1, "one wheel plus its share of the motor rotor seen through the gear"),
    ("low_speed_mps", 3.0, "below this the slip definitions are softened; see README"),
    ("slide_ratio", 0.75, "a fully sliding tyre's friction as a share of its peak: production tyre on dry asphalt"
                          " at 40 km/h, NHTSA DOT HS 809 747 figure 4.7"),
    ("slide_start", 1.5, "past this multiple of the peak slip the force turns towards sliding friction"),
    ("stick_full_mps", 0.15, "a stopped wheel slower than this is held by JSBSim's static friction"),
    ("stick_none_mps", 0.50, "above this the tyre model alone acts"),
]

# KIT 205/55 R17 91H. Each column corresponds to one of the three test loads.
# Peak slip is a ratio longitudinally and tan(angle from zero lateral force) laterally.
TEST_LOADS_N = (1250, 4000, 6000)
LOAD_CURVES = {
    "drive_peak_mu":  (1.1532,   1.0935,   1.050333),
    "brake_peak_mu":  (1.1408,   1.0935,   1.07325),
    "side_peak_mu":   (1.1372,   1.014625, 0.95975),
    "drive_peak_slip": (0.18,     0.145,    0.085),
    "brake_peak_slip": (0.205,    0.14,     0.105),
    "side_peak_slip":  (0.184028, 0.169463, 0.182993),
    "drive_shape":     (1.322317, 1.192531, 1.282328),
    "brake_shape":     (1.247996, 1.267602, 1.285354),
    "side_shape":      (1.430374, 1.367815, 1.342919),
}

DRIVELINE_PARAMS = [
    ("gear", 9.73, "motor to wheel reduction"),
    ("max_torque_nm", 460.0, "motor torque limit"),
    ("max_power_w", 375000.0, "motor power limit"),
    ("max_speed_rad_sec", 3000.0, "motor speed limit; only there to stop a spinning wheel running away"),
    ("front_torque_share", 0.5, "0 = rear wheel drive, 1 = front wheel drive"),
    ("coast_regen_nm", 24.0, "motor braking torque with the pedal released (matches the standard FDM's coast-down)"),
    ("coast_regen_fade_rad_sec", 100.0, "coast regen fades out below this motor speed"),
    ("brake_front_nm", 2300.0, "brake torque per front wheel at full pedal"),
    ("brake_rear_nm", None, "brake torque per rear wheel at full pedal; follows the CG, see rear_brake_nm() in generate.py"),
    ("handbrake_nm", 1500.0, "handbrake lever torque per rear wheel, enough to lock them while driving"),
    ("parking_nm", 1500.0, "electric parking brake clamp torque per rear wheel"),
    ("epb_dynamic_mps", 2.0, "above this the parking brake switch brakes all four wheels hydraulically instead"),
    ("epb_dynamic_norm", 0.5, "service brake demand of that dynamic emergency braking"),
    ("park_lock_nm", 1000.0, "holding torque per wheel while the motor is switched off"),
    ("disc_kg_front", 9.0, "front brake disc mass (estimate); for the disc temperature traction control watches"),
    ("disc_kg_rear", 7.0, "rear brake disc mass (estimate)"),
    ("disc_heat_j_kgk", 460.0, "heat capacity of grey cast iron"),
    ("disc_cooling_w_k", 20.0, "disc cooling to the air at rest (estimate)"),
    ("disc_cooling_w_k_per_mps", 2.0, "extra disc cooling per m/s of road speed (estimate)"),
    ("ambient_c", 20.0, "air temperature the discs cool down to"),
]

# Written by Nasal/engine.nas in FlightGear, or by a test script.
DRIVELINE_INPUTS = [
    ("throttle_norm", 0.0, "accelerator pedal, 0 to 1"),
    ("direction", 1.0, "1 = forward, -1 = reverse"),
    ("motor_on", 1.0, "0 switches the motor off: no drive, no coast regen, park lock on"),
]

# The rear brakes are sized so that on equal grip the front axle reaches its
# limit first at any deceleration up to this one, a little above the dry peak.
BRAKE_BALANCE_G = 1.15

# Occupant weights live outside the FDM, which FlightGear resets on every
# reposition. The tyre variant's -set.xml gives them their defaults.
OCCUPANT_INPUTS = {
    "driver_kg": "/systems/occupants/driver-kg",
    "codriver_kg": "/systems/occupants/codriver-kg",
    "codriver_enable": "/systems/codriver-enable",
}

# Evaluated first on every frame; JSBSim applies the point masses in the same frame.
OCCUPANT_EQS = [
    ("driver_lbs", "max(0.0, driver_kg) * 2.2046226", ["inertia/pointmass-weight-lbs[0]"]),
    ("codriver_lbs", "codriver_enable * max(0.0, codriver_kg) * 2.2046226",
     ["inertia/pointmass-weight-lbs[1]"]),
]

# Braking intents, read separately from FlightGear properties instead of the
# two axle commands FlightGear hands JSBSim, which fold the parking brake into
# both. Nasal/systems/brakes.nas publishes the automatic ones.
BRAKE_INPUTS = {
    "pedal_front": "/controls/gear/brake-left",                 # LEFT is the front axle
    "pedal_rear": "/controls/gear/brake-right",
    "automatic": "/systems/BrakeController/automatic-norm",     # AEB and cruise control
    "hold": "/systems/BrakeController/hold-norm",               # Auto Hold at a standstill
    "handbrake": "/systems/BrakeController/handbrake-norm",     # the lever, held
    "parking": "/controls/gear/brake-parking",                  # electric parking brake
}

# Evaluated after the driveline, before the wheels; values under brakes/.
BRAKE_EQS = [
    # The parking brake switch clamps the rear wheels at a standstill. Moving,
    # it brakes all four wheels through the hydraulics, as real ones do.
    ("epb_dynamic", "parking * max(0.0, min(1.0, abs(u_mps) - epb_dynamic_mps + 0.5))"),
    # Service brake demand per axle: pedal, automatic braking, Auto Hold.
    ("service_front", "max(pedal_front, automatic, hold, epb_dynamic * epb_dynamic_norm)"),
    ("service_rear", "max(pedal_rear, automatic, hold, epb_dynamic * epb_dynamic_norm)"),
    # Lever and parking clamp act on the rear wheels mechanically, past the hydraulics.
    ("mechanical_rear_nm", "max(handbrake * handbrake_nm, (parking - epb_dynamic) * parking_nm)"),
]

# --------------------------------------------------------------------------
# ABS. It runs one frame behind the wheels, as a controller does: it reads the
# slip the tyre channels worked out in the previous frame and sets each
# wheel's hydraulic brake torque for this one. Like real valves it can only
# release, hold or rebuild pressure, never exceed the request. The front
# wheels are controlled one by one; the rear pair follows whichever rear wheel
# needs less ("select low"), so on split grip the rear axle adds no yaw.
# Only the service brakes pass through it; handbrake and parking clamp do not.
# --------------------------------------------------------------------------
ABS_PARAMS = [
    ("enabled", 1.0, "0 switches ABS off: each wheel gets its whole service brake request"),
    ("min_speed_mps", 2.5, "below this ABS lets the wheels lock, as real systems do near a standstill"),
    ("dump_slip", 1.0, "release above this braking slip, as a share of the tyre's peak slip at its load"),
    ("rebuild_slip", 0.6, "rebuild below this share; hold in between"),
    ("dump_rate", 15.0, "outlet valve: while releasing, the torque falls by this share per second, exponentially"),
    ("build_rate", 1.5, "pulsed inlet valve: while rebuilding, it rises by this share of the full-pedal torque per second"),
    ("yaw_delay_start", 0.1, "front wheels: while one is under ABS, the other may brake this share of the full-pedal torque harder"),
    ("yaw_delay_rate", 0.5, "and that margin grows by this share per second, so split grip turns the car gradually"),
]

# Pass one, every wheel: the request and what this wheel alone would need.
ABS_WHEEL_EQS = [
    # the driver's service brakes plus traction or stability control's request
    ("brake_request_nm", "min({brake_par}, {service_cmd} * {brake_par} * {esc_keep} + stab_brake_nm)"),
    # braking slip over the tyre's peak braking slip: above 1 the wheel is past its grip peak
    ("abs_slip", "max(0.0, -1.0 * slip_ratio * ifthen(lt(vx_wheel_mps, 0.0), -1.0, 1.0)) / brake_peak_slip"),
    ("abs_slip_rate", "(abs_slip - abs_slip_last) / dt_s"),
    ("abs_slip_last", "abs_slip"),
    # Release while past the peak and still slipping more. Once the wheel
    # starts to recover, hold: releasing further only wastes braking while
    # the heavy wheel spins back up.
    ("abs_wheel_mode", "ifthen(lt(abs_dump_slip, abs_slip) * (1.0 - lt(abs_slip_rate, 0.0)), -1.0,"
                       " ifthen(lt(abs_rebuild_slip, abs_slip), 0.0, 1.0))"),
]

# Pass two, every wheel: -1 release, 0 hold, 1 rebuild, then the valves.
ABS_VALVE_EQS = [
    ("abs_mode", "{abs_mode}"),
    # On when a wheel first needs releasing. Off when the request goes, the car
    # is nearly stopped, or the pressure is back up to the request.
    ("abs_active", "abs_enabled * lt(abs_min_speed_mps, abs(vx_wheel_mps)) * lt(0.0, brake_request_nm)"
                   " * max(abs_active, lt(abs_mode, -0.5))"
                   " * (1.0 - lt(0.5, abs_mode) * lt(brake_request_nm - 1.0, service_brake_nm))"),
    ("abs_valve_nm", "ifthen(abs_active, max(0.0, min(brake_request_nm, ifthen(lt(abs_mode, -0.5),"
                     " service_brake_nm * exp(-1.0 * abs_dump_rate * dt_s),"
                     " service_brake_nm + lt(0.5, abs_mode) * abs_build_rate * {brake_par} * dt_s))),"
                     " brake_request_nm)"),
    # Yaw moment build-up delay, front axle only: with one front wheel on ice
    # under ABS, the other one's extra braking is let in gradually, so the
    # driver has time to steer against the pull.
    ("abs_yaw_margin_nm", "{yaw_margin}"),
    ("service_brake_nm", "{service}"),
]

# --------------------------------------------------------------------------
# Traction control. Docs/ESC/tc-esc-engineering-manual.md describes it and
# its sources. Like ABS it runs one frame behind the wheels. Following Bosch's
# TCS for a four-wheel-drive car with open differentials, each controller
# regulates one variable: a propshaft speed controller sets the motor torque,
# and differential lock controllers brake a wheel that slips more than its
# axle partner (transversal) or an axle that slips more than the other one
# (longitudinal), so that the open differentials can pass the torque on. The
# brakes take the difference, the motor what all driven wheels share.
# --------------------------------------------------------------------------
TC_PARAMS = [
    ("enabled", 1.0, "0 switches traction control off: motor torque limit, differential locks, drag torque control"),
    ("target_slip", 0.85, "reference drive slip, as a share of the tyre's peak drive slip at its load"),
    ("corner_min", 0.4, "share of the reference slip left when the lateral grip is fully in use"),
    ("wheel_limit", 1.4, "no driven wheel the locks leave alone may slip more than this share of its peak"
                         " (the tyre starts sliding at 1.5)"),
    ("p_gain", 0.3, "motor limit, proportional part: share of the motor's maximum torque per unit slip error"),
    ("d_time", 0.025, "motor limit, derivative look-ahead time on the measured propshaft slip, in seconds"),
    ("d_filter_s", 0.025, "low-pass filter time constant for the propshaft slip rate, in seconds"),
    ("cut_rate", 10.0, "motor limit falls by this share of the maximum torque per second per unit slip error"),
    ("restore_rate", 5.0, "and rises by this share per second per unit of slip below the reference"),
    ("error_limit", 2.0, "the motor limit acts on at most this much slip error, so one flaring wheel cannot cut it all"),
    ("lock_deadband", 0.5, "differential locks engage once the slip difference passes this share of the peak"),
    ("lock_release", 0.1, "an engaged differential lock holds on down to this slip difference"),
    ("lock_target", 1.0, "an engaged differential lock brings the wheel back towards this share of its peak slip"),
    ("lock_p_gain", 0.2, "lock brake, proportional part: share of the wheel's maximum drive torque per unit slip error"),
    ("lock_rate", 8.0, "lock brake rises by this share of the wheel's maximum drive torque per second per unit error"),
    ("lock_engage_kmh", 40.0, "differential locks engage below this speed (Audi A4 workshop manual; ika: 38 km/h)"),
    ("lock_cutout_kmh", 80.0, "an engaged lock cuts out above this speed (four-wheel drive; Audi, VW SSP 374)"),
    ("pump_time_s", 0.15, "the pump builds a wheel's full-pedal brake torque in this time (Audi e-tron; ika 0.05-0.15 s)"),
    ("temp_fade_c", 450.0, "the locks start to fade out at this brake disc temperature (estimate)"),
    ("temp_off_c", 550.0, "and are out at this one"),
    ("drag_slip", 0.35, "drag torque control cuts coast regen above this braking slip, as a share of the peak"),
    ("drag_cut_rate", 20.0, "coast regen falls by this share per second while a driven wheel slips"),
    ("drag_restore_rate", 2.0, "and recovers by this share per second"),
]

# Global, before the wheels' signals; values under tc/.
TC_PRE_EQS = [
    ("dt", "max(sim_dt, 0.0005)"),
    ("speed_kmh", "abs(u_fps) * 1.09728"),
    # VW SSP 374: the brake pedal switches the differential locks off at once
    ("driver_braking", "lt(0.02, max(pedal_front, pedal_rear))"),
    ("lock_allowed", "tc_enabled * lt(0.01, throttle_norm) * (1.0 - driver_braking)"),
    ("front_driven", "lt(0.0, front_torque_share)"),
    ("rear_driven", "lt(front_torque_share, 1.0)"),
]

# Every wheel, from the previous frame's tyre state; values under tyre/<wheel>/.
TC_WHEEL_SIGNAL_EQS = [
    # drive slip over the tyre's peak drive slip, positive while the wheel turns
    # faster than the road in the drive direction (also in reverse)
    ("tc_slip", "slip_ratio * direction / drive_peak_slip"),
    ("tc_brake_slip", "max(0.0, -1.0 * slip_ratio * ifthen(lt(vx_wheel_mps, 0.0), -1.0, 1.0)) / brake_peak_slip"),
    # the brake temperature model fades the locks out between these temperatures
    ("tc_temp_factor", "max(0.0, min(1.0, (tc_temp_off_c - disc_temp_c) / (tc_temp_off_c - tc_temp_fade_c)))"),
    ("tc_wheel_torque_nm", "max_torque_nm * gear * {axle_share} / 2.0"),
    ("tc_request_wheel_nm", "abs(request_torque_nm) * gear * {axle_share} / 2.0"),
]

# Every wheel: transversal differential lock, braking the wheel that slips more
# than its axle partner, PI with the integral state as the brake torque.
TC_WHEEL_LOCK_EQS = [
    ("tc_lock_err", "min(tc_slip - tc_lock_target, tc_slip - partner_tc_slip"
                    " - ifthen(lt(0.0, tc_lock_state_nm), tc_lock_release, tc_lock_deadband))"),
    # engages below lock_engage_kmh; once braking, holds on up to lock_cutout_kmh
    ("tc_lock_on", "lock_allowed * {driven} * ifthen(lt(speed_kmh, tc_lock_engage_kmh), 1.0,"
                   " lt(speed_kmh, tc_lock_cutout_kmh) * lt(0.0, tc_lock_state_nm))"),
    # never ahead of what the pump can have built by the next frame (no wind-up)
    ("tc_lock_state_nm", "tc_lock_on * max(0.0, min({brake_par}, stab_brake_nm + dt * {brake_par} / tc_pump_time_s,"
                         " tc_lock_state_nm + dt * tc_lock_rate * tc_lock_err * tc_wheel_torque_nm))"),
    # never harder than the torque the driver's pedal asks for at this wheel
    ("tc_lock_nm", "tc_lock_on * tc_temp_factor * max(0.0, min({brake_par}, tc_request_wheel_nm,"
                   " tc_lock_state_nm + tc_lock_p_gain * tc_lock_err * tc_wheel_torque_nm))"),
    # what the motor controller sees: the slip this wheel's lock leaves, unless
    # the lock is out (fast, hot) or at its brake limit, where it hands over at
    # most 0.5 above the single-wheel limit
    ("tc_resid", "ifthen(tc_lock_on * lt(0.98 * {brake_par}, tc_lock_nm), min(tc_slip, tc_wheel_limit + 0.5),"
                 " tc_slip - tc_lock_on * tc_temp_factor * max(0.0, tc_lock_err))"),
]

# Global; values under tc/.
TC_AXLE_EQS = [
    ("axle_front", "(tc_resid_fl + tc_resid_fr) / 2.0"),
    ("axle_rear", "(tc_resid_bl + tc_resid_br) / 2.0"),
    ("awd", "front_driven * rear_driven"),
]

# Once per axle, {lock} being lock_front or lock_rear; values under tc/.
TC_LONGITUDINAL_EQS = [
    ("{lock}_temp", "min(tc_temp_factor_{w1}, tc_temp_factor_{w2})"),
    ("{lock}_wheel_torque_nm", "max_torque_nm * gear * {axle_share} / 2.0"),
    ("{lock}_request_wheel_nm", "abs(request_torque_nm) * gear * {axle_share} / 2.0"),
    # longitudinal differential lock: brakes both wheels of the axle that slips more
    ("{lock}_err", "min(axle_{axle} - tc_lock_target, axle_{axle} - axle_{other}"
                   " - ifthen(lt(0.0, {lock}_state_nm), tc_lock_release, tc_lock_deadband))"),
    ("{lock}_on", "lock_allowed * awd * ifthen(lt(speed_kmh, tc_lock_engage_kmh), 1.0,"
                  " lt(speed_kmh, tc_lock_cutout_kmh) * lt(0.0, {lock}_state_nm))"),
    ("{lock}_state_nm", "{lock}_on * max(0.0, min({brake_par},"
                        " min(stab_brake_nm_{w1}, stab_brake_nm_{w2}) + dt * {brake_par} / tc_pump_time_s,"
                        " {lock}_state_nm + dt * tc_lock_rate * {lock}_err * {lock}_wheel_torque_nm))"),
    ("{lock}_nm", "{lock}_on * {lock}_temp * max(0.0, min({brake_par}, {lock}_request_wheel_nm,"
                  " {lock}_state_nm + tc_lock_p_gain * {lock}_err * {lock}_wheel_torque_nm))"),
    ("prop_{axle}", "ifthen({lock}_on * lt(0.98 * {brake_par}, {lock}_nm), min(axle_{axle}, tc_wheel_limit + 0.5),"
                    " axle_{axle} - {lock}_on * {lock}_temp * max(0.0, {lock}_err))"),
]

# Global; values under tc/.
TC_MOTOR_EQS = [
    # Propshaft speed controller: the torque-weighted slip of the driven wheels
    # against a reference that leaves room for the lateral force in a bend.
    ("slip", "front_torque_share * prop_front + (1.0 - front_torque_share) * prop_rear"),
    ("raw_slip", "front_torque_share * (tc_slip_fl + tc_slip_fr) / 2.0"
                 " + (1.0 - front_torque_share) * (tc_slip_bl + tc_slip_br) / 2.0"),
    ("slip_rate", "(raw_slip - raw_slip_last + tc_d_filter_s * slip_rate) / (tc_d_filter_s + dt)"),
    ("raw_slip_last", "raw_slip"),
    ("mu_lateral", "(mu_y_fl + mu_y_fr + mu_y_bl + mu_y_br) / 4.0"),
    ("lateral_use", "min(1.0, abs(ny) / max(mu_lateral, 0.05))"),
    ("target", "tc_target_slip * max(tc_corner_min, sqrt(max(0.0, 1.0 - lateral_use * lateral_use)))"),
    # One wheel spinning on its own counts once it passes wheel_limit: above the
    # locks' speed range nothing else would stop it (ika: a wider band for the
    # faster wheel than for the slower one).
    ("wheel_max", "max(front_driven * max(tc_resid_fl, tc_resid_fr), rear_driven * max(tc_resid_bl, tc_resid_br))"),
    ("error", "min(tc_error_limit, max(slip + tc_d_time * slip_rate - target, wheel_max - tc_wheel_limit))"),
    ("request_nm", "abs(request_torque_nm)"),
    # Engaged when the slip passes the reference while torque is asked for;
    # it stays engaged while the limit is below the request.
    ("engaged", "tc_enabled * lt(0.5, request_nm) * max(lt(0.0, error), engaged * lt(cap_nm, request_nm - 0.5))"),
    # The integral state is the torque limit itself: never above the request,
    # so no wind-up, and it starts from the torque being driven.
    ("cap_nm", "ifthen(engaged, max(0.0, min(max_torque_nm, min(cap_nm, request_nm)"
               " - dt * max_torque_nm * error * ifthen(lt(0.0, error), tc_cut_rate, tc_restore_rate))), max_torque_nm)"),
    ("motor_cap_nm", "ifthen(engaged, max(0.0, cap_nm - tc_p_gain * error * max_torque_nm), 1000000.0)"),
    ("active", "max(engaged * lt(motor_cap_nm, request_nm - 0.5),"
               " lt(1.0, max(tc_lock_nm_fl, tc_lock_nm_fr, tc_lock_nm_bl, tc_lock_nm_br, lock_front_nm, lock_rear_nm)))"),
    # Drag torque control: coast regen must not lock the driven wheels.
    ("drag_slip_max", "max(front_driven * max(tc_brake_slip_fl, tc_brake_slip_fr),"
                      " rear_driven * max(tc_brake_slip_bl, tc_brake_slip_br))"),
    ("drag_factor", "ifthen(tc_enabled, max(0.0, min(1.0, drag_factor + dt * ifthen(lt(tc_drag_slip, drag_slip_max),"
                    " -1.0 * tc_drag_cut_rate, tc_drag_restore_rate))), 1.0)"),
]

# --------------------------------------------------------------------------
# Stability control (ESC), manual section 7. It follows the controller models
# ika fitted to driving tests of a BMW 330xi (four-wheel drive, nearly 50:50):
# the yaw rate is compared with a single-track reference of this car, and
# fixed thresholds of the error bring in a motor torque cut, the outer front
# brake (oversteer) or the inner rear brake (understeer). A sideslip
# limitation takes over beyond 10 deg. Like TC it runs one frame behind.
# --------------------------------------------------------------------------
ESC_PARAMS = [
    ("enabled", 1.0, "0 switches stability control off"),
    ("min_speed_kmh", 20.0, "acts above this speed, going forwards (FMVSS 126 S4: may be off below 20 km/h and in reverse)"),
    ("v_char_mps", 82.0, "this car's characteristic speed in the reference yaw rate, measured at 80 km/h"
                         " (characteristic_speed in sim.py)"),
    ("wheelbase_m", None, "front to rear axle, from the standard FDM"),
    ("ref_lag_s", 0.1, "the reference follows the steering with this lag, in phase with the car (ika: all-pass filter)"),
    ("yaw_limit_share", 1.0, "the reference yaw rate is at most this share of mu g / v (ika: mu = 1)"),
    ("understeer_limit_share", 1.5, "for the torque cut in understeer the reference may go up to this share of"
                                    " mu g / v, so that driving on with the wheel turned past the grip counts"),
    ("bend_yaw_rate", 0.05, "rad/s of yaw rate that make a bend; nothing acts below (ika)"),
    ("cut_error", 0.07, "rad/s of yaw rate error from which the motor torque is cut (ika)"),
    ("cut_full", 0.15, "rad/s of yaw rate error at which the cut reaches torque_share"),
    ("torque_share", 0.25, "the motor torque is cut down to this share of the request at most (ika)"),
    ("torque_hold_s", 0.3, "the cut holds this long after the error has eased (ika: 2 s, too long for daily driving)"),
    ("torque_restore_s", 0.3, "then the torque returns from torque_share to the request in this time"),
    ("oversteer_start", 0.07, "rad/s of oversteer error at which the outer front brake starts"),
    ("oversteer_full", 0.15, "and at which it reaches oversteer_nm (ika, BMW 330xi: 600 N m at 0.098 to 2400 at 0.15)"),
    ("oversteer_nm", 2000.0, "outer front brake torque at oversteer_full"),
    ("understeer_start", 0.07, "rad/s of understeer error at which the inner rear brake starts"),
    ("understeer_full", 0.10, "and at which it reaches understeer_nm (ika)"),
    ("understeer_nm", 600.0, "inner rear brake torque at understeer_full (ika)"),
    ("beta_start_deg", 10.0, "sideslip limitation: half its torque from this body sideslip (ika)"),
    ("beta_full_deg", 12.0, "and all of it from this one (ika)"),
    ("beta_nm", 600.0, "front brake torque on the side the car slides towards (ika)"),
    ("beta_damping", 0.6, "each return from the sideslip limitation scales yaw control's brakes by this (ika)"),
    ("release_share", 0.8, "oversteer while braking: the driver's pressure on the inner wheels, which turn the car"
                           " further, is reduced by up to this share (Audi SSP: pressure reduction)"),
    ("reset_steer_deg", 1.0, "with the road wheels within this angle and no bend the scaling resets to 1"),
]

# Global, after TC's motor controller; values under esc/.
ESC_EQS = [
    ("speed_mps", "u_fps * 0.3048"),
    ("on", "esc_enabled * lt(esc_min_speed_kmh / 3.6, speed_mps)"),
    ("delta_rad", "steer_front_deg * 0.017453293"),
    # single-track reference with this car's characteristic speed, limited by the friction
    ("ref_steady", "speed_mps * delta_rad / (esc_wheelbase_m * (1.0 + pow(speed_mps / esc_v_char_mps, 2.0)))"),
    ("ref_limit", "esc_yaw_limit_share * mu_lateral * 9.80665 / max(speed_mps, 1.0)"),
    ("ref", "ref + (max(-1.0 * ref_limit, min(ref_limit, ref_steady)) - ref) * min(1.0, dt / esc_ref_lag_s)"),
    ("ref_us", "ref_us + (max(-1.0 * esc_understeer_limit_share * ref_limit, min(esc_understeer_limit_share * ref_limit,"
               " ref_steady)) - ref_us) * min(1.0, dt / esc_ref_lag_s)"),
    # errors signed into the direction the car turns: oversteer turns it too much
    ("turn", "ifthen(lt(0.0, r), 1.0, -1.0)"),
    ("bend", "on * lt(esc_bend_yaw_rate, abs(r))"),
    ("oversteer", "bend * (r - ref) * turn"),
    ("understeer", "bend * (ref - r) * turn"),
    # past the grip: braking the inner rear wheel there would only spin the car (sine with
    # dwell), but the motor torque can still be taken off
    ("understeer_drive", "bend * (ref_us - r) * turn"),
    ("beta_deg", "atan(v_fps / max(abs(u_fps), 1.0)) * 57.29578"),
    # Brake torques grow with the error past its threshold, and with the road's friction: on ice
    # a dry-road torque would only drive the wheel deep into ABS.
    ("grip", "min(1.0, mu_lateral)"),
    ("oversteer_nm", "grip * esc_oversteer_nm * max(0.0, min(1.0, (oversteer - esc_oversteer_start)"
                     " / (esc_oversteer_full - esc_oversteer_start)))"),
    ("understeer_nm", "grip * esc_understeer_nm * max(0.0, min(1.0, (understeer - esc_understeer_start)"
                      " / (esc_understeer_full - esc_understeer_start)))"),
    # sideslip limitation: brake the front wheel on the side the car slides towards
    ("beta_nm", "on * grip * lt(esc_beta_start_deg, abs(beta_deg)) * esc_beta_nm * (0.5 + 0.5 * min(1.0,"
                " (abs(beta_deg) - esc_beta_start_deg) / (esc_beta_full_deg - esc_beta_start_deg)))"),
    ("beta_active", "lt(1.0, beta_nm)"),
    ("damping", "ifthen(lt(abs(steer_front_deg), esc_reset_steer_deg) * lt(abs(r), esc_bend_yaw_rate), 1.0,"
                " ifthen(beta_was_active * (1.0 - beta_active), damping * esc_beta_damping, damping))"),
    ("beta_was_active", "beta_active"),
    # turning right (r > 0) the outer front wheel is the left one, the inner rear the right one
    ("brake_fl", "ifthen(beta_active, beta_nm * lt(beta_deg, 0.0), damping * oversteer_nm * lt(0.0, turn))"),
    ("brake_fr", "ifthen(beta_active, beta_nm * lt(0.0, beta_deg), damping * oversteer_nm * lt(turn, 0.0))"),
    ("brake_bl", "(1.0 - beta_active) * damping * understeer_nm * lt(turn, 0.0)"),
    ("brake_br", "(1.0 - beta_active) * damping * understeer_nm * lt(0.0, turn)"),
    # the share of the driver's brake pressure each wheel keeps: in oversteer the
    # inner wheels' braking turns the car further (split grip), so it is reduced
    ("release", "esc_release_share * max(0.0, min(1.0, (oversteer - esc_oversteer_start)"
                " / (esc_oversteer_full - esc_oversteer_start)))"),
    ("keep_fl", "1.0 - release * lt(turn, 0.0)"),
    ("keep_fr", "1.0 - release * lt(0.0, turn)"),
    ("keep_bl", "1.0 - release * lt(turn, 0.0)"),
    ("keep_br", "1.0 - release * lt(0.0, turn)"),
    # Motor torque: cut with the error, down to torque_share, at once; once the error
    # eases it holds a moment, then the torque comes back smoothly.
    ("cut_target", "1.0 - (1.0 - esc_torque_share) * max(0.0, min(1.0, (max(oversteer, understeer_drive) - esc_cut_error)"
                   " / (esc_cut_full - esc_cut_error)))"),
    ("hold_s", "ifthen(lt(cut_target, torque_factor + 0.001), esc_torque_hold_s, max(0.0, hold_s - dt))"),
    ("torque_factor", "ifthen(on, ifthen(lt(cut_target, torque_factor), cut_target, ifthen(lt(0.0, hold_s),"
                      " torque_factor, min(cut_target, torque_factor + dt * (1.0 - esc_torque_share)"
                      " / esc_torque_restore_s))), 1.0)"),
    ("active", "on * max(lt(1.0, max(brake_fl, brake_fr, brake_bl, brake_br)), lt(0.001, release),"
               " lt(torque_factor, 0.99) * lt(1.0, abs(request_torque_nm)))"),
]

# Every wheel: the stability brake request, built up by the pump and released
# at once. ABS limits it like the driver's request.
TC_WHEEL_BRAKE_EQS = [
    ("stab_target_nm", "min({brake_par}, min(tc_request_wheel_nm, tc_lock_nm + {axle_lock}) + {esc_brake})"),
    ("stab_brake_nm", "min(stab_target_nm, stab_brake_nm + dt * {brake_par} / tc_pump_time_s)"),
]

TC_WHEEL_EQS = TC_WHEEL_SIGNAL_EQS + TC_WHEEL_LOCK_EQS + TC_WHEEL_BRAKE_EQS
# Per-wheel values the global equations read, as <name>_<wheel>.
TC_WHEEL_SHARED = ("tc_slip", "tc_resid", "tc_brake_slip", "tc_temp_factor", "tc_lock_nm", "mu_y", "stab_brake_nm")


def tc_axle_fields(axle, axle_wheels):
    """The fields that turn TC_LONGITUDINAL_EQS into one axle's equations."""
    return {"lock": "lock_" + axle, "axle": axle, "other": "rear" if axle == "front" else "front",
            "w1": axle_wheels[0].name, "w2": axle_wheels[1].name,
            "axle_share": "front_torque_share" if axle == "front" else "(1.0 - front_torque_share)",
            "brake_par": "brake_%s_nm" % axle}

# --------------------------------------------------------------------------
# Equations, evaluated top to bottom on every FDM frame.
# A name is resolved, in this order, to: a value computed earlier in the same
# list, a parameter, an input, or one of the JSBSim properties in EXTERNAL.
# --------------------------------------------------------------------------
EXTERNAL = {
    "sim_dt": "simulation/channel-dt",
    "ny": "accelerations/Ny",
    "sim_time": "simulation/sim-time-sec",
    "u_fps": "velocities/u-fps",
    "v_fps": "velocities/v-fps",
    "p": "velocities/p-rad_sec",
    "q": "velocities/q-rad_sec",
    "r": "velocities/r-rad_sec",
    # The occupants move the CG, so the wheel positions are taken from it live
    "cg_x_in": "inertia/cg-x-in",
    "cg_y_in": "inertia/cg-y-in",
    "cg_z_in": "inertia/cg-z-in",
}

# {front_omega} / {rear_omega} expand to the mean wheel speed of each axle.
DRIVELINE_EQS = [
    # JSBSim reports dt = 0 while it trims; never divide by that
    ("dt_s", "max(sim_dt, 0.0005)"),
    ("u_mps", "u_fps * 0.3048"),
    ("v_mps", "v_fps * 0.3048"),
    # open centre differential: motor speed is the torque-weighted axle speed
    ("motor_rad_sec", "gear * (front_torque_share * {front_omega}"
                      " + (1.0 - front_torque_share) * {rear_omega})"),
    ("rev_limit", "max(0.0, min(1.0, (max_speed_rad_sec - abs(motor_rad_sec))"
                  " / (0.05 * max_speed_rad_sec)))"),
    # the driver's request: constant torque up to the power limit, then constant power
    ("request_torque_nm", "throttle_norm * direction * rev_limit"
                          " * min(max_torque_nm, max_power_w / max(abs(motor_rad_sec), 1.0))"),
    # what the motor drives: the request, limited by traction control, and ESC's share of that
    ("drive_torque_nm", "request_torque_nm * min(1.0, motor_cap_nm / max(abs(request_torque_nm), 0.001))"
                        " * torque_factor"),
    # pedal released: a small torque against the rotation, zero at standstill
    ("coast_torque_nm", "-1.0 * coast_regen_nm * (1.0 - min(1.0, 20.0 * throttle_norm))"
                        " * max(-1.0, min(1.0, motor_rad_sec / coast_regen_fade_rad_sec))"),
    # coast regen brakes the wheels outside ABS's control, so it lets go while ABS
    # works, and drag torque control scales it down when it makes a wheel slip
    ("motor_torque_nm", "motor_on * (drive_torque_nm + coast_torque_nm * drag_factor * (1.0 - abs_any))"),
    ("axle_torque_front_nm", "motor_torque_nm * gear * front_torque_share"),
    ("axle_torque_rear_nm", "motor_torque_nm * gear * (1.0 - front_torque_share)"),
]

# {..} fields are filled in per wheel from the standard FDM.
# Each entry: (name, expression) or (name, expression, [extra output properties]).
WHEEL_EQS = [
    # Load on the wheel, from the state of JSBSim's own strut (one frame old).
    ("load_n", "max(0.0, {spring} * comp_ft + {damping} * comp_vel_fps) * 4.4482216"),
    # Contact point relative to the CG: forward, right and below it.
    ("x_body_m", "cg_x_in * 0.0254 - {x_struct}"),
    ("y_body_m", "{y_struct} - cg_y_in * 0.0254"),
    ("cg_height_m", "cg_z_in * 0.0254 - {z_struct} - comp_ft * 0.3048"),
    # Velocity of the contact patch: body axes, then the wheel's own axes.
    ("vx_mps", "u_mps + q * cg_height_m - r * y_body_m"),
    ("vy_mps", "v_mps + r * x_body_m - p * cg_height_m"),
    ("steer_rad", "{steer}"),
    ("vx_wheel_mps", "vx_mps * cos(steer_rad) + vy_mps * sin(steer_rad)"),
    ("vy_wheel_mps", "vy_mps * cos(steer_rad) - vx_mps * sin(steer_rad)"),
    ("v_ref_mps", "max(abs(vx_wheel_mps), low_speed_mps)"),
    # Slip with the wheel speed left over from the previous frame.
    ("slip_ratio_prev", "(omega_rad_sec * radius_m - vx_wheel_mps) / v_ref_mps"),
    ("slip_tan", "-1.0 * vy_wheel_mps / v_ref_mps"),
    # A locked wheel in reverse has positive slip. Select the braking curve by
    # whether the slip opposes travel, independent of the selected drive gear.
    ("braking", "lt(slip_ratio_prev * vx_wheel_mps, 0.0)"),
    ("slip_ratio_peak", "ifthen(braking, brake_peak_slip, drive_peak_slip)"),
    ("slip_tan_peak", "side_peak_slip"),
    ("shape_x", "ifthen(braking, brake_shape, drive_shape)"),
    ("grip_scale", "mu0 / {reference_mu}"),
    ("mu_x", "surface * grip_scale * ifthen(braking, brake_peak_mu, drive_peak_mu)"),
    ("mu_y", "surface * grip_scale * side_peak_mu"),
    ("mu", "max(mu_x, mu_y)"),
    ("slip_norm_prev", "sqrt(pow(slip_ratio_prev / slip_ratio_peak, 2.0)"
                       " + pow(slip_tan / slip_tan_peak, 2.0) + 0.00000001)"),
    # For a normalised slip of 1, C * atan(B) = pi/2 for each fitted shape.
    ("curve_x_prev", "sin(shape_x * atan(tan(1.5707963267948966 / shape_x) * slip_norm_prev)) / slip_norm_prev"),
    # Far past the peak the tread is sliding. The fitted curves keep about 94 %
    # of their peak there, a measured production tyre 75 %, and sliding rubber
    # pulls straight against its sliding direction whatever the wheel's heading.
    # So from slide_start times the peak slip to full sliding (a locked wheel,
    # or 45 degrees sideways) the force blends into that sliding friction.
    ("mu_slide", "slide_ratio * mu_x"),
    ("sigma_prev", "sqrt(pow(slip_ratio_prev, 2.0) + pow(slip_tan, 2.0) + 0.00000001)"),
    ("slide_prev", "max(0.0, min(1.0, (sigma_prev - slide_start * slip_ratio_peak)"
                   " / (1.0 - slide_start * slip_ratio_peak)))"),
    ("stiffness_x_n", "load_n * ((1.0 - slide_prev) * mu_x * curve_x_prev / slip_ratio_peak"
                      " + slide_prev * mu_slide / sigma_prev)"),
    # Wheel spin. A free-rolling wheel is far too stiff to integrate explicitly
    # at 120 Hz, so the tyre force enters implicitly through its secant
    # stiffness, and brake plus rolling resistance act as Coulomb friction that
    # can hold the wheel at exactly zero (a locked wheel).
    ("drive_torque_nm", "{axle_torque} / {wheels_on_axle}"),
    # The park lock only bites below walking pace, so switching the motor off
    # at speed does not lock the wheels.
    ("park_torque_nm", "(1.0 - motor_on) * park_lock_nm * max(0.0, min(1.0, 1.5 - abs(vx_wheel_mps)))"),
    # This wheel's own brake: the hydraulic torque the ABS channel let through,
    # handbrake or parking clamp, park lock and rolling resistance.
    ("brake_torque_nm", "service_brake_nm + {mechanical} + park_torque_nm"
                        " + rolling_resistance * roll_factor * load_n * radius_m"),
    ("implicit_gain", "radius_m * radius_m * stiffness_x_n / v_ref_mps"),
    ("numerator", "wheel_inertia_kgm2 * omega_rad_sec / dt_s + drive_torque_nm"
                  " + implicit_gain * vx_wheel_mps / radius_m"),
    # A fresh FDM (FlightGear builds one on every reposition) must not inherit a
    # wheel speed that does not match the road, so for its first frames the
    # wheel is simply set rolling with the road.
    ("omega_rad_sec", "ifthen(lt(sim_time, 0.05), vx_wheel_mps / radius_m,"
                      " numerator * max(abs(numerator) - brake_torque_nm, 0.0)"
                      " / (max(abs(numerator), 0.000001) * (wheel_inertia_kgm2 / dt_s + implicit_gain)))"),
    # Keep the implicit longitudinal stiffness unless the new slip would take
    # the resultant outside the friction ellipse. Lateral force uses the new slip.
    ("slip_ratio", "(omega_rad_sec * radius_m - vx_wheel_mps) / v_ref_mps"),
    ("slip_norm", "sqrt(pow(slip_ratio / slip_ratio_peak, 2.0)"
                  " + pow(slip_tan / slip_tan_peak, 2.0) + 0.00000001)"),
    ("curve_x", "min(curve_x_prev, 1.0 / slip_norm)"),
    ("curve_y", "sin(side_shape * atan(tan(1.5707963267948966 / side_shape) * slip_norm)) / slip_norm"),
    ("sigma", "sqrt(pow(slip_ratio, 2.0) + pow(slip_tan, 2.0) + 0.00000001)"),
    ("slide", "max(0.0, min(1.0, (sigma - slide_start * slip_ratio_peak) / (1.0 - slide_start * slip_ratio_peak)))"),
    ("fx_n", "load_n * ((1.0 - slide) * mu_x * curve_x * slip_ratio / slip_ratio_peak"
             " + slide * mu_slide * slip_ratio / sigma)"),
    ("fy_n", "load_n * ((1.0 - slide) * mu_y * curve_y * slip_tan / slip_tan_peak"
             " + slide * mu_slide * slip_tan / sigma)"),
    # Standstill. A slip-based tyre cannot hold a parked car: it creeps. So a
    # wheel that is nearly stationary over the ground and not turning (held by
    # the brake, or just by its rolling resistance) is handed to JSBSim's own
    # static friction, and taken back as soon as it turns.
    ("contact_speed_mps", "sqrt(vx_wheel_mps * vx_wheel_mps + vy_wheel_mps * vy_wheel_mps)"),
    ("locked", "ifthen(lt(abs(omega_rad_sec), 0.000001), 1.0, 0.0)"),
    ("stick", "locked * max(0.0, min(1.0, (stick_none_mps - contact_speed_mps)"
              " / (stick_none_mps - stick_full_mps)))"),
    # The native lateral solver applies the wheel's surface factor itself.
    ("jsb_static_mu", "stick * grip_scale * side_peak_mu",
     ["gear/unit[{unit}]/static_friction_coeff"]),
    ("jsb_rolling_mu", "stick * min(surface * grip_scale * brake_peak_mu, brake_torque_nm / (radius_m * max(load_n, 1.0)))"
                       " / max(roll_factor, 0.05)",
     ["gear/unit[{unit}]/rolling_friction_coeff"]),
    # Back to body axes and pounds, applied at the contact patch.
    ("fx_body_lbs", "(1.0 - stick) * (fx_n * cos(steer_rad) - fy_n * sin(steer_rad)) * 0.22480894",
     ["external_reactions/tyre_{wheel}_x/magnitude"]),
    ("fy_body_lbs", "(1.0 - stick) * (fx_n * sin(steer_rad) + fy_n * cos(steer_rad)) * 0.22480894",
     ["external_reactions/tyre_{wheel}_y/magnitude"]),
    ("contact_z_in", "({z_struct} + comp_ft * 0.3048) / 0.0254",
     ["external_reactions/tyre_{wheel}_x/location-z-in",
      "external_reactions/tyre_{wheel}_y/location-z-in"]),
    # Contact-patch dissipation: longitudinal force times tread slip speed,
    # plus lateral force opposing sideslip. No sliding work in static contact.
    ("slip_power_w", "(1.0 - stick) * max(0.0, fx_n * (omega_rad_sec * radius_m - vx_wheel_mps)"
                     " - fy_n * vy_wheel_mps)"),
    # Visual onset and saturation, not a rubber temperature model.
    ("smoke_norm", "min(1.0, max(0.0, (slip_power_w - 3000.0) / 30000.0))"
                   " * min(1.0, max(0.0, (slip_norm - 1.0) / 0.5))"),
    # 0 to 1: how far past the grip peak the tyre is sliding. For sound effects.
    ("squeal", "(1.0 - stick) * min(1.0, load_n / load_nominal_n)"
               " * max(0.0, min(1.0, (slip_norm - 0.8) / 0.7))"),
    # Brake disc temperature from the friction brakes' power and cooling to the
    # air. Traction control fades its brakes out when a disc gets hot.
    ("disc_temp_c", "disc_temp_c + dt_s * ((service_brake_nm + {mechanical}) * abs(omega_rad_sec)"
                    " - (disc_cooling_w_k + disc_cooling_w_k_per_mps * abs(vx_wheel_mps)) * (disc_temp_c - ambient_c))"
                    " / ({disc_kg} * disc_heat_j_kgk)"),
]


class Wheel:
    def __init__(self, name, unit, x, y, z, spring, damping, steered, front):
        self.name = name          # fl, fr, bl, br
        self.unit = unit          # JSBSim gear/unit[] index
        self.x, self.y, self.z = x, y, z   # structural frame, metres, unloaded contact point
        self.spring = spring      # lbs/ft
        self.damping = damping    # lbs/ft/sec
        self.steered = steered
        self.front = front


def _number(element, tag, unit):
    child = element.find(tag)
    if child is None:
        raise ValueError("<%s> missing in <%s>" % (tag, element.tag))
    if unit is not None and child.get("unit") != unit:
        raise ValueError("<%s> is in %r, expected %r" % (tag, child.get("unit"), unit))
    return float(child.text)


def _location(element, **attrs):
    for loc in element.findall("location"):
        if all(loc.get(k) == v for k, v in attrs.items()):
            if loc.get("unit") != "M":
                raise ValueError("location is in %r, expected 'M'" % loc.get("unit"))
            return tuple(float(loc.find(axis).text) for axis in "xyz")
    raise ValueError("<location %s> not found in <%s>" % (attrs, element.tag))


def read_vehicle(stock_text):
    """The wheels of the standard FDM and the tyre variant's mass with its default driver.

    Returns (cg, mass_kg, wheels). The CG is for the car with the default
    driver aboard; the FDM itself follows the occupants' weights while running.
    """
    root = ET.fromstring(stock_text)
    mass_kg, cg, _ = mass.with_occupants()
    wheels = []
    for unit, contact in enumerate(root.find("ground_reactions").findall("contact")):
        if contact.get("type") != "BOGEY":
            continue
        x, y, z = _location(contact)
        wheels.append(Wheel(
            name=contact.get("name").lower(), unit=unit, x=x, y=y, z=z,
            spring=_number(contact, "spring_coeff", "LBS/FT"),
            damping=_number(contact, "damping_coeff", "LBS/FT/SEC"),
            steered=_number(contact, "max_steer", "DEG") != 0.0,
            front=x < cg[0]))          # structural x points aft
    if len(wheels) != 4 or sum(w.front for w in wheels) != 2:
        raise ValueError("expected two front and two rear BOGEY contacts")
    return cg, mass_kg, wheels


def wheelbase(wheels):
    """Front to rear axle in metres."""
    front_x = sum(w.x for w in wheels if w.front) / 2.0
    rear_x = sum(w.x for w in wheels if not w.front) / 2.0
    return round(rear_x - front_x, 3)


def rear_brake_nm(front_nm, cg, mass_kg, wheels):
    """Rear brake torque that shares braking out like the axle loads at BRAKE_BALANCE_G.

    Below that deceleration the front axle carries a smaller share of the load
    than of the braking, so on equal grip the front wheels reach their limit
    first and a locking car stays straight.
    """
    front_x = sum(w.x for w in wheels if w.front) / 2.0
    rear_x = sum(w.x for w in wheels if not w.front) / 2.0
    wheelbase = rear_x - front_x
    to_rear = rear_x - cg[0]
    axle_n = {True: mass_kg * G * to_rear / wheelbase, False: mass_kg * G * (wheelbase - to_rear) / wheelbase}
    # the ground under the settled car, in the structural frame
    ground_z = sum(w.z + axle_n[w.front] / 2.0 / (w.spring * 4.4482216 / 0.3048) for w in wheels) / 4.0
    height = cg[2] - ground_z
    front_share = (to_rear + height * BRAKE_BALANCE_G) / wheelbase
    return round(front_nm * (1.0 - front_share) / front_share, 1)


def _mass_balance():
    """The tyre variant's <mass_balance>: mass.py's empty car plus the two occupants."""
    kg, cg, inertia = mass.empty()
    pad = "    "

    def location(point, indent):
        return ("%s<location%s unit=\"M\">\n" % (indent[0], indent[1])
                + "".join("%s    <%s> %.3f </%s>\n" % (indent[0], axis, value, axis)
                          for axis, value in zip("xyz", point))
                + "%s</location>\n" % indent[0])

    out = [pad + "<!-- From dev/tyre-model/mass.py: components placed from the 3D model, a 90 kWh\n"
           + pad + "     floor battery and one motor driving all four wheels. Inertia about the\n"
           + pad + "     empty CG; the products of inertia are small and left out. The occupants'\n"
           + pad + "     weights are set on every frame by Systems/tyre-model.xml. -->\n",
           pad + "<mass_balance>\n"]
    for axis, i in (("ixx", 0), ("iyy", 1), ("izz", 2)):
        out.append('%s    <%s unit="KG*M2"> %.0f </%s>\n' % (pad, axis, inertia[i][i], axis))
    out.append('%s    <emptywt unit="KG"> %.1f </emptywt>\n' % (pad, kg))
    out.append(location(cg, (pad + "    ", ' name="CG"')))
    for name, default_kg, at in mass.OCCUPANTS:
        weight = default_kg if name == "Driver" else 0.0
        out.append('%s    <pointmass name="%s">\n' % (pad, name))
        out.append('%s        <weight unit="KG"> %.1f </weight>\n' % (pad, weight))
        out.append(location(at, (pad + "        ", "")))
        out.append("%s    </pointmass>\n" % pad)
    out.append(pad + "</mass_balance>\n")
    return "".join(out)


def _property_lines(prefix, items):
    return "".join('%s<property value="%r">%s/%s</property> <!-- %s -->\n'
                   % (INDENT, float(value), prefix, name, note) for name, value, note in items)


def _load_curve_xml(output, load_property, values):
    rows = "".join(f"\t\t\t\t\t\t{load} {value}\n" for load, value in zip(TEST_LOADS_N, values))
    return (f'\t\t<fcs_function name="{output}">\n'
            f'\t\t\t<function>\n\t\t\t\t<table>\n'
            f'\t\t\t\t\t<independentVar>{load_property}</independentVar>\n'
            f'\t\t\t\t\t<tableData>\n{rows}\t\t\t\t\t</tableData>\n'
            f'\t\t\t\t</table>\n\t\t\t</function>\n\t\t</fcs_function>\n')


def build_system(stock_text):
    cg, mass_kg, wheels = read_vehicle(stock_text)
    front = [w for w in wheels if w.front]
    rear = [w for w in wheels if not w.front]

    tyre_params = TYRE_PARAMS + [
        ("load_nominal_n", round(mass_kg * G / len(wheels), 1), "a quarter of the car's weight with the driver"),
    ]
    front_brake = dict((name, value) for name, value, _ in DRIVELINE_PARAMS)["brake_front_nm"]
    driveline_params = [(name, rear_brake_nm(front_brake, cg, mass_kg, wheels) if value is None else value, note)
                        for name, value, note in DRIVELINE_PARAMS]
    shared = dict(EXTERNAL)
    shared.update(OCCUPANT_INPUTS)
    shared.update(BRAKE_INPUTS)
    shared.update((name, "tyre/par/" + name) for name, _, _ in tyre_params)
    shared.update((name, "driveline/par/" + name) for name, _, _ in DRIVELINE_PARAMS)
    shared.update((name, "driveline/in/" + name) for name, _, _ in DRIVELINE_INPUTS)
    shared.update(("abs_" + name, "abs/par/" + name) for name, _, _ in ABS_PARAMS)
    shared.update(("tc_" + name, "tc/par/" + name) for name, _, _ in TC_PARAMS)
    shared.update(("esc_" + name, "esc/par/" + name) for name, _, _ in ESC_PARAMS)
    shared["abs_any"] = "abs/active"
    shared["steer_front_deg"] = "fcs/steer-pos-deg[%d]" % front[0].unit
    esc_params = [(name, wheelbase(wheels) if value is None else value, note) for name, value, note in ESC_PARAMS]
    for w in wheels:
        shared["omega_" + w.name] = "tyre/%s/omega_rad_sec" % w.name
        shared["esc_brake_" + w.name] = "esc/brake_" + w.name
        shared["esc_keep_" + w.name] = "esc/keep_" + w.name
        for key in TC_WHEEL_SHARED:
            shared["%s_%s" % (key, w.name)] = "tyre/%s/%s" % (w.name, key)
    driveline_names = [name for name, _ in DRIVELINE_EQS]
    brake_names = [name for name, _ in BRAKE_EQS]
    wheel_names = (set(LOAD_CURVES) | {eq[0] for eq in WHEEL_EQS}
                   | {name for name, _ in ABS_WHEEL_EQS + ABS_VALVE_EQS + TC_WHEEL_EQS})
    longitudinal = [(name.format(**fields), expr.format(**fields))
                    for fields in (tc_axle_fields("front", front), tc_axle_fields("rear", rear))
                    for name, expr in TC_LONGITUDINAL_EQS]
    tc_names = {name for name, _ in TC_PRE_EQS + TC_AXLE_EQS + TC_MOTOR_EQS + longitudinal}
    esc_names = {name for name, _ in ESC_EQS}

    def resolve_tc(name):
        if name in tc_names:
            return "tc/" + name
        return resolve_brakes(name)

    def resolve_esc(name):
        if name in esc_names:
            return "esc/" + name
        return resolve_tc(name)

    def resolve_driveline(name):
        if name in driveline_names:
            return "driveline/" + name
        if name in tc_names:
            return "tc/" + name
        if name in esc_names:
            return "esc/" + name
        return shared[name]

    def resolve_brakes(name):
        if name in brake_names:
            return "brakes/" + name
        return resolve_driveline(name)

    def axle_mean(axle):
        return "(%s) / %r" % (" + ".join("omega_" + w.name for w in axle), float(len(axle)))

    def wheel_resolver(w):
        local = {
            "comp_ft": "gear/unit[%d]/compression-ft" % w.unit,
            "comp_vel_fps": "gear/unit[%d]/compression-velocity-fps" % w.unit,
            "steer_deg": "fcs/steer-pos-deg[%d]" % w.unit,
            "surface": "gear/unit[%d]/static-friction-factor" % w.unit,
            "roll_factor": "gear/unit[%d]/rolling_friction-factor" % w.unit,
        }
        axle = front if w.front else rear
        partner = [other for other in axle if other is not w][0]
        for name in ("abs_wheel_mode", "abs_active", "service_brake_nm", "tc_slip", "stab_brake_nm"):
            local["partner_" + name] = "tyre/%s/%s" % (partner.name, name)
        local["partner_wheel_mode"] = local.pop("partner_abs_wheel_mode")
        local["partner_service_nm"] = local.pop("partner_service_brake_nm")

        def resolve_wheel(name):
            if name in wheel_names:
                return "tyre/%s/%s" % (w.name, name)
            if name in local:
                return local[name]
            return resolve_brakes(name)
        return resolve_wheel

    def wheel_fields(w):
        return {
            "wheel": w.name,
            "unit": w.unit,
            "spring": repr(w.spring),
            "damping": repr(w.damping),
            # structural frame: x aft, y right, z up
            "x_struct": repr(w.x),
            "y_struct": repr(w.y),
            "z_struct": repr(w.z),
            "steer": "steer_deg * 0.017453293" if w.steered else "0.0",
            "axle_torque": "axle_torque_front_nm" if w.front else "axle_torque_rear_nm",
            "wheels_on_axle": repr(float(len(front if w.front else rear))),
            "service_cmd": "service_front" if w.front else "service_rear",
            "brake_par": "brake_front_nm" if w.front else "brake_rear_nm",
            "mechanical": "0.0" if w.front else "mechanical_rear_nm",
            "disc_kg": "disc_kg_front" if w.front else "disc_kg_rear",
            "axle_share": "front_torque_share" if w.front else "(1.0 - front_torque_share)",
            "driven": "front_driven" if w.front else "rear_driven",
            "axle_lock": "lock_front_nm" if w.front else "lock_rear_nm",
            "esc_brake": "esc_brake_" + w.name,
            "esc_keep": "esc_keep_" + w.name,
            "reference_mu": LOAD_CURVES["brake_peak_mu"][1],
            # The rear pair follows the wheel that needs less (select low), except
            # while traction or stability control brakes one of them on purpose.
            "abs_mode": "abs_wheel_mode" if w.front else ("ifthen(lt(0.0, stab_brake_nm + partner_stab_brake_nm),"
                                                          " abs_wheel_mode, min(abs_wheel_mode, partner_wheel_mode))"),
            "yaw_margin": ("ifthen(partner_abs_active, min({brake_par}, abs_yaw_margin_nm + abs_yaw_delay_rate"
                           " * {brake_par} * dt_s), abs_yaw_delay_start * {brake_par})"
                           .format(brake_par="brake_front_nm")) if w.front else "0.0",
            # the yaw delay holds back plain braking, not a request made for traction or stability
            "service": ("ifthen(partner_abs_active * (1.0 - lt(0.0, stab_brake_nm)),"
                        " min(abs_valve_nm, partner_service_nm + abs_yaw_margin_nm), abs_valve_nm)")
                       if w.front else "abs_valve_nm",
        }

    out = ['<?xml version="1.0"?>\n',
           "<!--\n"
           "\tGENERATED FILE: edit dev/tyre-model/generate.py and run it again.\n\n"
           "\tTyre and driveline model for the Follow Me EV. Loaded by\n"
           "\tfollowme_e-tron-tyre.xml; described in dev/tyre-model/README.md.\n"
           "-->\n",
           '<system name="Tyre and driveline model">\n\n',
           INDENT + "<!-- Tyre parameters -->\n", _property_lines("tyre/par", tyre_params), "\n",
           INDENT + "<!-- Driveline and brake parameters -->\n",
           _property_lines("driveline/par", driveline_params), "\n",
           INDENT + "<!-- ABS parameters -->\n", _property_lines("abs/par", ABS_PARAMS), "\n",
           INDENT + "<!-- Traction control parameters -->\n", _property_lines("tc/par", TC_PARAMS), "\n",
           INDENT + "<!-- Stability control parameters -->\n", _property_lines("esc/par", esc_params), "\n",
           INDENT + "<!-- Inputs -->\n", _property_lines("driveline/in", DRIVELINE_INPUTS), "\n",
           INDENT + "<!-- State: wheel speeds, and what the ABS and stability control channels read"
                    " before the wheels compute it -->\n"]
    ambient = dict((name, value) for name, value, _ in DRIVELINE_PARAMS)["ambient_c"]
    for w in wheels:
        for name in ("omega_rad_sec", "slip_ratio", "vx_wheel_mps", "abs_slip_last", "abs_active", "abs_yaw_margin_nm",
                     "service_brake_nm", "tc_lock_state_nm", "stab_brake_nm"):
            out.append('%s<property value="0.0">tyre/%s/%s</property>\n' % (INDENT, w.name, name))
        for name, value in (("brake_peak_slip", 0.1), ("drive_peak_slip", 0.1), ("mu_y", 1.0), ("disc_temp_c", ambient)):
            out.append('%s<property value="%r">tyre/%s/%s</property>\n' % (INDENT, value, w.name, name))
    for name, value in (("abs/active", 0.0), ("driveline/request_torque_nm", 0.0), ("tc/engaged", 0.0),
                        ("tc/cap_nm", 0.0), ("tc/raw_slip_last", 0.0), ("tc/slip_rate", 0.0), ("tc/drag_factor", 1.0),
                        ("tc/lock_front_state_nm", 0.0), ("tc/lock_rear_state_nm", 0.0), ("esc/ref", 0.0), ("esc/ref_us", 0.0),
                        ("esc/damping", 1.0), ("esc/beta_was_active", 0.0), ("esc/hold_s", 0.0),
                        ("esc/torque_factor", 1.0)):
        out.append('%s<property value="%r">%s</property>\n' % (INDENT, value, name))

    out.append('\n%s<channel name="Occupants">\n' % INDENT)
    for name, expr, outputs in OCCUPANT_EQS:
        out.append(fcs_function("occupants/" + name, expr, shared.__getitem__, outputs))
    out.append("%s</channel>\n" % INDENT)

    out.append('\n%s<channel name="Traction and stability control">\n' % INDENT)
    for name, expr in TC_PRE_EQS:
        out.append(fcs_function("tc/" + name, expr, resolve_tc))
    for eqs in (TC_WHEEL_SIGNAL_EQS, TC_WHEEL_LOCK_EQS):
        for w in wheels:
            for name, expr in eqs:
                out.append(fcs_function("tyre/%s/%s" % (w.name, name), expr.format(**wheel_fields(w)),
                                        wheel_resolver(w)))
    for name, expr in TC_AXLE_EQS + longitudinal + TC_MOTOR_EQS:
        out.append(fcs_function("tc/" + name, expr, resolve_tc))
    for name, expr in ESC_EQS:
        out.append(fcs_function("esc/" + name, expr, resolve_esc))
    for w in wheels:
        for name, expr in TC_WHEEL_BRAKE_EQS:
            out.append(fcs_function("tyre/%s/%s" % (w.name, name), expr.format(**wheel_fields(w)), wheel_resolver(w)))
    out.append("%s</channel>\n" % INDENT)

    out.append('\n%s<channel name="Driveline">\n' % INDENT)
    fields = {"front_omega": axle_mean(front), "rear_omega": axle_mean(rear)}
    for name, expr in DRIVELINE_EQS:
        out.append(fcs_function("driveline/" + name, expr.format(**fields), resolve_driveline))
    out.append("%s</channel>\n" % INDENT)

    out.append('\n%s<channel name="Brakes">\n' % INDENT)
    for name, expr in BRAKE_EQS:
        out.append(fcs_function("brakes/" + name, expr, resolve_brakes))
    out.append("%s</channel>\n" % INDENT)

    out.append('\n%s<channel name="ABS">\n' % INDENT)
    for eqs in (ABS_WHEEL_EQS, ABS_VALVE_EQS):
        for w in wheels:
            for name, expr in eqs:
                out.append(fcs_function("tyre/%s/%s" % (w.name, name), expr.format(**wheel_fields(w)),
                                        wheel_resolver(w)))
    actives = {"active_" + w.name: "tyre/%s/abs_active" % w.name for w in wheels}
    out.append(fcs_function("abs/active", "max(%s)" % ", ".join(actives), actives.__getitem__))
    out.append("%s</channel>\n" % INDENT)

    for w in wheels:
        fields, resolve_wheel = wheel_fields(w), wheel_resolver(w)
        out.append('\n%s<channel name="Tyre %s">\n' % (INDENT, w.name))
        for eq in WHEEL_EQS:
            name, expr = eq[0], eq[1].format(**fields)
            outputs = [o.format(**fields) for o in (eq[2] if len(eq) > 2 else [])]
            out.append(fcs_function("tyre/%s/%s" % (w.name, name), expr, resolve_wheel, outputs))
            if name == "load_n":
                for parameter, values in LOAD_CURVES.items():
                    out.append(_load_curve_xml(resolve_wheel(parameter), resolve_wheel("load_n"), values))
        out.append("%s</channel>\n" % INDENT)

    out.append("\n</system>\n")
    return "".join(out)


def _external_reactions(stock_text, test_forces):
    cg, _, wheels = read_vehicle(stock_text)
    pad = "    "
    out = [pad + "<!-- Tyre forces, computed by Systems/tyre-model.xml -->\n",
           pad + "<external_reactions>\n"]

    def force(name, location, direction):
        out.append('%s  <force name="%s" frame="BODY">\n' % (pad, name))
        out.append('%s    <location unit="M">\n' % pad)
        for axis, value in zip("xyz", location):
            out.append("%s        <%s> %r </%s>\n" % (pad, axis, value, axis))
        out.append("%s    </location>\n%s    <direction>\n" % (pad, pad))
        for axis, value in zip("xyz", direction):
            out.append("%s      <%s>%d</%s>\n" % (pad, axis, value, axis))
        out.append("%s    </direction>\n%s  </force>\n" % (pad, pad))

    for w in wheels:
        force("tyre_%s_x" % w.name, (w.x, w.y, w.z), (1, 0, 0))
        force("tyre_%s_y" % w.name, (w.x, w.y, w.z), (0, 1, 0))
    if test_forces:
        # Not in the shipped FDM. A push at the CG stands in for the pull of a
        # slope, which standalone JSBSim (flat ground only) cannot provide.
        force("test_push_x", cg, (1, 0, 0))
        force("test_push_y", cg, (0, 1, 0))
    out.append(pad + "</external_reactions>\n")
    return "".join(out)


FDM_HEADER = """<!--
    GENERATED FILE: edit followme_e-tron.xml or dev/tyre-model/generate.py and
    run the generator again.

    This is followme_e-tron.xml with four changes:
      - the four wheels keep their struts but JSBSim's own wheel friction and
        brakes are switched off,
      - the four drive forces are replaced by tyre forces at the contact patches,
      - Systems/tyre-model.xml computes those forces,
      - mass, CG and inertia come from dev/tyre-model/mass.py, with point
        masses for the driver and the co-driver.
    See dev/tyre-model/README.md.
-->
"""


def build_fdm(stock_text, test_forces=False):
    xml = stock_text

    def strip_wheel(match):
        block = match.group(0)
        for tag in ("static_friction", "dynamic_friction", "rolling_friction"):
            block, n = re.subn(r"<%s>[^<]*</%s>" % (tag, tag), "<%s> 0.0 </%s>" % (tag, tag), block)
            assert n == 1, tag
        block = re.sub(r"[ \t]*<table name=\"CORNERING_COEFF\".*?</table>\n", "", block, flags=re.S)
        block, n = re.subn(r"<brake_group>[^<]*</brake_group>", "<brake_group> NONE </brake_group>", block)
        assert n == 1
        return block

    xml, n = re.subn(r"<contact type=\"BOGEY\".*?</contact>", strip_wheel, xml, flags=re.S)
    assert n == 4, n
    xml, n = re.subn(r"[ \t]*<mass_balance>.*?</mass_balance>\n",
                     lambda m: _mass_balance(), xml, flags=re.S)
    assert n == 1, n
    xml, n = re.subn(r"[ \t]*<external_reactions>.*?</external_reactions>\n",
                     lambda m: _external_reactions(stock_text, test_forces), xml, flags=re.S)
    assert n == 1, n
    xml, n = re.subn(r"\n</fdm_config>",
                     lambda m: '\n    <system file="%s"/>\n\n</fdm_config>' % SYSTEM_FILE, xml)
    assert n == 1, n
    first_line, rest = xml.split("\n", 1)
    assert first_line.startswith("<?xml"), first_line
    return first_line + "\n" + FDM_HEADER + rest


def check_equations():
    """Catch a typo in an equation before JSBSim does, with a clearer message."""
    known = set(EXTERNAL) | set(LOAD_CURVES) | {"comp_ft", "comp_vel_fps", "steer_deg", "surface", "roll_factor"}
    known |= {n for n, _, _ in TYRE_PARAMS + DRIVELINE_PARAMS + DRIVELINE_INPUTS} | {"load_nominal_n"}
    known |= {"omega_fl", "omega_fr", "omega_bl", "omega_br"} | set(OCCUPANT_INPUTS) | set(BRAKE_INPUTS)
    known |= {n for n, _ in DRIVELINE_EQS + BRAKE_EQS + ABS_WHEEL_EQS + ABS_VALVE_EQS} | {eq[0] for eq in WHEEL_EQS}
    known |= {"abs_" + n for n, _, _ in ABS_PARAMS} | {"abs_any", "partner_wheel_mode", "partner_abs_active", "partner_service_nm"}

    class _Wheel:
        def __init__(self, name):
            self.name = name

    longitudinal = [(name.format(**fields), expr.format(**fields))
                    for fields in (tc_axle_fields("front", [_Wheel("fl"), _Wheel("fr")]),
                                   tc_axle_fields("rear", [_Wheel("bl"), _Wheel("br")]))
                    for name, expr in TC_LONGITUDINAL_EQS]
    known |= {"tc_" + n for n, _, _ in TC_PARAMS} | {n for n, _ in TC_PRE_EQS + TC_AXLE_EQS + TC_MOTOR_EQS + longitudinal}
    known |= {n for n, _ in TC_WHEEL_EQS} | {"partner_tc_slip", "partner_stab_brake_nm"}
    known |= {"esc_" + n for n, _, _ in ESC_PARAMS} | {n for n, _ in ESC_EQS} | {"steer_front_deg"}
    known |= {prefix + w for prefix in ("esc_brake_", "esc_keep_") for w in ("fl", "fr", "bl", "br")}
    known |= {"%s_%s" % (key, w) for key in TC_WHEEL_SHARED for w in ("fl", "fr", "bl", "br")}
    for eq in (OCCUPANT_EQS + DRIVELINE_EQS + BRAKE_EQS + ABS_WHEEL_EQS + ABS_VALVE_EQS + WHEEL_EQS
               + TC_PRE_EQS + TC_WHEEL_EQS + TC_AXLE_EQS + longitudinal + TC_MOTOR_EQS + ESC_EQS):
        expr = re.sub(r"\{\w+\}", "0.0", eq[1])
        unknown = names(expr) - known
        if unknown:
            raise ValueError("%s uses undefined %s" % (eq[0], sorted(unknown)))


def generate(stock_text, test_forces=False):
    """Return (fdm_xml, system_xml) for the given standard FDM text."""
    check_equations()
    return build_fdm(stock_text, test_forces), build_system(stock_text)


def read_text(path):
    """Return (text with LF line ends, the line end the file actually uses)."""
    raw = path.read_bytes().decode("utf-8")
    return raw.replace("\r\n", "\n"), "\r\n" if "\r\n" in raw else "\n"


def stale_outputs():
    """The outputs whose committed content differs from what would be generated.

    Returns [(path, new_text, newline)]; line-end style alone never counts as a
    difference, so a checkout with converted line ends still passes.
    """
    stock_text, stock_newline = read_text(STOCK_FDM)
    fdm_xml, system_xml = generate(stock_text)
    stale = []
    # the FDM copy keeps the standard FDM's line ends so the two diff cleanly
    for path, text, newline in ((OUT_FDM, fdm_xml, stock_newline), (OUT_SYSTEM, system_xml, "\n")):
        if not path.exists():
            stale.append((path, text, newline))
            continue
        current, current_newline = read_text(path)
        if current != text:
            stale.append((path, text, current_newline))
    return stale


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="do not write; exit 1 if the committed files are out of date")
    args = parser.parse_args(argv)

    stale = stale_outputs()
    if args.check:
        for path, _, _ in stale:
            print("out of date:", path.relative_to(REPO))
        return 1 if stale else 0
    OUT_SYSTEM.parent.mkdir(exist_ok=True)
    for path, text, newline in stale:
        path.write_bytes(text.replace("\n", newline).encode("utf-8"))
        print("wrote", path.relative_to(REPO))
    if not stale:
        print("already up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
