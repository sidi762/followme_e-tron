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
| Braking | pedal times 1.7 g on a dry road; wheels never lock | brake torque per wheel; ABS keeps the wheels from locking |
| Cornering grip | fixed 1.0 g cap, same at any load | peaks, then falls; less per kg on a loaded tyre |
| Combined | braking and cornering limits are independent | one friction ellipse per tyre |
| Surface | affects braking and cornering, not acceleration | affects everything |
| Mass | 1575 kg, 67% on the front wheels, yaw inertia 16,200 kg·m² | 1575 kg from components plus a 60 kg driver: 52% front, yaw inertia 1,830 kg·m² |

`report.py` prints current numbers for both. On flat dry ground at 120 Hz the standard FDM
reaches 100 km/h in 3.8 s and the tyre model in 3.5 s. The nominal 100 km/h stop takes about
23 m for the standard FDM. The tyre model takes 38.8 m at 80% pedal and 36.9 m at full pedal with
ABS. Without ABS full pedal locks all four wheels and takes 38.0 m, and the best hand-found split of
the pedals, 83% front and 90% rear, takes 37.0 m.

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
| `dev/tyre-model/mass.py` | mass, CG and inertia built up from components |
| `dev/tyre-model/fit_body_shell.py` | measures the body shell in the 3D model for `mass.py` |
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

## Mass and occupants

The standard FDM puts its 1575 kg 0.82 m behind the front axle, 67% on the front wheels, and gives
it moments of inertia several times those of a car this size. The variant keeps the 1575 kg but
builds the CG and inertia up from components in `mass.py`, each placed where the 3D model puts it:

- a 545 kg battery for the 90 kWh in `Nasal/electrical.nas`, under the floor between the arches
- one drive unit on the front axle (motor, inverter, reduction gear, centre differential), a
  propeller shaft and a rear differential, matching the single-motor driveline
- 40 kg unsprung per corner, the front and rear compartments, seats, instrument panel and trim
- the body shell, which takes the remaining 329 kg spread over the exterior mesh by area

| | Mass | Front axle share | CG height | Ixx / Iyy / Izz |
|---|---|---|---|---|
| Standard FDM | 1575 kg | 67% | about 0.37 m | 7,587 / 7,232 / 16,195 kg·m² |
| Tyre variant with the default driver | 1635 kg | 52% | about 0.46 m | 515 / 1,756 / 1,830 kg·m² |

The component masses are estimates for a car of this kind, not measurements. The battery sits
almost exactly at the CG, so the split hardly depends on them; its weight mostly moves the CG
height. `python3 dev/tyre-model/mass.py` prints the table. The products of inertia are small and
left out.

Two JSBSim point masses carry the occupants: the driver behind the steering wheel, and the
co-driver on the rear right seat, where `Models/followmeEV.xml` shows the co-driver model. Their
weights are FlightGear properties outside the FDM, so they survive a reposition:
`/systems/occupants/driver-kg` (60 kg, or 50/60/75/90 kg under Vehicle Configuration) and
`/systems/occupants/codriver-kg` (60 kg), which counts while "Enable co-driver model" is ticked.
The FDM applies them on every frame, and the tyre model takes the wheel positions from the live CG.

The rear brakes follow the CG. `rear_brake_nm()` in `generate.py` sizes them so that, on equal grip,
the front axle reaches its limit first at any deceleration up to 1.15 g. With the CG near the
middle that is 836 N·m per rear wheel instead of 580.

The centre differential stays at 50:50. With the weight further back, a full-throttle start on dry
asphalt now slips the front tyres past their peak. A rear bias hooks up on dry but spins the rear
first on a slippery road, and with the lower yaw inertia the car then turns round. Traction control
is meant to deal with both.

To audit the body shell against the 3D model (needs NumPy):

```bash
python3 dev/tyre-model/fit_body_shell.py
```

## ABS

The `ABS` channel sits between the `Brakes` channel and the wheels. Like a real controller it
works one frame behind: it reads the slip each tyre channel computed in the previous frame and
sets each wheel's hydraulic torque for this one. It controls only the service brakes; the
handbrake lever and the parking clamp bypass it.

- **What it watches.** Each wheel's braking slip divided by the tyre's measured peak braking slip
  at its present load (`abs_slip`, 20.5% / 14% / 10.5% at 1,250 / 4,000 / 6,000 N). A real
  controller estimates the car's speed from the wheels and an accelerometer; this one takes the
  true speed of each contact patch.
