# Run with dev/tyre-model/fg/run.sh followme_e-tron-tyre electrical.nas.
var near = func(label, actual, expected, tolerance = 1e-7) {
    if (actual == nil or math.abs(actual - expected) > tolerance)
        die(label ~ ": got " ~ actual ~ ", expected " ~ expected);
};

var checkElectrical = func {
    var hv = followme.cSource;
    var lv = followme.cSource_small;
    var bus = followme.circuit_1;
    var aux = followme.circuit_low;
    near("independent branches", bus.parallelConnection == aux.parallelConnection, 0);
    near("independent components", bus.parallelConnection[0].units == aux.parallelConnection[0].units, 0);

    # A lossless 90 kW load takes exactly 1.5 kWh in one simulated minute.
    var pack = followme.VoltageSource.new(0, 405, followme.kWh2kWs(90));
    var testBus = followme.Circuit.new(pack);
    var load = followme.Appliance.new();
    load.isPowerLoad = 1;
    load.activePower_kW = 90;
    testBus.addUnitToSeries(0, load);
    foreach (var dt; [0.03, 4.97, 15, 40]) testBus.update(dt);
    near("irregular time steps", pack.getRemainingInkWh(), 88.5);
    testBus.update(0);
    near("zero elapsed time", pack.getRemainingInkWh(), 88.5);
    pack.resetRemainingToFull();
    testBus.update(60);
    near("one time step", pack.getRemainingInkWh(), 88.5);
    pack.setRemainingKWh(0.001);
    testBus.update(60);
    near("discharge clamps at empty", pack.getRemainingInkWh(), 0);
    pack.voltageSourceUpdate(-90000, 60);
    near("no regenerative charging", pack.getRemainingInkWh(), 0);
    var before = lv.getRemainingInkWh();
    aux.update(60);
    near("unloaded 12 V current", aux.current, 0);
    near("12 V charge", lv.getRemainingInkWh(), before);

    var hvBefore = hv.getRemainingInkWh();
    setprop("/controls/lighting/headlight", 1);
    followme.advancePowerSupply(60);
    near("parked headlights draw from 12 V", (before - lv.getRemainingInkWh()) * 3600000,
         60 * aux.current * 12, 0.001);
    if (aux.current < 110 / 12) die("parked lamps drew too little current");
    near("parked lamps leave traction pack alone", hv.getRemainingInkWh(), hvBefore);
    setprop("/controls/lighting/headlight", 0);
    lv.resetRemainingToZero();
    followme.frontWiper.Fast();
    followme.advancePowerSupply(0);
    near("empty accessory bus stops wiper", getprop("/controls/wiper/frontwiper/switch/powered"), 0);
    near("flat 12 V inhibits start", followme.requestDrivePower(), 0);
    followme.frontWiper.Stop();
    followme.quickRecharge();
    near("quick recharge recovers 12 V", lv.getRemainingInkWh(), 0.72);

    near("start accepted", engine.engine_1.startEngine(), 1);
    followme.advancePowerSupply(0.1);
    near("precharge ramp", followme.linkVoltage, 200);
    engine.engine_1.update_engine();
    near("traction inhibited during precharge", engine.engine_1.isRunning(), 0);
    followme.advancePowerSupply(0.1025);
    if (followme.powerState != "ready") die("precharge did not complete");
    near("capacitor energy from HV including feed loss",
         (90 - hv.getRemainingInkWh()) * 3600000, 0.5 * 0.002 * 405 * 405, 0.1);
    engine.engine_1.update_engine();
    near("traction enabled after precharge", engine.engine_1.isRunning(), 1);
    setprop("/services/service-truck/connect", 1);
    near("cannot connect a running vehicle", getprop("/services/service-truck/connect"), 0);
    lv.setRemainingFraction(0.5);
    setprop("/controls/lighting/headlight", 1);
    hvBefore = hv.getRemainingInkWh();
    followme.advancePowerSupply(60);
    near("DC/DC powers lamps and tops up 12 V", lv.getRemainingInkWh(), 0.362);
    near("converter output watts", getprop("/systems/electrical/e-tron/dc-dc-output-w"), 255);
    near("DC/DC input includes conversion loss",
         (hvBefore - hv.getRemainingInkWh()) * 3600000, 60 * 255 / 0.92, 1);
    hv.setRemainingKWh(1e-7);
    var auxBeforeCutoff = lv.getRemainingInkWh();
    followme.advancePowerSupply(1);
    near("depleted HV opens the contactor", followme.powerState == "off", 1);
    if (followme.linkVoltage < 0 or lv.getRemainingInkWh() >= auxBeforeCutoff)
        die("accessories must fall back to 12 V when the traction pack runs out");
    engine.engine_1.stopEngine();
    setprop("/controls/lighting/headlight", 0);

    hv.setRemainingFraction(0.5);
    var savedAux = lv.getRemainingInkWh();
    near("half pack kWh", hv.getRemainingInkWh(), 45);
    followme.save();
    hv.resetRemainingToFull();
    lv.resetRemainingToFull();
    save.resume();
    near("saved 12 V charge", lv.getRemainingInkWh(), savedAux);
    bus.update(2);
    near("restored charge survives next tick", hv.getRemainingInkWh(), 45);
    props.getNode("/save/bkwh").remove();
    setprop("/save/br", 25);
    followme.resume();
    near("percentage-only save", hv.getRemainingInkWh(), 22.5);
    setprop("/save/bkwh", 0);
    followme.resume();
    near("saved empty pack", hv.electromotiveForce, 0);
    near("empty pack cannot start motor", engine.engine_1.startEngine(), 0);

    dialogs.batteryPayload.openBAP();
    var widget = dialogs.batteryPayload._widget.Front;
    widget._onChargeInputChange({type: "drag", deltaX: widget._width * 0.5});
    near("panel changes pack", hv.getRemainingInkWh(), 45);
    near("panel fill", widget._cLevel.get("coord[2]"), widget._left + widget._width / 2, 1e-4);
    if (widget._cDataAbs.getText() != "45.0 kWh") die("incorrect battery label");
    widget._onChargeInputChange({type: "wheel", deltaY: -2 * widget._width});
    near("panel clamps at empty", hv.getRemainingInkWh(), 0);
    dialogs.batteryPayload.close();

    setprop("/services/service-truck/connect", 1);
    followme.chargeBatteryStart();
    near("charger started", getprop("/controls/is-recharging"), 1);
    engine.startEngine(engine.engine_1);
    near("charging interlock", engine.mainSwitchStarted, 0);
    followme.updateCharging(60);
    near("one minute at 240 kW", hv.getRemainingInkWh(), 4);
    setprop("/services/service-truck/connect", 0);
    followme.updateCharging(30);
    near("unplug stops charging", getprop("/controls/is-recharging"), 0);
    near("unplugged energy", hv.getRemainingInkWh(), 4);
    setprop("/services/service-truck/connect", 1);
    followme.chargeBatteryStart();
    followme.updateCharging(3600);
    near("full pack", hv.getRemainingInkWh(), 90);
    near("charger stopped at full", getprop("/controls/is-recharging"), 0);
    near("instrument charge", getprop("/systems/electrical/e-tron/battery-kWh"), 90);
};

var begun = 0;
setlistener("/sim/signals/fdm-initialized", func(n) {
    if (!n.getBoolValue() or begun) return;
    begun = 1;
    settimer(func {
        var errors = [];
        call(checkElectrical, [], nil, nil, errors);
        if (size(errors)) print("TYRETEST STEP electrical FAILED: ", errors[0]);
        else print("TYRETEST DONE");
        fgcommand("exit");
    }, 5);
}, 1);
