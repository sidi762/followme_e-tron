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
# Equations, evaluated top to bottom on every FDM frame.
# A name is resolved, in this order, to: a value computed earlier in the same
# list, a parameter, an input, or one of the JSBSim properties in EXTERNAL.
# --------------------------------------------------------------------------
EXTERNAL = {
    "sim_dt": "simulation/channel-dt",
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
    # constant torque up to the power limit, then constant power
    ("drive_torque_nm", "throttle_norm * direction * rev_limit"
                        " * min(max_torque_nm, max_power_w / max(abs(motor_rad_sec), 1.0))"),
    # pedal released: a small torque against the rotation, zero at standstill
    ("coast_torque_nm", "-1.0 * coast_regen_nm * (1.0 - min(1.0, 20.0 * throttle_norm))"
                        " * max(-1.0, min(1.0, motor_rad_sec / coast_regen_fade_rad_sec))"),
    ("motor_torque_nm", "motor_on * (drive_torque_nm + coast_torque_nm)"),
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
    ("stiffness_x_n", "mu_x * load_n * curve_x_prev / slip_ratio_peak"),
    # Wheel spin. A free-rolling wheel is far too stiff to integrate explicitly
    # at 120 Hz, so the tyre force enters implicitly through its secant
    # stiffness, and brake plus rolling resistance act as Coulomb friction that
    # can hold the wheel at exactly zero (a locked wheel).
    ("drive_torque_nm", "{axle_torque} / {wheels_on_axle}"),
    # The park lock only bites below walking pace, so switching the motor off
    # at speed does not lock the wheels.
    ("park_torque_nm", "(1.0 - motor_on) * park_lock_nm * max(0.0, min(1.0, 1.5 - abs(vx_wheel_mps)))"),
    # This wheel's own brake. The hydraulic unit passes the service request on
    # unchanged for now; ABS and stability control will modulate it here.
    ("brake_request_nm", "{service_cmd} * {brake_par}"),
    ("service_brake_nm", "brake_request_nm"),
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
    ("fx_n", "mu_x * load_n * curve_x * slip_ratio / slip_ratio_peak"),
    ("fy_n", "mu_y * load_n * curve_y * slip_tan / slip_tan_peak"),
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
    for w in wheels:
        shared["omega_" + w.name] = "tyre/%s/omega_rad_sec" % w.name
    driveline_names = [name for name, _ in DRIVELINE_EQS]
    brake_names = [name for name, _ in BRAKE_EQS]
    wheel_names = set(LOAD_CURVES) | {eq[0] for eq in WHEEL_EQS}

    def resolve_driveline(name):
        if name in driveline_names:
            return "driveline/" + name
        return shared[name]

    def resolve_brakes(name):
        if name in brake_names:
            return "brakes/" + name
        return resolve_driveline(name)

    def axle_mean(axle):
        return "(%s) / %r" % (" + ".join("omega_" + w.name for w in axle), float(len(axle)))

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
           INDENT + "<!-- Inputs -->\n", _property_lines("driveline/in", DRIVELINE_INPUTS), "\n",
           INDENT + "<!-- State: wheel speeds -->\n"]
    for w in wheels:
        out.append('%s<property value="0.0">tyre/%s/omega_rad_sec</property>\n' % (INDENT, w.name))

    out.append('\n%s<channel name="Occupants">\n' % INDENT)
    for name, expr, outputs in OCCUPANT_EQS:
        out.append(fcs_function("occupants/" + name, expr, shared.__getitem__, outputs))
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

    for w in wheels:
        local = {
            "comp_ft": "gear/unit[%d]/compression-ft" % w.unit,
            "comp_vel_fps": "gear/unit[%d]/compression-velocity-fps" % w.unit,
            "steer_deg": "fcs/steer-pos-deg[%d]" % w.unit,
            "surface": "gear/unit[%d]/static-friction-factor" % w.unit,
            "roll_factor": "gear/unit[%d]/rolling_friction-factor" % w.unit,
        }

        def resolve_wheel(name, w=w, local=local):
            if name in wheel_names:
                return "tyre/%s/%s" % (w.name, name)
            if name in local:
                return local[name]
            return resolve_brakes(name)

        fields = {
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
            "reference_mu": LOAD_CURVES["brake_peak_mu"][1],
        }
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
    known |= {n for n, _ in DRIVELINE_EQS + BRAKE_EQS} | {eq[0] for eq in WHEEL_EQS}
    for eq in OCCUPANT_EQS + DRIVELINE_EQS + BRAKE_EQS + WHEEL_EQS:
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