- **What it can do.** Each wheel's valves release, hold or rebuild pressure, and never give more
  than the request. Past the peak (`dump_slip`) and still slipping more, it releases, falling
  exponentially at `dump_rate`. Once the wheel recovers, it holds. Below `rebuild_slip` it builds
  back up in a slow ramp (`build_rate`). One cycle on dry asphalt takes about a third of a second.
- **Front and rear.** The front wheels are controlled one by one. The rear pair follows whichever
  rear wheel needs less ("select low"), so on split grip the rear axle adds no yaw. While one front
  wheel is under ABS, the other may brake only a little harder at first (`yaw_delay_start`), and
  that margin grows at `yaw_delay_rate`. So split grip turns the car gradually and the driver has
  time to steer against it.
- **When.** It engages when a wheel first needs releasing and lets go when the request goes, when
  the pressure is back up to the request, or below `min_speed_mps` (9 km/h), where it lets the
  wheels lock as real systems do. Ordinary braking never reaches it. Coast regen drops out while
  it works, because the motor brakes the wheels outside its control.

Its parameters are under `/fdm/jsbsim/abs/par`; `abs/par/enabled` = 0 switches it off.

| Full pedal from 100 km/h | Without ABS | With ABS |
|---|---|---|
| Dry | 38.0 m, all four locked | 36.9 m, rolling |
| Grip x0.6 | 62.9 m | 60.2 m |
| Grip x0.3 | 123.1 m | 118.0 m |
| Dry, 6.75° of steering | turns at 3.8°/s | turns at 19.4°/s |

The distances differ less than on a real car because the fitted tyre curves keep about 94% of
their peak grip at full lock. What ABS changes most here is that the car still steers. On split
grip (80 km/h, left wheels on asphalt, right on ice) a driver holding the heading keeps it within
4° with ABS. Without ABS the locked wheels cannot steer and the car turns 88°.

## How it works

JSBSim keeps doing the suspension: the four `BOGEY` contacts still carry the car. Their friction
coefficients are zero and they are in no brake group, so JSBSim adds no force in the road plane.
`Systems/tyre-model.xml` supplies those forces instead, every FDM frame, per wheel:

1. **Load** from JSBSim's strut compression and compression speed.
2. **Contact patch velocity** from the body velocity and rotation rates about the current CG,
   turned into the wheel's own axes by the steering angle.
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

Each wheel has its own brake. The `Brakes` channel combines the braking intents, which arrive
separately (see Properties), into a service brake demand per axle and a mechanical torque on the
rear wheels:

- **Service brakes**, hydraulic, all four wheels: the pedal of that axle, automatic braking (AEB
  and cruise control) and Auto Hold, whichever asks for most. Each wheel turns the demand into
  `brake_request_nm`, and the ABS channel passes on as much of it as the wheel can take as
  `service_brake_nm` (see ABS above). Stability control will add its own requests there later.
- **Handbrake lever** (held with `b`): the rear wheels only, mechanically, past the hydraulics.
  `handbrake_nm` locks them while driving. Held on a straight at speed, the locked rear wheels let
  the car swing round.
- **Electric parking brake** (`B`): at a standstill it clamps the rear wheels with `parking_nm`.
  Switched on above `epb_dynamic_mps` it brakes all four wheels hydraulically at
  `epb_dynamic_norm` instead, as real ones do, and clamps once the car has stopped.

The park lock (motor off) and rolling resistance add to each wheel's total `brake_torque_nm`.

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

Steering needs nothing new: the model reads `fcs/steer-pos-deg`, which FlightGear fills from the
rudder.

The brakes and the occupants are read from FlightGear properties outside `/fdm/jsbsim/`. The brakes
skip FlightGear's own brake commands for JSBSim, which fold the parking brake into both axles.
`Nasal/systems/brakes.nas` publishes the automatic intents.

