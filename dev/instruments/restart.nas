# Run in an isolated FlightGear session with
# --prop:/nasal/paneltest/file=Aircraft/followme_e-tron/dev/instruments/restart.nas
var panel = nil;
var ignition = func { engine.toggleEngine(engine.engine_1); };

var checkPage = func(name) {
    if (panel.displayPage != name) die("expected " ~ name ~ ", got " ~ panel.displayPage);
    var files = smartInstruments.art;
    if (name == "off") {
        if (panel.infoImage.getVisible() or panel.signGroup.getVisible()) die("screen still lit");
    } else {
        var file = name == "doors" ? "doors/dashboard_Door.png" : "dashboard" ~ files[name] ~ ".png";
        if (!panel.infoImage.getVisible() or panel.infoImage.get("src") != smartInstruments.artDir ~ file)
            die("wrong image for " ~ name);
    }
};

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

var checkLiveScreenWithTestLamps = func {
    checkPage("range");
    if (!panel.gaugeGroup.getVisible() or panel.speedometer.getText() == "" or
        panel.batteryRemainingDisplay.getText() != followme.cSource.getRemainingPercentage())
        die("gauges not ready during the lamp test");
    checkLamps();
};

var steps = [
    [5, func {
        panel = smartInstruments.smartInstruments;
        checkPage("standby");
        followme.brakeController.disableHandBrake();
        setprop("/controls/lighting/headlight", 0);
        ignition();
        checkPage("selfTest");
        checkLamps();
    }],
    [1.25, checkLiveScreenWithTestLamps],
    [0.75, func {
        checkLamps({ready_sign: 1});
        checkPage("range");
        ignition();
        checkPage("summary");
        if (panel.signGroup.getVisible()) die("dashboard still lit after shutdown");
    }],
    [1, func { ignition(); checkLamps(); }],
    [1.25, func {
        checkLiveScreenWithTestLamps();
        ignition();
        checkPage("summary");
        ignition();
    }],
    [0.65, func { checkPage("selfTest"); checkLamps(); }],
    [0.6, checkLiveScreenWithTestLamps],
    [0.75, func {
        checkLamps({ready_sign: 1});
        setprop("/controls/lighting/headlight", 2);
    }],
    [0.5, func {
        checkLamps({ready_sign: 1, positionlight_sign: 1, headlight_sign: 1});
        setprop("/controls/lighting/headlight", 0);
    }],
    [0.5, func { checkLamps({ready_sign: 1}); }],
];

# Visit every normal page through the driver controls, including wraparound.
foreach (var name; ["total","sinceStart","trip1","trip2","media","navigation","assist","tyres","flow","compass","range"]) {
    (func(expected) {
        append(steps, [0.6, func {
            panel.pageKey(1);
            panel.pageKey(0);
            checkPage(expected);
        }]);
    })(name);
}

var more = [
    [0.5, func {
        panel.previousCenterScreen();
        checkPage("compass");
        followme.frontleft_door.open();
    }],
    [1.3, func {
        checkPage("doors");
        if (!panel.doorIcons[0].getVisible() or panel.doorIcons[1].getVisible()) die("wrong door highlight");
        panel.nextCenterScreen();
        followme.safety.aebActive();
    }],
    [1, func { checkPage("aeb"); followme.safety.aebStop(); }],
    [1, func { checkPage("doors"); followme.frontleft_door.close(); }],
    [1.3, func {
        checkPage("compass");
        panel.nextCenterScreen();
        checkPage("range");
        setprop("/controls/engines/engine/throttle", 0.65);
    }],
    [8, func {
        if (panel.km < 1 and panel.rangeKm.getText() != "--") die("premature range estimate");
        setprop("/controls/engines/engine/throttle", 0.08);
    }],
    [45, func {
        setprop("/controls/engines/engine/throttle", 0);
        if (panel.km < 1 or panel.kWh <= 0 or panel.rangeKm.getText() == "--") die("missing trip measurements");
        panel.nextCenterScreen();
        checkPage("total");
        panel.pageKey(1);
    }],
    [1.5, func {
        panel.pageKey(0);
        checkPage("total");
        if (panel.consumption("total") != nil or panel.consumption("sinceStart") == nil) die("counter reset leaked");
        ignition();
        checkPage("summary");
        if (panel.summaryRows[0].getText() != sprintf("%.1f km",panel.km)) die("incorrect trip distance");
    }],
    [1.5, func {
        followme.cSource.setRemainingFraction(0.46);
        setprop("/services/service-truck/connect",1);
        followme.chargeBatteryStart();
    }],
    [8, func {
        checkPage("charge");
        if (panel.gaugeGroup.getVisible() or panel.chargeStatus.getText() == "") die("wrong charging overlays");
        setprop("/services/service-truck/connect",0);
    }],
    [0.5, func {
        checkPage("off");
        ignition();
        checkPage("selfTest");
    }],
    [2, func {
        checkPage("total");
        checkLamps({ready_sign:1});
        if (panel.counters.sinceStart.km < 1 or panel.counters.sinceStart.km != panel.counters.journey.km)
            die("stale trip on restart");
    }],
];
steps = steps ~ more;

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
