"""Mass, centre of gravity and moments of inertia of the tyre model variant.

The standard FDM gives the car 1575 kg with the CG 0.82 m behind the front axle
(67 % of the weight on the front wheels) and moments of inertia several times
those of a car this size. The tyre variant builds them up from components
instead, each placed where Models/followme.ac and the interior models put it.

Axes are JSBSim's structural frame, which the 3D model shares: x aft from the
front bumper, y right, z up from the bottom of the unloaded tyres. Metres, kg.

The car carries a 90 kWh battery (Nasal/electrical.nas) under the floor and one
motor that drives all four wheels through a centre differential, as the tyre
model's driveline does. The component masses are estimates for a 3.8 m car of
this kind. The body shell takes whatever is left of the kerb mass and is spread
over the exterior mesh by area; fit_body_shell.py measures that mesh.

Standard library only: generate.py imports it.
"""

KERB_KG = 1575.0             # the standard FDM's empty weight, kept

# name, kg, box corner, opposite box corner. A box spreads its mass evenly
# through its volume; a box of zero size is a point mass.
COMPONENTS = [
    # 90 kWh at about 165 Wh/kg at pack level, between the wheel arches
    ("battery pack", 545.0, (0.98, -0.62, 0.15), (2.85, 0.62, 0.30)),
    # one motor driving all four wheels: motor, inverter, reduction gear and
    # centre differential on the front axle, a shaft to a rear differential
    ("drive unit", 105.0, (0.40, -0.28, 0.20), (0.90, 0.28, 0.50)),
    ("propeller shaft", 12.0, (0.90, -0.05, 0.24), (2.95, 0.05, 0.30)),
    ("rear differential", 28.0, (3.00, -0.18, 0.20), (3.30, 0.18, 0.40)),
    # wheel, tyre, brake, hub, knuckle, drive shaft and half the links
    ("unsprung front left", 40.0, (0.675, -0.67, 0.295), (0.675, -0.67, 0.295)),
    ("unsprung front right", 40.0, (0.675, 0.67, 0.295), (0.675, 0.67, 0.295)),
    ("unsprung rear left", 40.0, (3.155, -0.67, 0.295), (3.155, -0.67, 0.295)),
    ("unsprung rear right", 40.0, (3.155, 0.67, 0.295), (3.155, 0.67, 0.295)),
    # subframe, steering, strut tops, 12 V battery, cooling, brake unit, crash structure
    ("front compartment", 120.0, (0.10, -0.60, 0.30), (0.95, 0.60, 0.85)),
    # subframe, springs and dampers, on-board charger, DC/DC converter
    ("rear compartment", 80.0, (2.95, -0.60, 0.25), (3.65, 0.60, 0.70)),
    ("front seats", 36.0, (1.55, -0.63, 0.43), (2.10, 0.63, 1.00)),
    ("rear seat", 25.0, (2.45, -0.65, 0.40), (2.95, 0.65, 0.95)),
    ("instrument panel and HVAC", 45.0, (0.95, -0.68, 0.60), (1.40, 0.68, 1.05)),
    ("trim, carpet, headliner, restraints", 45.0, (1.00, -0.70, 0.30), (3.40, 0.70, 1.70)),
    ("wiring, high-voltage cables, sundries", 45.0, (0.50, -0.50, 0.25), (3.40, 0.50, 0.60)),
]

# Body in white, closures and glass spread over the exterior mesh by area:
# centroid, and second moments per kg about that centroid (kg m2 per kg).
# Measured by fit_body_shell.py from Models/followme.ac.
BODY_SHELL_CENTROID = (2.1963, 0.0040, 0.8629)
BODY_SHELL_INERTIA_PER_KG = (
    (0.5486, -0.0041, -0.1478),
    (-0.0041, 1.4658, -0.0004),
    (-0.1478, -0.0004, 1.4818),
)

# JSBSim point masses, in this order: pointmass-weight-lbs[0] and [1].
# The driver sits behind the steering wheel, eye at the cockpit view. The
# co-driver is the passenger model Models/followmeEV.xml shows on the rear
# right seat when "Enable co-driver model" is ticked.
OCCUPANTS = [
    ("Driver", 60.0, (1.85, -0.33, 0.70)),
    ("Co-driver", 60.0, (2.55, 0.33, 0.70)),
]


def _box_inertia(kg, lo, hi):
    dx, dy, dz = (h - l for l, h in zip(lo, hi))
    return ((kg * (dy * dy + dz * dz) / 12.0, 0.0, 0.0),
            (0.0, kg * (dx * dx + dz * dz) / 12.0, 0.0),
            (0.0, 0.0, kg * (dx * dx + dy * dy) / 12.0))


def body_shell_kg():
    return KERB_KG - sum(kg for _, kg, _, _ in COMPONENTS)


def parts(occupants=()):
    """[(name, kg, centre, inertia about own centre)] for the car and the given occupants.

    `occupants` is a list of (name, kg, centre) like OCCUPANTS.
    """
    shell_kg = body_shell_kg()
    out = [("body shell", shell_kg, BODY_SHELL_CENTROID,
            tuple(tuple(shell_kg * v for v in row) for row in BODY_SHELL_INERTIA_PER_KG))]
    for name, kg, lo, hi in COMPONENTS:
        centre = tuple((l + h) / 2.0 for l, h in zip(lo, hi))
        out.append((name, kg, centre, _box_inertia(kg, lo, hi)))
    zero = ((0.0, 0.0, 0.0),) * 3
    out.extend((name, kg, centre, zero) for name, kg, centre in occupants if kg > 0.0)
    return out


def combine(items):
    """Total mass, CG and inertia tensor about the CG of a list from parts()."""
    kg = sum(item[1] for item in items)
    cg = tuple(sum(item[1] * item[2][i] for item in items) / kg for i in range(3))
    inertia = [[0.0] * 3 for _ in range(3)]
    for _, m, centre, own in items:
        r = [centre[i] - cg[i] for i in range(3)]
        r2 = sum(v * v for v in r)
        for i in range(3):
            for j in range(3):
                inertia[i][j] += own[i][j] + m * ((r2 if i == j else 0.0) - r[i] * r[j])
    return kg, cg, inertia


def empty():
    return combine(parts())


def with_occupants(driver_kg=OCCUPANTS[0][1], codriver_kg=0.0):
    (driver, _, driver_at), (codriver, _, codriver_at) = OCCUPANTS
    return combine(parts([(driver, driver_kg, driver_at), (codriver, codriver_kg, codriver_at)]))


if __name__ == "__main__":
    print("%-40s %7s   %5s %6s %5s" % ("part", "kg", "x", "y", "z"))
    for name, kg, centre, _ in parts():
        print("%-40s %7.1f   %5.2f %+6.2f %5.2f" % ((name, kg) + tuple(centre)))
    for label, (kg, cg, inertia) in (("empty", empty()),
                                     ("with the driver", with_occupants()),
                                     ("with driver and co-driver", with_occupants(codriver_kg=60.0))):
        print("\n%s: %.0f kg, CG x %.3f y %+.3f z %.3f m" % ((label, kg) + tuple(cg)))
        print("  Ixx %.0f  Iyy %.0f  Izz %.0f kg m2" % (inertia[0][0], inertia[1][1], inertia[2][2]))