| Property | |
|---|---|
| `/controls/gear/brake-left` | front axle pedal, 0 to 1 (joystick axis, or both with the S key) |
| `/controls/gear/brake-right` | rear axle pedal |
| `/systems/BrakeController/automatic-norm` | AEB and cruise control braking |
| `/systems/BrakeController/hold-norm` | Auto Hold at a standstill |
| `/systems/BrakeController/handbrake-norm` | 1 while the handbrake lever is held |
| `/controls/gear/brake-parking` | electric parking brake, after its half-second actuator |
| `/systems/occupants/driver-kg` | driver weight, 60 kg by default |
| `/systems/occupants/codriver-kg` | co-driver weight on the rear right seat, 60 kg by default |
| `/systems/codriver-enable` | 1 while "Enable co-driver model" is ticked; the co-driver counts only then |

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
| `tyre/<wheel>/brake_request_nm`, `service_brake_nm` | hydraulic brake torque asked for and applied |
| `tyre/<wheel>/brake_torque_nm` | all of it: service, mechanical, park lock, rolling resistance |
| `brakes/service_front`, `service_rear` | service brake demand per axle, 0 to 1 |
| `brakes/mechanical_rear_nm` | handbrake lever or parking clamp on each rear wheel |
| `abs/active`, `tyre/<wheel>/abs_active` | ABS working on any wheel, on this wheel |
| `tyre/<wheel>/abs_mode` | -1 releasing, 0 holding, 1 rebuilding |
| `tyre/<wheel>/abs_slip` | braking slip over the tyre's peak braking slip at its load |
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

The tests run the generated FDM in standalone JSBSim on flat ground: wheel loads and occupant
weights, launch on dry and slippery surfaces, threshold braking against locked wheels, steering
with locked wheels, the friction ellipse, mixed surfaces, the cornering limit and understeer, power
oversteer by drive layout, holding and releasing on slopes, pulling away at full lock, each
wheel's brake request, ABS on dry, wet and icy roads, while steering and on split grip, the
handbrake lever, the parking brake at rest and while moving, Auto
Hold, and that results do not depend on the FDM rate (60 to 240 Hz). They do not start FlightGear
and do not run any Nasal.

For that there is a scripted drive in a real FlightGear, rendered in software under Xvfb:

```bash
dev/tyre-model/fg/run.sh                                        # tyre model: start, accelerate, brake, turn, reverse
dev/tyre-model/fg/run.sh followme_e-tron                        # the same drive on the standard FDM
dev/tyre-model/fg/run.sh followme_e-tron-tyre reposition.nas    # reposition while moving
```

It prints what the car did and fails on a Nasal error. It has been run on FlightGear 2020.3.18
(Ubuntu 24.04 package) only. The occupant weights, the driver weight buttons and each braking
intent (S key, handbrake lever, parking brake at rest and moving, Auto Hold) and ABS on a full
stop from 98 km/h (37.5 m, no wheel locked) have also been
checked in FlightGear 2024.1.8 on macOS, including after a reposition. Nobody has driven the tyre
model by hand yet.

## Limits

- Wet running uses FlightGear's surface multiplier on the dry curves. The prototype has no
  measured wet slip curves, relaxation length, camber, temperature or wear model.
- Forces act in the body's x-y plane, which is the road plane only as long as the car sits on its
  wheels.
- The wheel load is one frame old.
- A locked tyre's force points about 2° off its sliding direction, because the friction ellipse
  normalises the two slips by different peak slips. Braking on locked wheels (ABS off) with 6.75° of
  steering still turns the car at about 4°/s.
- A full-throttle start on dry asphalt slips the front tyres past their peak (see Mass and
  occupants).
- Coast regen is a fixed motor torque so that lifting off slows the car as the standard FDM does;
  it does not charge the battery.
- On every reposition FlightGear 2020.3 prints "Property ... is already defined" once per
  parameter. JSBSim says that about any declared property that survives an FDM rebuild.

Not done yet:

- Tyre squeal: the sounds still listen to JSBSim's `side_friction_coeff`, which is now zero while
  moving. `tyre/<wheel>/squeal` is there for them.
- "Magic bush tyres" (`reduceRollingFriction`) has no effect; the equivalent is
  `tyre/par/rolling_resistance`.
- No traction control or stability control. They are planned inside the FDM, acting on the motor
  torque and on each wheel's brake request. `brakesABS` in `Nasal/systems/brakes.nas` is not used.
- Outside ABS the hydraulic brakes apply the request at once; there is no pressure build-up time.
- ABS has no warning lamp, sound or pedal feel yet.
- The limo keeps the standard model.
