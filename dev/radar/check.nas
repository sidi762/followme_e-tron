# Checks the parking radar and the AEB radar against AI models placed around the car,
# and times terrain probes for the radar rework. Start a session on flat ground with
# --prop:/nasal/radartest/file=Aircraft/followme_e-tron/dev/radar/check.nas
# Prints RADARTEST lines, then exits with status 1 if a check failed.
var failures = 0;
var parking = nil;
var front = nil;
var targets = [];

var report = func(line) { print("RADARTEST ", line); };

var expect = func(name, got, want, tolerance = 0.15) {
    var ok = (want == nil) ? got == 10000 : math.abs(got - want) <= tolerance;
    if (!ok) failures += 1;
    report(sprintf("%s %s: got %s, want %s", ok ? "ok  " : "FAIL", name,
        got == 10000 ? "clear" : sprintf("%.2f m", got), want == nil ? "clear" : sprintf("%.2f m", want)));
};

# One fresh reading, without waiting for the model list's own refresh
var reading = func(radar) {
    radar.multiplayerManager.nxtupdatetime = 0;
    radar.update();
    return radar.radarOutput;
};

var makeTarget = func(i) {
    var node = props.globals.getNode("/ai/models/radartest[" ~ i ~ "]", 1);
    node.setValues({position: {"latitude-deg": 0, "longitude-deg": 0, "altitude-ft": -10000}, valid: 1});
    return node;
};

# Puts a car-sized target `back` meters behind the front bumper (negative is ahead),
# `right` meters to the right, turned `turn` degrees from our heading
var place = func(node, back, right, turn = 0) {
    var heading = getprop("/orientation/heading-deg");
    var c = geo.aircraft_position();
    c.apply_course_distance(heading + 180, back);
    c.apply_course_distance(heading + 90, right);
    node.setValues({
        position: {"latitude-deg": c.lat(), "longitude-deg": c.lon(), "altitude-ft": c.alt() * M2FT},
        orientation: {"true-heading-deg": geo.normdeg(heading + turn)},
    });
};
var park = func(node) { place(node, -500, 0); };

var check = func(name, ok, detail = "") {
    if (!ok) failures += 1;
    report((ok ? "ok   " : "FAIL ") ~ name ~ (ok or detail == "" ? "" : ": " ~ detail));
};

# Records the radar sounds instead of playing them
var played = [];
var realPlayAudio = nil;
var recordAudio = func {
    played = [];
    if (realPlayAudio == nil) realPlayAudio = followme.playAudio;
    followme.playAudio = func(file, audioVolume = 1, audioPath = "", queue = "followme_fx") {
        append(played, file ~ " on " ~ queue);
    };
};
var stopRecordingAudio = func { if (realPlayAudio != nil) followme.playAudio = realPlayAudio; };
var powerState = func getprop("/systems/electrical/e-tron/power-state");
var reverse = func(wanted) { if ((engine.engine_1.getDirection() == -1) != wanted) engine.engine_1.toggleDirection(); };
var running = func(assist) {
    return assist.isRunning and assist.rear.isRunning and assist.front.isRunning and getprop("/systems/isParkingRadarActive");
};
var stopped = func(assist) {
    return !assist.isRunning and !assist.rear.isRunning and !assist.front.isRunning and !getprop("/systems/isParkingRadarActive");
};

# Check the actual Canvas paths by vehicle side, independently of sensor orientation.
var checkDisplay = func(frontText, rearText, lit) {
	var panel = smartInstruments.smartInstruments;
	check("display: radar page", panel.displayPage == "radar" and panel.details.radar.getVisible());
	check("display: front distance", panel.frontRadarDisplay.distanceText.getText() == frontText,
	      panel.frontRadarDisplay.distanceText.getText());
	check("display: rear distance", panel.rearRadarDisplay.distanceText.getText() == rearText,
	      panel.rearRadarDisplay.distanceText.getText());
	var visible = [];
	foreach (var bumper; ["front", "rear"])
		foreach (var side; ["left", "center", "right"])
			foreach (var band; ["near", "mid", "far"]) {
				var id = bumper ~ "-" ~ side ~ "-" ~ band;
				var arc = panel.details.radar.getElementById(id);
				if (arc.getVisible() and arc.get("fill") != nil) append(visible, id);
			}
	check("display: illuminated sectors", string.join(" ", visible) == lit, string.join(" ", visible));
};

