# Run in an isolated FlightGear session with
# --prop:/nasal/paneltest/file=Aircraft/followme_e-tron/dev/instruments/restart.nas
var panel = nil;
var ignition = func { engine.toggleEngine(engine.engine_1); };

# Read the displayed Canvas properties independently of the controller's cache.
var checkLamps = func(expected = nil) {
    var lamps = panel.signGroup.getChildren();
    if (!panel.signGroup.getVisible() or size(lamps) != 11) die("missing instrument lamps");
    foreach (var lamp; lamps) {
        var id = lamp.get("id");
        var lit = expected == nil or contains(expected, id);
        if (lamp.getVisible() != lit) die("incorrect visibility for " ~ id);
    }
};

var steps = [
    [5, func {
        panel = smartInstruments.smartInstruments;
        followme.brakeController.disableHandBrake();
        setprop("/controls/lighting/headlight", 0);
        ignition();
        checkLamps();
    }],
    [2, func {
        checkLamps({ready_sign: 1});
        ignition();
        if (panel.signGroup.getVisible()) die("dashboard still lit after shutdown");
    }],
    [1, func { ignition(); checkLamps(); }],
    [2, func {
        checkLamps({ready_sign: 1});
        setprop("/controls/lighting/headlight", 2);
    }],
    [0.5, func {
        checkLamps({ready_sign: 1, positionlight_sign: 1, headlight_sign: 1});
        setprop("/controls/lighting/headlight", 0);
    }],
    [0.5, func { checkLamps({ready_sign: 1}); }],
];

var runStep = func(i) {
    settimer(func {
        var errors = [];
        call(steps[i][1], [], nil, nil, errors);
        if (size(errors)) {
            print("PANELTEST FAILED at step ", i, ": ", errors[0]);
        } elsif (i + 1 < size(steps)) {
            return runStep(i + 1);
        } else {
            print("PANELTEST DONE");
        }
        fgcommand("exit", props.Node.new({status: size(errors) ? 1 : 0}));
    }, steps[i][0]);
};

var begun = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
    if (n.getBoolValue() and !begun) {
        begun = 1;
        runStep(0);
    }
}, 1);
