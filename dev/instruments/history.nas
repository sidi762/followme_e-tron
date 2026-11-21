# Run three separate FlightGear processes with the same fresh FG_HOME and aircraft.
# Use --prop:/nasal/historytest/file=Aircraft/followme_e-tron/dev/instruments/history.nas
# and --prop:/sim/test/dashboard-history=seed, restore, then empty (one value per run).
# Leave the standard aircraft-data load and save-on-exit settings enabled.
var stage = getprop("/sim/test/dashboard-history");
var near = func(label, actual, expected) {
	if (actual == nil or math.abs(actual - expected) > 0.001)
		die(label ~ ": expected " ~ expected ~ ", got " ~ actual);
};

# Seed distinct reset points so that a swapped or lost trip baseline changes the readings.
var seedHistory = func(panel, pack) {
	near("fresh odometer", panel.km, 0);
	near("fresh pack", pack.getRemainingInkWh(), 90);
	foreach (var reading; [["total", 5, 1], ["trip1", 10, 2], ["trip2", 20, 3]]) {
		var (counter, km, kWh) = reading;
		panel.km = km;
		panel.kWh = kWh;
		panel.seconds = km * 60;
		panel.resetCounter(counter);
	}
	panel.km = 25;
	panel.kWh = 5;
	panel.seconds = 1500;
	pack.setRemainingKWh(40);
};

var checkRestoredCounters = func(panel) {
	near("odometer", panel.km, 25);
	near("energy history", panel.kWh, 5);
	near("driving time", panel.seconds, 1500);
	near("trip 1 time", panel.seconds - panel.counters.trip1.seconds, 900);
	near("trip 1 distance", panel.km - panel.counters.trip1.km, 15);
	near("total average", panel.consumption("total"), 20);
	near("trip 1 average", panel.consumption("trip1"), 20);
	if (panel.consumption("sinceStart") != nil or panel.consumption("journey") != nil)
		die("new ignition inherited a journey");
};

var check = func {
	var panel = smartInstruments.smartInstruments;
	var pack = followme.cSource;
	if (stage == "seed") {
		seedHistory(panel, pack);
	} elsif (stage == "restore") {
		checkRestoredCounters(panel);
		near("partly charged pack", pack.getRemainingInkWh(), 40);
		near("trip 2 average", panel.consumption("trip2"), 40);
		panel.updatePage("range");
		if (panel.rangeKm.getText() != "200") die("range unavailable before moving");
		# The third process must distinguish these saved zeros from missing values.
		panel.resetCounter("trip2");
		pack.setRemainingKWh(0);
	} elsif (stage == "empty") {
		checkRestoredCounters(panel);
		near("empty pack", pack.getRemainingInkWh(), 0);
		if (panel.consumption("trip2") != nil) die("trip 2 reset was lost");
	} else {
		die("unknown test stage: " ~ stage);
	}
};

var started = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
	if (!n.getBoolValue() or started) return;
	started = 1;
	settimer(func {
		var errors = [];
		call(check, [], nil, nil, errors);
		if (size(errors)) print("HISTORYTEST FAILED ", stage, ": ", errors[0]);
		else print("HISTORYTEST DONE ", stage);
		fgcommand("exit", props.Node.new({status: size(errors) ? 1 : 0}));
	}, 1);
}, 1);