# Rear bumper 3.8 m behind the front one, target half length 2.3 m, half width 0.95 m
var steps = [
    [5, func {
        parking = followme.parkingRadar;
        front = followme.safety.frontRadar;
        if (followme.safety.aebEnabled) followme.safety.disableAEB();
        # Present before the radar starts: the old model list never saw these
        append(targets, makeTarget(0));
        place(targets[0], 3.8 + 1.5 + 2.3, 0);
        if (parking.isRunning) parking.stop();
        parking.init();
        expect("rear: car aligned, 1.5 m behind", reading(parking), 1.5);
        place(targets[0], 3.8 + 2.0 + 0.95, 0, 90);
        expect("rear: car crossing, 2.0 m behind", reading(parking), 2.0);
        place(targets[0], 3.8 + 0.4 + 2.3, 0.5 + 0.95);
        expect("rear: car at the bumper corner, 0.4 m", reading(parking), 0.4);
        place(targets[0], 3.8 + 1.0 + 2.3, 3.5);
        expect("rear: car beside the sector", reading(parking), nil);
        place(targets[0], -3.0 - 2.3, 0);
        expect("rear: car ahead of us", reading(parking), nil);
    }],
    [0.5, func {
        # Added while the radar runs
        append(targets, makeTarget(1));
        place(targets[1], 3.8 + 1.0 + 2.3, 0);
        setprop("/ai/models/model-added", targets[1].getPath());
        expect("rear: car added while running, 1.0 m", reading(parking), 1.0);
        # FlightGear keeps a removed model's node but marks it invalid
        targets[1].setBoolValue("valid", 0);
        setprop("/ai/models/model-removed", targets[1].getPath());
        expect("rear: removed car is forgotten", reading(parking), nil);
    }],
    [0.5, func {
        front.initWithoutStarting();
        front.start();
        place(targets[0], -(8 + 2.3), 0);
        expect("aeb: car ahead, 8 m", reading(front), 8.0);
        place(targets[0], -(8 + 2.3), 2.0);
        expect("aeb: car beside the corridor", reading(front), nil);
        place(targets[0], 0, 0);
        expect("aeb: passenger model on our own position", reading(front), nil);
        # Stopping the AEB radar used to empty the parking radar's model list too
        place(targets[0], 3.8 + 1.5 + 2.3, 0);
        front.stop();
        expect("rear: still sees the car after the AEB radar stops", reading(parking), 1.5);
    }],
    [0.5, func {
        park(targets[0]);
        report(sprintf("body pitch at rest %.2f deg", getprop("/orientation/pitch-deg")));
        expect("rear: flat ground is clear", reading(parking), nil);
        front.start();
        expect("aeb: flat ground is clear", reading(front), nil);
        front.stop();
        parking.stop();
    }],
    [0.5, func {
        # Front parking radar: 1.2 m range, its own tone and queue
        var nose = followme.frontParkingRadar;
        recordAudio();
        nose.init(1);
        expect("front: flat ground is clear", reading(nose), nil);
        place(targets[0], -(0.8 + 2.3), 0);
        expect("front: car 0.8 m ahead", reading(nose), 0.8);
        check("front: beeps at once, front tone on its own queue",
            size(played) == 1 and played[0] == "parking_radar_high.wav on fx_radar_front", debug.string(played));
        place(targets[0], -(0.2 + 2.3), 0);
        reading(nose);
        check("front: repeats quickly under 0.3 m", nose.warningInterval == nose.continuousInterval,
            "interval " ~ nose.warningInterval);
        place(targets[0], -(1.5 + 2.3), 0);
        expect("front: car 1.5 m ahead is out of range", reading(nose), nil);
        place(targets[0], 3.8 + 0.5 + 2.3, 0);
        expect("front: car behind", reading(nose), nil);
        nose.stop();

        recordAudio();
        parking.init(1);
        place(targets[0], 3.8 + 1.5 + 2.3, 0);
        reading(parking);
        check("rear: beeps at once, rear tone every 0.5 s at 1.5 m",
            size(played) == 1 and played[0] == "parking_radar.wav on fx_radar" and math.abs(parking.warningInterval - 0.5) < 0.01,
            debug.string(played) ~ ", interval " ~ parking.warningInterval);
        place(targets[0], 3.8 + 0.3 + 2.3, 0);
        reading(parking);
        check("rear: continuous tone under 0.5 m", parking.warningSound == "parking_radar_long.wav", parking.warningSound);
        parking.stop();
        park(targets[0]);
        stopRecordingAudio();
    }],
    [0.5, func {
        var assist = followme.parkingAssist;
        assist.stop();
        reverse(0);
        report("drive system: " ~ powerState());
        reverse(1);
        check("assist: reverse with the drive system off leaves it off", stopped(assist));
        reverse(0);
        engine.toggleEngine(engine.engine_1);
    }],
    [8, func {
        var assist = followme.parkingAssist;
        check("drive system is ready after starting", powerState() == "ready", powerState());
        smartInstruments.smartInstruments.previousCenterScreen();
        reverse(1);
        check("assist: reverse turns front and rear on, with the cockpit lamp", running(assist));
        checkDisplay("--", "--", "");
        smartInstruments.smartInstruments.nextCenterScreen();
        place(targets[0], -(2.3 + 0.2), -1.55);
        place(targets[1], 3.8 + 2.3 + 1.3, 1.55);
        targets[1].setBoolValue("valid", 1);
        setprop("/ai/models/model-added", targets[1].getPath());
    }],
    [1.4, func {
        checkDisplay("0.2 m", "1.3 m", "front-left-near rear-right-mid");
        place(targets[0], -(2.3 + 1.0), 1.55);
        place(targets[1], 3.8 + 2.3 + 0.3, 0);
    }],
    [1.4, func {
        checkDisplay("1.0 m", "0.3 m", "front-right-far rear-left-near rear-center-near rear-right-near");
        # Two echoes at one bumper must survive, even when the closer one occupies only one side.
        place(targets[1], -(2.3 + 0.5), -1.55);
    }],
    [1.4, func {
        checkDisplay("0.5 m", "--", "front-left-mid front-right-far");
        park(targets[0]);
        place(targets[1], -2.25, 0);
    }],
    [1.4, func {
        checkDisplay("0.0 m", "--", "front-left-near front-center-near front-right-near");
        park(targets[1]);
    }],
    [1.4, func {
        checkDisplay("--", "--", "");
        var panel = smartInstruments.smartInstruments;
        followme.frontleft_door.setpos(1);
        panel.update();
        check("display: open door overrides the radar", panel.displayPage == "doors");
        followme.frontleft_door.setpos(0);
        panel.update();
        check("display: radar resumes when the door closes", panel.displayPage == "radar");
        followme.safety.aebActive();
        check("display: AEB overrides the radar", panel.displayPage == "aeb");
        followme.safety.aebStop();
        check("display: radar resumes after AEB", panel.displayPage == "radar");
        var assist = followme.parkingAssist;
        reverse(0);
        assist.watchSpeed();
        check("assist: stays on when pulling forwards slowly", running(assist));
        assist.speedKMH = func 20;
        assist.watchSpeed();
        delete(assist, "speedKMH");
        check("assist: goes off above 15 km/h forwards", stopped(assist));
        check("display: returns to selected compass page", panel.displayPage == "compass");
        followme.toggleParkingRadar();
        check("assist: the switch turns it back on", running(assist));
        checkDisplay("--", "--", "");
        engine.toggleEngine(engine.engine_1);
        check("assist: shutting the drive system down turns it off", stopped(assist), powerState());
        check("display: shutdown takes down the radar page", panel.displayPage == "summary");
        reverse(1);
        engine.toggleEngine(engine.engine_1);
    }],
    [8, func {
        var assist = followme.parkingAssist;
        check("assist: powering up in reverse turns it on", running(assist), powerState());
        checkDisplay("--", "--", "");
        assist.stop();
        check("display: previous page survives restart", smartInstruments.smartInstruments.displayPage == "compass");
        reverse(0);
        engine.toggleEngine(engine.engine_1);
    }],
    [0.5, func {
        # Costs on this scenery: the current vertical probes against horizontal rays
        var heading = getprop("/orientation/heading-deg");
        var bumper = geo.aircraft_position();
        bumper.apply_course_distance(heading + 180, 3.8);
        bumper.set_alt(bumper.alt() + 0.3);
        var n = 200;
        var t = systime();
        for (var i = 0; i < n; i += 1) {
            var p = geo.Coord.new(bumper);
            p.apply_course_distance(heading + 180, 0.01 * i);
            geo.elevation(p.lat(), p.lon());
        }
        var elevationUs = (systime() - t) / n * 1e6;

        var ray = func(downDeg, sideDeg) {
            var target = geo.Coord.new(bumper);
            target.apply_course_distance(heading + 180 + sideDeg, math.cos(downDeg * D2R));
            target.set_alt(bumper.alt() - math.sin(downDeg * D2R));
            return get_cart_ground_intersection({x: bumper.x(), y: bumper.y(), z: bumper.z()},
                {x: target.x() - bumper.x(), y: target.y() - bumper.y(), z: target.z() - bumper.z()});
        };
        t = systime();
        for (var i = 0; i < n; i += 1) ray(0, i * 0.1 - 10);
        var levelUs = (systime() - t) / n * 1e6;
        t = systime();
        for (var i = 0; i < n; i += 1) ray(8, i * 0.1 - 10);
        var downUs = (systime() - t) / n * 1e6;

        var hit = ray(8, 0);
        var hitM = "no hit";
        if (typeof(hit) == "hash" and contains(hit, "lat") and contains(hit, "lon")) {
            var h = geo.Coord.new().set_latlon(hit.lat, hit.lon);
            hitM = sprintf("%.2f m (flat ground: %.2f m)", bumper.distance_to(h), 0.3 / math.tan(8 * D2R));
        } elsif (typeof(hit) == "hash") {
            hitM = "a result with keys " ~ string.join(", ", keys(hit));
        }
        report(sprintf("cost: geo.elevation %.0f us, level ray %.0f us, ray 8 deg down %.0f us", elevationUs, levelUs, downUs));
        report("ray 8 deg down from 0.3 m hits the ground at " ~ hitM);

        t = systime();
        for (var i = 0; i < 20; i += 1) reading(parking);
        report(sprintf("cost: one clear parking radar scan %.2f ms", (systime() - t) / 20 * 1000));
        parking.stop();
    }],
];

var finish = func(errors) {
    stopRecordingAudio();
    foreach (var node; targets) node.remove();
    if (size(errors)) {
        failures += 1;
        report("FAIL Nasal error: " ~ errors[0]);
    }
    report(failures ? sprintf("FAILED %d", failures) : "DONE");
    fgcommand("exit", props.Node.new({status: failures ? 1 : 0}));
};

var runStep = func(i) {
    settimer(func {
        var errors = [];
        call(steps[i][1], [], nil, nil, errors);
        if (size(errors) or i + 1 >= size(steps)) return finish(errors);
        runStep(i + 1);
    }, steps[i][0]);
};

var begun = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
    if (n.getBoolValue() and !begun) {
        begun = 1;
        runStep(0);
    }
}, 1);
