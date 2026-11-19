# Tyre and driveline model (prototype)

An experimental variant of the Follow Me EV, `followme_e-tron-tyre`, whose wheels have their own
speed. They can spin and lock, grip is shared between cornering, braking and accelerating, and the
motor drives the car through the tyres instead of pushing the body.

It is a test bed for a tyre simulation that should later carry over to faster cars. It is plain
JSBSim XML: no C++ changes, and stock FlightGear loads it.

## Trying it

Start FlightGear with `--aircraft=followme_e-tron-tyre`, or pick "Follow Me e-tron (tyre model
prototype)" among the variants of the Follow Me EV in the launcher. Everything except the flight
model is the standard EV.

The scalar tuning parameters can be changed while driving, in the property browser under
`/fdm/jsbsim/tyre/par` and `/fdm/jsbsim/driveline/par`. For example
`driveline/par/front_torque_share` = 0 makes the car rear wheel drive.

## What differs from the standard FDM

| | Standard FDM | Tyre model |
|---|---|---|
| Drive | four equal body forces, whatever the grip | motor torque on the wheels, limited by the tyres |
| Drive update | by a Nasal timer: 10 Hz, or once per frame below 10 fps | every FDM frame (120 Hz) |
| Wheel speed | not a state: wheels cannot spin or lock | one state per wheel |
| Braking | pedal times 1.7 g on a dry road; wheels never lock | brake torque; too much locks the wheels |
| Cornering grip | fixed 1.0 g cap, same at any load | peaks, then falls; less per kg on a loaded tyre |
| Combined | braking and cornering limits are independent | one friction ellipse per tyre |
| Surface | affects braking and cornering, not acceleration | affects everything |

`report.py` prints current numbers for both. On flat dry ground at 120 Hz the standard FDM
reaches 100 km/h in 3.8 s and the tyre model in 3.3 s. The nominal 100 km/h stop takes about
23 m for the standard FDM. The tyre model takes 40.3 m at 80% pedal and 38.8 m at full pedal.
Independent front/rear inputs of 92%/82% give 37.1 m with both axles still rolling.

The standard FDM is slower off the line because `engine.nas` works out each update's torque from
the previous update's rpm, which lags while the rpm climbs. That also makes its acceleration depend
on the frame rate: at about 4 fps it took 4 s to reach 89 km/h.

## Files

| File | |
|---|---|
| `followme_e-tron-tyre-set.xml` | the variant; includes the standard `-set.xml`, changes only `<aero>` |
| `followme_e-tron-tyre.xml` | **generated** FDM: the standard one with wheel friction off and tyre forces in `<external_reactions>` |
| `Systems/tyre-model.xml` | **generated** JSBSim system: the model itself |
| `dev/tyre-model/generate.py` | the equations and parameters, and the generator for the two files above |
| `dev/tyre-model/fit_reference.py` | reproduces the force-curve fits from the published test archive |
| `dev/tyre-model/jsbexpr.py` | turns `a * max(b, c)` into JSBSim `<function>` XML |
| `dev/tyre-model/sim.py` | runs either FDM headless in JSBSim |
| `dev/tyre-model/test_tyre_model.py` | behaviour checks |
| `dev/tyre-model/report.py` | standard FDM against tyre model, as a table |
| `dev/tyre-model/fg/` | a scripted drive in a real, headless FlightGear |

To change the model, edit `generate.py` (or the standard FDM, which the wheel positions, mass and
strut constants are read from) and regenerate:

```bash
python3 dev/tyre-model/generate.py
```

## Tyre measurements

