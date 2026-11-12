# Headless check: what happens to the tyre model when FlightGear rebuilds the FDM
# (reposition) while the car is moving, and with the engine off.

var say = func(msg) print("TYRETEST " ~ msg);
var num = func(path) {
	var v = getprop(path);
	return (v == nil or v == "") ? 0 : v;
};

var snapshot = func(label) {
	say(sprintf("%-34s| t %6.1f | fdm t %6.1f | %6.1f km/h | u %6.2f m/s | pedal>fdm %.2f | motor_on %.0f | omega fl %7.2f bl %7.2f | stick fl %.2f | running %d | agl %.2f ft",
		label, num("/sim/time/elapsed-sec"), num("/fdm/jsbsim/simulation/sim-time-sec"),
		num("/velocities/groundspeed-kt") * 1.852, num("/fdm/jsbsim/velocities/u-fps") * 0.3048,
		num("/fdm/jsbsim/driveline/in/throttle_norm"), num("/fdm/jsbsim/driveline/in/motor_on"),
		num("/fdm/jsbsim/tyre/fl/omega_rad_sec"), num("/fdm/jsbsim/tyre/bl/omega_rad_sec"),
		num("/fdm/jsbsim/tyre/fl/stick"), engine.engine_1.isRunning(), num("/position/altitude-agl-ft")));
};

var peak = 0;
var watch = maketimer(0, func {
	var s = math.abs(num("/fdm/jsbsim/velocities/u-fps")) * 0.3048;
	if (s > peak) peak = s;
});

var steps = [
	[10, func { snapshot("spawned"); engine.startEngine(engine.engine_1); }],
	[2, func { setprop("/controls/engines/engine/throttle", 1); }],
	[3, func { snapshot("3 s full throttle"); setprop("/controls/engines/engine/throttle", 0); }],
	[1, func { snapshot("pedal released"); say("REPOSITION while moving"); followme.resetOnPosition(); }],
	[0.5, func { peak = 0; watch.start(); }],
	[8, func { snapshot("8 s after reposition");
			   say(sprintf("peak speed since reposition %.3f m/s", peak)); watch.stop(); }],
	[0.1, func { setprop("/controls/engines/engine/throttle", 1); }],
	[3, func { snapshot("3 s full throttle again"); setprop("/controls/engines/engine/throttle", 0);
			   followme.brakeController.applyFeetBrakes(1); }],
	[6, func { followme.brakeController.applyFeetBrakes(0); engine.stopEngine(engine.engine_1);
			   snapshot("stopped, engine off"); }],
	[1, func { say("REPOSITION with the engine off"); followme.resetOnPosition(); }],
	[8, func { snapshot("8 s after reposition, engine off"); }],
	[0.5, func { say("DONE"); fgcommand("exit"); }],
];

var runStep = func(i) {
	if (i >= size(steps)) return;
	settimer(func {
		var err = [];
		call(steps[i][1], [], nil, nil, err);
		if (size(err)) say("STEP " ~ i ~ " FAILED: " ~ err[0]);
		runStep(i + 1);
	}, steps[i][0]);
};

var begun = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
	if (n.getBoolValue() and !begun) {
		begun = 1;
		say("fdm initialised");
		runStep(0);
	}
}, 1);
