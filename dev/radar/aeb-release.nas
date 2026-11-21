# Run on a flat runway in an isolated FlightGear session with
# --prop:/nasal/aebtest/file=Aircraft/followme_e-tron/dev/radar/aeb-release.nas
# Only the obstacle distance is scripted. The radar clock, pedals, AEB and FDM run normally.
var safety = nil;
var brakes = nil;
var panel = nil;
var obstacle = nil;
var scansAtClear = 0;
var simTime = func { return getprop("/fdm/jsbsim/simulation/sim-time-sec"); };
var holdBegan = 0;
var watchAutoHold = 0;
var pressureGap = 0;
var pedalTravel = func { return getprop("/sim/multiplay/generic/float[37]"); };
var speed = func { return followme.vInfo.getSpeedKMH(); };
var throttle = func(value) { setprop("/controls/engines/engine/throttle", value); };
var leftBrake = func { return getprop("/fdm/jsbsim/fcs/left-brake-cmd-norm"); };
var rightBrake = func { return getprop("/fdm/jsbsim/fcs/right-brake-cmd-norm"); };
var expect = func(condition, message) { if (!condition) die(message); };

var steps = [
	["first approach", func { return speed() > 45; }, func { obstacle = 4; }],
	["acknowledge", func { return safety.aebActivated; }, func {
		expect(panel.displayPage == "aeb", "initial warning missing");
		expect(pedalTravel() == 1 and !brakes.applyingFeetBrake, "AEB must move the pedal without driver input");
		brakes.keyboardBrake();
		brakes.keyboardBrakeRelease();
		expect(panel.displayPage != "aeb" and safety.aebActivated, "wrong pedal acknowledgement");
	}],
	["clear below activation speed", func { return speed() <= 28; }, func {
		expect(safety.aebActivated and leftBrake() > 0.99, "lost braking with obstacle present");
		scansAtClear = safety.frontRadar.scanCount;
		obstacle = nil;
	}],
	["low-speed release", func { return !safety.aebActivated; }, func {
		expect(safety.frontRadar.scanCount >= scansAtClear + 3, "radar stopped before confirming clearance");
		expect(!getprop("/autopilot/autobrake/engaged"), "automatic brake still engaged");
	}],
	["first roll-away", func { return leftBrake() == 0 and rightBrake() == 0; }, func { throttle(0.65); }],
];

# Run the same stop with three different owners of the brake after the two seconds.
var addStop = func(label, driverPressure, useAutoHold) {
	var handoffPressure = useAutoHold ? 1 : driverPressure;
	var scenario = [
		[label ~ " approach", func { return speed() > 45; }, func {
			if (useAutoHold) autohold.startAutoHold();
			obstacle = 4;
		}],
		[label ~ " warning", func { return safety.aebActivated; }, func {
			expect(panel.displayPage == "aeb", "next hazard did not rearm");
			brakes.applyFeetBrakes(driverPressure);
			expect(pedalTravel() == 1, "pedal did not follow full AEB");
		}],
		[label ~ " standstill", func { return !safety.aebActivated; }, func {
			expect(speed() <= 0.5 and safety.aebHoldTimer.isRunning, "missing standstill hold");
			holdBegan = simTime();
			watchAutoHold = useAutoHold;
			pressureGap = 0;
			obstacle = nil;
		}],
		[label ~ " retaining pressure", func { return simTime() - holdBegan >= 1.75; }, func {
			expect(leftBrake() == 1 and rightBrake() == 1 and pedalTravel() == 1, "released before handoff");
			expect(!autohold.working and !brakes.handBrakeIsOn(), "premature handoff or parking brake");
		}],
		[label ~ " handoff", func { return brakes.aebDemand == 0; }, func {
			var duration = simTime() - holdBegan;
			expect(duration >= 1.9 and duration <= 2.2, "hold duration: " ~ duration);
			expect(autohold.working == useAutoHold and !pressureGap, "Auto Hold takeover failed");
			expect(math.abs(pedalTravel() - driverPressure) < 0.001, "pedal did not return to driver input");
			expect(!getprop("/controls/gear/brake-parking") and !panel.handBrakeSign.getVisible(), "parking brake applied");
			watchAutoHold = 0;
			print("AEBRELEASE ", label, " held ", duration, " s; pedal=", pedalTravel());
		}],
		[label ~ " wheel brakes", func {
			return leftBrake() == handoffPressure and rightBrake() == handoffPressure;
		}, func {
			brakes.applyFeetBrakes(0);
			throttle(0.65);
		}],
		[label ~ " drives again", func { return speed() > 8; }, func {
			expect(leftBrake() == 0 and rightBrake() == 0 and pedalTravel() == 0, "brakes did not return");
			if (useAutoHold) autohold.stopAutoHold();
		}],
	];
	steps = steps ~ scenario;
};
addStop("free pedal", 0, 0);
addStop("driver", 0.25, 0);
addStop("Auto Hold", 0, 1);

var index = 0;
var deadline = 0;
var tick = func {
	var errors = [];
	call(func {
		if (steps[index][1]()) {
			steps[index][2]();
			print("AEBRELEASE ", steps[index][0], " speed=", speed());
			index += 1;
			deadline = systime() + 15;
		} elsif (systime() > deadline) die("timeout: " ~ steps[index][0]);
	}, [], nil, nil, errors);
	if (size(errors)) {
		print("AEBRELEASE FAILED ", errors[0], " speed=", speed(), " AEB=", safety.aebActivated,
		      " radar=", safety.frontRadar.isRunning, " pedal=", brakes.applyingFeetBrake,
		      " FDM=", leftBrake(), "/", rightBrake(), " park=", getprop("/controls/gear/brake-parking"));
	} elsif (index < size(steps)) {
		return settimer(tick, 0.02);
	} else print("AEBRELEASE DONE");
	fgcommand("exit", props.Node.new({status: size(errors) ? 1 : 0}));
};

setlistener("/sim/signals/fdm-initialized", func(n) {
	if (!n.getBoolValue() or safety != nil) return;
	safety = followme.safety;
	brakes = followme.brakeController;
	panel = smartInstruments.smartInstruments;
	setlistener(brakes.frontBrakeOutput, func(node) {
		if (watchAutoHold and node.getValue() < 0.99) pressureGap = 1;
	});
	safety.frontRadar.scan = func { return obstacle; };
	settimer(func {
		brakes.disableHandBrake();
		engine.toggleEngine(engine.engine_1);
		safety.enableAEB();
		throttle(0.65);
		deadline = systime() + 20;
		tick();
	}, 3);
}, 1);