The dry force reference is KIT's anonymised **205/55 R17 91H summer tyre** on a 6.5-inch rim,
tested at 2.4 bar on dry AC11 asphalt. KIT publishes three vertical loads, repeated traction,
braking and cornering sweeps, and separate combined-slip tests. The fit uses the pure-slip
W-axis data with nominal zero camber. The commercial model and performance class are undisclosed.
The original measurements are by Philipp Bühler and colleagues (2025), licensed CC BY-NC-SA 4.0.
[KIT dataset and licence](https://doi.org/10.35097/p0rr2jc5wmf0drf8)

| Load per tyre | Drive peak, μ at slip | Brake peak, μ at slip magnitude | Lateral peak, μ at slip angle |
|---|---|---|---|
| 1,250 N | 1.153 at 18.0% | 1.141 at 20.5% | 1.137 at 10.4° |
| 4,000 N | 1.094 at 14.5% | 1.094 at 14.0% | 1.015 at 9.6° |
| 6,000 N | 1.050 at 8.5% | 1.073 at 10.5% | 0.960 at 10.4° |

Each peak and its slip are the mean of the two repeat peaks. Each lateral sweep is centred
on its interpolated zero-force angle before folding left and right turns together. With
normalised slip `s = slip / peak_slip` (using the tangent for angles), the fitted pure force
magnitude is `Fz * μ * sin(C * atan(tan(π / (2*C)) * abs(s)))`. A least-squares fit
sets C independently for each direction and load. RMS errors in force divided by load range
from 0.016 to 0.038 on the fitting samples. JSBSim interpolates the parameters between test
loads and holds their endpoint values outside that range. The full-lock response and large
sideways slides extrapolate beyond the available sweeps. Combined slip uses an ellipse.

The mean reported kinematic rolling radius in the four 4,000 N longitudinal runs is
0.31205 m. The rolling resistance uses a separate measured reference, 8.7 kg/t for a
225/40 R18 Michelin Pilot Sport 4 S. In that tyre's dry ABS test, 100 to 5 km/h took
33.74 m. This is a whole-vehicle benchmark. The wheel-plus-reflected-motor inertia of
2.1 kg·m² remains a vehicle estimate. [Tyre Reviews test and conditions](https://www.tyrereviews.com/Tyre-Tests/best-performance-summer-tyres-for-2025.htm)

To audit the fit, unpack the KIT download and pass its inner ZIP to the script in a Python
environment with NumPy and SciPy. It checks the shipped coefficients against the data.

```bash
python3 dev/tyre-model/fit_reference.py "/path/to/Determination of tire properties - Data.zip"
```

## How it works

JSBSim keeps doing the suspension: the four `BOGEY` contacts still carry the car. Their friction
coefficients are zero and they are in no brake group, so JSBSim adds no force in the road plane.
`Systems/tyre-model.xml` supplies those forces instead, every FDM frame, per wheel:

1. **Load** from JSBSim's strut compression and compression speed.
2. **Contact patch velocity** from the body velocity and rotation rates, turned into the wheel's
   own axes by the steering angle.
3. **Slip**: slip ratio from wheel speed against road speed, slip angle from the sideways speed.
4. **Force** uses fitted drive, brake and lateral curves evaluated at the combined normalised
   slip. Each wheel reads the last contact sample from its own
   `gear/unit[n]/static-friction-factor` and `rolling_friction-factor`. These include
   FlightGear's material and weather effects. The native lateral solver applies its own surface
   multiplier during the standstill handoff, so it receives the dry lateral coefficient.
5. **Wheel speed** from motor torque, brake torque and the tyre's own reaction.
6. The force goes back into JSBSim as two `<external_reactions>` forces at the contact patch.

The driveline is a motor with a torque limit and a power limit, a single gear, and open
differentials (equal torque to each wheel of an axle, `front_torque_share` between the axles).

Three things are less obvious:

- **The wheel speed update is implicit.** A free-rolling wheel reacts to slip far faster than
  120 Hz can follow, so an explicit integrator blows up. The update treats the tyre force as
  `stiffness * slip` with the stiffness taken from the curve, and brake plus rolling resistance as
  Coulomb friction that can hold the wheel at exactly zero. That is what a locked wheel is.
- **Low speed is softened.** Below `low_speed_mps` the slips are divided by that speed instead of
  the real one, otherwise the forces become stiffer than the FDM rate can integrate. 3 m/s suits
  120 Hz. The cost: under about 10 km/h the tyres respond more softly than they should.
- **Standstill is handed back to JSBSim.** A slip-based tyre makes no force without slip, so a
  parked car creeps. A wheel that is not turning and nearly stationary over the ground gets
  JSBSim's static friction switched back on (`stick` = 1), through the writable
  `gear/unit[n]/static_friction_coeff` and `rolling_friction_coeff`. As soon as it turns, the
  tyre model has it again.

## Properties

Under `/fdm/jsbsim/` in FlightGear.

Inputs, written by `Nasal/engine.nas`:

| Property | |
|---|---|
| `driveline/in/throttle_norm` | accelerator pedal, 0 to 1 |
| `driveline/in/direction` | 1 forward, -1 reverse |
| `driveline/in/motor_on` | 0: no drive, no coast regen, and a park lock below walking pace |

Brakes and steering need nothing new: the model reads `fcs/left-brake-cmd-norm` (front axle),
`fcs/right-brake-cmd-norm` (rear axle) and `fcs/steer-pos-deg`, which FlightGear already fills from
`/controls/gear/brake-left`, `brake-right`, `brake-parking` and the rudder.

Outputs worth knowing, per wheel `fl`, `fr`, `bl`, `br`:

| Property | |
|---|---|
| `tyre/<wheel>/omega_rad_sec` | signed wheel speed, sent to the exterior spin animation |
| `tyre/<wheel>/slip_power_w` | contact-patch sliding power, longitudinal and lateral combined |
| `tyre/<wheel>/smoke_norm` | visual smoke intensity after the grip peak, scaled from 3 to 33 kW of sliding power per wheel |
| `tyre/<wheel>/slip_ratio` | -1 is a locked wheel, 0 free rolling, above 0 driving |
| `tyre/<wheel>/slip_tan` | tangent of the slip angle |
| `tyre/<wheel>/load_n`, `fx_n`, `fy_n` | load and tyre force, in the wheel's axes |
| `tyre/<wheel>/mu_x`, `mu_y` | longitudinal and lateral peak coefficients after load and surface scaling |
| `tyre/<wheel>/locked`, `stick` | wheel not turning; wheel handed to JSBSim's static friction |
| `tyre/<wheel>/squeal` | 0 to 1, how far past the grip peak the tyre is sliding |
| `driveline/motor_rad_sec`, `driveline/motor_torque_nm` | motor speed and torque |

Parameters are listed with a comment each at the top of `Systems/tyre-model.xml`.

## Nasal

`Nasal/engine.nas` looks for `driveline/in/throttle_norm` when it loads. If it is there, the
engine passes pedal, direction and gear ratio to the FDM and reads the motor speed back, instead
of writing forces. `Nasal/steering.nas` skips turning the old drive forces when they do not exist.
With the standard or the limo FDM neither property exists and both scripts behave as before.

The pedal still reaches the FDM on the engine's 0.1 s timer, so it is up to 0.1 s late (one frame
at low frame rates). What the FDM does with it is no longer tied to that timer.

FlightGear resets the FDM's properties when it repositions the car, so the engine sends its whole
state on every update, and anything tuned by hand in the property browser is back at its default
after a reposition.

## Tests

```bash
pip install -r dev/tyre-model/requirements.txt
python3 -m pytest dev/tyre-model      # a few seconds
python3 dev/tyre-model/report.py
```

The tests run the generated FDM in standalone JSBSim on flat ground: launch on dry and slippery
surfaces, threshold braking against locked wheels, steering with locked wheels, the friction
ellipse, mixed surfaces, the cornering limit and understeer, power oversteer by drive layout, holding and releasing
on slopes, pulling away at full lock, and that results do not depend on the FDM rate (60 to
240 Hz). They do not start FlightGear and do not run any Nasal.

For that there is a scripted drive in a real FlightGear, rendered in software under Xvfb:

```bash
dev/tyre-model/fg/run.sh                                        # tyre model: start, accelerate, brake, turn, reverse
dev/tyre-model/fg/run.sh followme_e-tron                        # the same drive on the standard FDM
dev/tyre-model/fg/run.sh followme_e-tron-tyre reposition.nas    # reposition while moving
```

It prints what the car did and fails on a Nasal error. It has been run on FlightGear 2020.3.18
(Ubuntu 24.04 package) only. Nobody has driven the tyre model by hand yet.

## Limits

- Wet running uses FlightGear's surface multiplier on the dry curves. The prototype has no
  measured wet slip curves, relaxation length, camber, temperature or wear model.
- Forces act in the body's x-y plane, which is the road plane only as long as the car sits on its
  wheels.
- The wheel load is one frame old.
- Coast regen is a fixed motor torque so that lifting off slows the car as the standard FDM does;
  it does not charge the battery.
- On every reposition FlightGear 2020.3 prints "Property ... is already defined" once per
  parameter. JSBSim says that about any declared property that survives an FDM rebuild.

Not done yet:

- Tyre squeal: the sounds still listen to JSBSim's `side_friction_coeff`, which is now zero while
  moving. `tyre/<wheel>/squeal` is there for them.
- "Magic bush tyres" (`reduceRollingFriction`) has no effect; the equivalent is
  `tyre/par/rolling_resistance`.
- The handbrake uses the rear service brakes, which are too weak to lock the rear wheels.
- No ABS or traction control. `brakesABS` in `Nasal/systems/brakes.nas` could now work from
  `tyre/<wheel>/slip_ratio`.
- The limo keeps the standard model.
