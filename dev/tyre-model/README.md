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

Every parameter is a property and can be changed while driving, in the property browser under
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
| Combined | braking and cornering limits are independent | one friction circle per tyre |
| Surface | affects braking and cornering, not acceleration | affects everything |

`report.py` prints current numbers for both. As of this commit, on a dry road: 0-100 km/h in 3.8 s
for the standard FDM and 3.3 s for the tyre model; 100-0 km/h in 23 m for the standard FDM, 40 m for
the tyre model at 80 % pedal and 48 m with the wheels locked at full pedal.

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

## How it works

JSBSim keeps doing the suspension: the four `BOGEY` contacts still carry the car. Their friction
coefficients are zero and they are in no brake group, so JSBSim adds no force in the road plane.
`Systems/tyre-model.xml` supplies those forces instead, every FDM frame, per wheel:

1. **Load** from JSBSim's strut compression and compression speed.
2. **Contact patch velocity** from the body velocity and rotation rates, turned into the wheel's
   own axes by the steering angle.
3. **Slip**: slip ratio from wheel speed against road speed, slip angle from the sideways speed.
4. **Force**: one magic formula curve on the combined, normalised slip; the force points against
   the slip. The peak friction coefficient falls as the load rises (`load_sensitivity`) and scales
   with the surface under the car (FlightGear's material friction factor).
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
| `tyre/<wheel>/omega_rad_sec` | wheel speed |
| `tyre/<wheel>/slip_ratio` | -1 is a locked wheel, 0 free rolling, above 0 driving |
| `tyre/<wheel>/slip_tan` | tangent of the slip angle |
| `tyre/<wheel>/load_n`, `fx_n`, `fy_n` | load and tyre force, in the wheel's axes |
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
circle, the cornering limit and understeer, power oversteer by drive layout, holding and releasing
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

- The tyre parameters are estimates for a road tyre. Nothing is fitted to measured data.
- One curve shape for both directions; no relaxation length, camber, temperature or wear.
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
- The wheel animation and multiplayer still use road speed, so spinning and locked wheels do not
  show.
- "Magic bush tyres" (`reduceRollingFriction`) has no effect; the equivalent is
  `tyre/par/rolling_resistance`.
- The handbrake uses the rear service brakes, which are too weak to lock the rear wheels.
- No ABS or traction control. `brakesABS` in `Nasal/systems/brakes.nas` could now work from
  `tyre/<wheel>/slip_ratio`.
- The limo keeps the standard model.
