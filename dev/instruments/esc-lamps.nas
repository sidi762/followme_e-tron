# Checks the ESC and ESC OFF lamps of the tyre model in a running FlightGear:
#   --aircraft=followme_e-tron-tyre --prop:/nasal/esclamps/file=<this file>
# Every result line starts with ESCLAMPS so it can be picked out of the log.

var say = func(msg) print("ESCLAMPS " ~ msg);
var dash = func smartInstruments.smartInstruments;
var lamps = func sprintf("esc %d off %d", dash().escSign.getVisible(), dash().escOffSign.getVisible());
var failures = 0;
var check = func(label, ok) {
	if (!ok) failures += 1;
	say(sprintf("%-44s %s | %s", label, ok ? "ok" : "FAILED", lamps()));
};

var flashed = 0;
var watch = maketimer(0.05, func { if (dash().escSign.getVisible()) flashed = 1; });

var steps = [
	[10, func engine.startEngine(engine.engine_1)],
	[0.3, func check("ignition self-test lights both", dash().escSign.getVisible() and dash().escOffSign.getVisible())],
	[4, func check("ready: both off", !dash().escSign.getVisible() and !dash().escOffSign.getVisible())],
	[0.1, func setprop("/fdm/jsbsim/tc/par/enabled", 0)],
	[0.5, func check("traction control off: ESC OFF lit", dash().escOffSign.getVisible())],
	[0.1, func { setprop("/fdm/jsbsim/tc/par/enabled", 1); setprop("/fdm/jsbsim/esc/par/enabled", 0); }],
	[0.5, func check("stability control off: ESC OFF lit", dash().escOffSign.getVisible())],
	[0.1, func setprop("/fdm/jsbsim/esc/par/enabled", 1)],
	[0.5, func check("both on again: ESC OFF out", !dash().escOffSign.getVisible())],
	[0.1, func { watch.start(); setprop("/controls/engines/engine/throttle", 1); }],
	[2.5, func { watch.stop(); setprop("/controls/engines/engine/throttle", 0);
				 check("full throttle start: ESC lamp flashed", flashed); }],
	[1.5, func check("after the start: ESC lamp out", !dash().escSign.getVisible())],
	[0.5, func { say(failures ? failures ~ " FAILED" : "ALL OK"); say("DONE"); fgcommand("exit"); }],
];

var run = func(i) {
	if (i >= size(steps)) return;
	settimer(func {
		var err = [];
		call(steps[i][1], [], nil, nil, err);
		if (size(err)) { failures += 1; say("STEP " ~ i ~ " FAILED: " ~ err[0]); }
		run(i + 1);
	}, steps[i][0]);
};

var begun = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
	if (n.getBoolValue() and !begun) {
		begun = 1;
		run(0);
	}
}, 1);
