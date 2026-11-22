# Followme e-tron save and resume by Marsdolphin c 2020
# This saves and lets you resume the functions of the car.
# It will be under development for new features.


# Vehicle variants may leave optional properties unset.
var savedProperties = [
    ["/position/latitude-deg", "/save/latitude-deg"],
    ["/position/longitude-deg", "/save/longitude-deg"],
    ["/position/altitude-ft", "/save/altitude-ft"],
    ["/orientation/heading-deg", "/save/heading-deg"],
    ["/orientation/pitch-deg", "/save/pitch-deg"],
    ["/orientation/roll-deg", "/save/roll-deg"],
    ["/controls/lighting/headlight", "/save/headlight"],
    ["/systems/horn", "/save/horn"],
    ["/controls/mode", "/save/controls/mode"],
    ["/controls/direction", "/save/controls/dir"],
    ["/controls/flight/aileron", "/save/controls/ail"],
    ["/controls/steering_wheel", "/save/controls/stw"],
    ["/controls/gear/brake-parking", "/save/controls/pb"],
    ["/systems/plate/name", "/save/plate_name"],
    ["/systems/plate/file", "/save/plate_file"],
    ["/systems/interior/type", "/save/type/int"],
    ["/systems/decorations-enable", "/save/int/dec"],
    ["/systems/pmodel-enable", "/save/pmodel"],
    ["/controls/doors/rearright/position-norm", "/save/drr"],
    ["/controls/doors/rearleft/position-norm", "/save/drl"],
    ["/controls/doors/frontright/position-norm", "/save/dfr"],
    ["/controls/doors/frontleft/position-norm", "/save/dfl"],
];

var save = func {
    foreach (var paths; savedProperties) {
        var value = getprop(paths[0]);
        if (value != nil) setprop(paths[1], value);
        else {
            var stale = props.getNode(paths[1]);
            if (stale != nil) stale.remove();
        }
    }
    var indicators = followme.indicatorController;
    setprop("/save/indicator-mode", indicators.getMode());
    setprop("/save/indicator-hazards", indicators.falseLight);
    setprop("/save/bkwh", followme.cSource.getRemainingInkWh());
    setprop("/save/br", followme.cSource.getRemainingPercentageFloat());
    setprop("/save/aux-kwh", followme.cSource_small.getRemainingInkWh());

    print("State saved");
}


# Resume


# Restore the switch selection and let the relay drive the lamp outputs.
var restoreIndicators = func {
    var indicators = followme.indicatorController;
    var modes = indicators.IND_MODES;
    var mode = getprop("/save/indicator-mode");
    var hazards = getprop("/save/indicator-hazards");
    if (mode == nil) {
        # Older snapshots stored only the two visible lamps.
        var left = getprop("/save/l/indicator");
        var right = getprop("/save/r/indicator");
        if (left == nil and right == nil) return;
        hazards = left and right;
        if (hazards) mode = modes.BOTH_WITHOUT_LED;
        elsif (left) mode = modes.LEFT_WITH_LED;
        elsif (right) mode = modes.RIGHT_WITH_LED;
        else mode = modes.OFF;
    }
    indicators.falseLight = hazards or 0;
    indicators.stalkTarget = (mode == modes.LEFT_WITH_LED) - (mode == modes.RIGHT_WITH_LED);
    interpolate(indicators.stalkPosition);
    indicators.stalkPosition.setDoubleValue(indicators.stalkTarget);
    if (indicators.getMode() != mode) indicators.setMode(mode);
};

var resume = func {
    foreach (var paths; savedProperties) {
        var value = getprop(paths[1]);
        if (value != nil) setprop(paths[0], value);
    }
    restoreIndicators();
    var aux = getprop("/save/aux-kwh");
    if (aux != nil and num(aux) != nil) followme.cSource_small.setRemainingKWh(num(aux));
    var bkwh = getprop("/save/bkwh");
    var br = getprop("/save/br");
    if (bkwh != nil and num(bkwh) != nil) {
        followme.cSource.setRemainingKWh(num(bkwh));
    } elsif (br != nil and num(br) != nil) {
        followme.cSource.setRemainingFraction(num(br) / 100);
    }

    print("State resumed!");
}
