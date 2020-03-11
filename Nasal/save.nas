# Followme e-tron save and resume by Marsdolphin c 2020
# This saves and lets you resume the basic functions of the car.
# It will be under development for new features.


var save = func {

    var lat = getprop("/position/latitude-deg");
        setprop("/save/latitude-deg", lat);

    var lon = getprop("/position/longitude-deg");
        setprop("/save/longitude-deg", lon);

    var alt = getprop("/position/altitude-ft");
        setprop("/save/altitude-ft", alt);

    var heading = getprop("/orientation/heading-deg");
        setprop("/save/heading-deg", heading);

    var pitch = getprop("/orientation/pitch-deg");
        setprop("/save/pitch-deg", pitch);

    var roll = getprop("/orientation/roll-deg");
        setprop("/save/roll-deg", roll);


    var left_indicator = getprop("/sim/model/lights/indicator-left/state");
        setprop("/save/l/indicator", left_indicator);

    var right_indicator = getprop("/sim/model/lights/indicator-right/state");
        setprop("/save/r/indicator", right_indicator);


    var horn = getprop("/systems/horn");
        setprop("/save/horn", horn);


    var mode = getprop("/controls/mode");
        setprop("/save/controls/mode", mode);

    var dir = getprop("/controls/direction");
        setprop("/save/controls/dir", dir);

    var aileron = getprop("/controls/flight/aileron");
        setprop("/save/controls/ail", aileron);

    var steering_wheel = getprop("/controls/steering_wheel");
        setprop("/save/controls/stw", steering_wheel);


    var platename = getprop("/systems/plate/name");
        setprop("/save/plate_name", platename);

    var platefile = getprop("/systems/plate/file");
        setprop("/save/plate_file", platefile);


    var interior = getprop("/systems/interior/type");
        setprop("/save/type/int", interior);
        print("State Saved!");
}


# Resume


var resume = func {

    var lat = getprop("/save/latitude-deg");
        setprop("/position/latitude-deg", lat);

    var lon = getprop("/save/longitude-deg");
        setprop("/position/longitude-deg", lon);

    var alt = getprop("/save/altitude-ft");
        setprop("/position/altitude-ft", alt);

    var heading = getprop("/save/heading-deg");
        setprop("/orientation/heading-deg", heading);

    var pitch = getprop("/save/pitch-deg");
        setprop("/orientation/pitch-deg", pitch);

    var roll = getprop("/save/roll-deg");
        setprop("/orientation/roll-deg", roll);


    var left_indicator = getprop("/save/l/indicator");
        setprop("/sim/model/lights/indicator-left/state", left_indicator);

    var right_indicator = getprop("/save/r/indicator");
        setprop("/sim/model/lights/indicator-right/state", right_indicator);


    var horn = getprop("/save/horn");
        setprop("/systems/horn", horn);


    var mode = getprop("/save/controls/mode");
        setprop("/controls/mode", mode);

    var dir = getprop("/save/controls/dir");
        setprop("/controls/direction", dir);

    var aileron = getprop("/save/controls/ail");
        setprop("/controls/flight/aileron", ail);

    var steering_wheel = getprop("/save/controls/stw");
        setprop("/controls/steering_wheel", stw);




    var platename = getprop("/save/plate_name");
        setprop("/systems/plate/name", pm);

    var platefile = getprop("/save/plate_file");
        setprop("/systems/plate/file", pf);


    var interior = getprop("/save/type/int");
        setprop("/systems/interior/type", interior);
        print("State Resumed!");
}
