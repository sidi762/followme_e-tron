# Scripted drive for a headless FlightGear run.
# Every result line starts with TYRETEST so it can be picked out of the log.

var say = func(msg) print("TYRETEST " ~ msg);
var num = func(path) {
	var v = getprop(path);
	return (v == nil or v == "") ? 0 : v;
};

var start = {lat: 0, lon: 0};
var metresFromStart = func() {
	var here = geo.aircraft_position();
	var there = geo.Coord.new().set_latlon(start.lat, start.lon, here.alt());
	return here.distance_to(there);
};

var snapshot = func(label) {
	say(sprintf("%-28s| t %6.1f | %6.1f km/h | u %6.2f m/s | rpma %7.0f | pedal>fdm %.2f | motor_on %.0f | motor %7.1f rad/s | brakes L %.2f R %.2f P %.2f | rudder %5.2f | hdg %6.1f | moved %7.2f m",
		label, num("/sim/time/elapsed-sec"), num("/velocities/groundspeed-kt") * 1.852,
		num("/fdm/jsbsim/velocities/u-fps") * 0.3048, num("/controls/engines/engine/rpma"),
		num("/fdm/jsbsim/driveline/in/throttle_norm"), num("/fdm/jsbsim/driveline/in/motor_on"),
		num("/fdm/jsbsim/driveline/motor_rad_sec"),
		num("/controls/gear/brake-left"), num("/controls/gear/brake-right"), num("/controls/gear/brake-parking"),
		num("/controls/flight/rudder"), num("/orientation/heading-deg"), metresFromStart()));
};

var wheels = func(label) {
	foreach (var w; ["fl", "fr", "bl", "br"]) {
		var base = "/fdm/jsbsim/tyre/" ~ w ~ "/";
		say(sprintf("  %s %s: load %6.0f N | omega %7.2f | slip %7.3f | tan(alpha) %7.3f | fx %7.0f N | fy %7.0f N | stick %.2f | locked %.0f | squeal %.2f",
			label, w, num(base ~ "load_n"), num(base ~ "omega_rad_sec"), num(base ~ "slip_ratio"),
			num(base ~ "slip_tan"), num(base ~ "fx_n"), num(base ~ "fy_n"), num(base ~ "stick"),
			num(base ~ "locked"), num(base ~ "squeal")));
	}
};

# [seconds to wait before the step, what to do]
var steps = [
	[10, func {
		start.lat = num("/position/latitude-deg");
		start.lon = num("/position/longitude-deg");
		say("aero = " ~ getprop("/sim/aero") ~ " | flight-model = " ~ getprop("/sim/flight-model")
			~ " | model-hz = " ~ num("/sim/model-hz") ~ " | fps = " ~ num("/sim/frame-rate")
			~ " | airport = " ~ getprop("/sim/presets/airport-id")
			~ " | tyre model present = " ~ (props.globals.getNode("/fdm/jsbsim/tyre/fl/load_n") != nil)
			~ " | engine.tyreModel = " ~ (engine.tyreModel != nil)
			~ " | surface friction factor = " ~ num("/fdm/jsbsim/ground/static-friction-factor")
			~ " | agl ft = " ~ num("/position/altitude-agl-ft"));
		snapshot("spawned, engine off");
		wheels("spawn");
	}],
	[20, func { snapshot("parked 20 s, engine off"); }],
	[0.5, func { engine.startEngine(engine.engine_1); }],
	[3, func { snapshot("engine started"); }],
	[10, func { snapshot("idle 10 s, no brakes"); wheels("idle"); }],
	[0.1, func { setprop("/controls/engines/engine/throttle", 1); }],
	[1, func { wheels("1 s full throttle"); }],
	[3, func { snapshot("4 s full throttle"); setprop("/controls/engines/engine/throttle", 0); }],
	[2, func { snapshot("2 s coasting"); followme.brakeController.keyboardBrake(); }],
	[0.5, func { wheels("braking 0.8"); }],
	[7.5, func { snapshot("8 s after brake 0.8"); followme.brakeController.keyboardBrakeRelease(); }],
	[1, func { setprop("/controls/engines/engine/throttle", 0.3); }],
	[4, func { snapshot("4 s at pedal 0.3"); setprop("/controls/flight/rudder", 0.2); }],
	[1.5, func { wheels("turning, rudder 0.2"); }],
	[2.5, func { snapshot("4 s turning, rudder 0.2");
				 setprop("/controls/flight/rudder", 0); setprop("/controls/engines/engine/throttle", 0);
				 followme.brakeController.applyFeetBrakes(1); }],
	[0.3, func { wheels("full brake"); }],
	[6, func { snapshot("after full brake"); followme.brakeController.applyFeetBrakes(0);
			   engine.engine_1.toggleDirection(); setprop("/controls/engines/engine/throttle", 0.3); }],
	[3, func { snapshot("3 s reverse, pedal 0.3"); setprop("/controls/engines/engine/throttle", 0);
			   followme.brakeController.applyFeetBrakes(1); }],
	[5, func { followme.brakeController.applyFeetBrakes(0); engine.engine_1.toggleDirection();
			   followme.brakeController.toggleHandBrake(); }],
	[3, func { snapshot("handbrake on"); engine.stopEngine(engine.engine_1); }],
	[3, func { snapshot("engine stopped"); wheels("stopped"); }],
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
