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
    ["/sim/model/lights/indicator-left/state", "/save/l/indicator"],
    ["/sim/model/lights/indicator-right/state", "/save/r/indicator"],
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
    setprop("/save/bkwh", followme.cSource.getRemainingInkWh());
    setprop("/save/br", followme.cSource.getRemainingPercentageFloat());
    setprop("/save/aux-kwh", followme.cSource_small.getRemainingInkWh());

    print("State saved");
}


# Resume


var resume = func {
    foreach (var paths; savedProperties) {
        var value = getprop(paths[1]);
        if (value != nil) setprop(paths[0], value);
    }
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
