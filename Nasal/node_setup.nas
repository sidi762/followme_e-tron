var VehicleInformationManager = {
    new: func(){
        var m = {parents:[VehicleInformationManager]};
        m._speedKTSNode = props.getNode("/sim/multiplay/generic/float[15]", 1);
        m._headingNode = props.getNode("/orientation/heading-deg",1);
        m._altitudeFTNode = props.getNode("/position/altitude-ft",1);
        return m;
    },
    getSpeedKMH: func(){
        return me._speedKTSNode.getValue()*1.852;
    },
    getSpeedKTS: func(){
        return me._speedKTSNode.getValue();
    },
    getHeadingDEG: func(){
        return me._headingNode.getValue();
    },
    getAltitudeFT: func(){
        return me._altitudeFTNode.getValue();
    },
    engine:{},
};

var vehicleInformation = VehicleInformationManager.new();

#//For Engine
vehicleInformation.engine.throttleNode = props.getNode("/controls/engines/engine/throttle",1);
vehicleInformation.engine.rpmNode = props.getNode("/controls/engines/engine/rpma",1);
vehicleInformation.engine.isStarted = props.getNode("/controls/engines/engine/started",1);
vehicleInformation.engine.direction = props.getNode("/controls/direction", 1);
vehicleInformation.engine.mode = props.getNode("/controls/mode", 1);

#//Lignting
vehicleInformation.lighting = props.getNode("/controls/lighting", 1);
vehicleInformation.lighting.reverseIndicator = vehicleInformation.lighting.getNode("reverse_indicator", 1);

props.getNode("/",1).setValue("/controls/lighting/indicator-left", 0);
props.getNode("/",1).setValue("/controls/lighting/indicator-right", 0);

props.getNode("/",1).setValue("/systems/horn", 0);
props.getNode("/",1).setValue("/controls/mode", 1);
props.getNode("/",1).setValue("/controls/direction", 1);
props.getNode("/",1).setValue("/systems/instruments/enable_switches", 0);
props.getNode("/",1).setValue("/systems/instruments/enable_cdu", 0);
props.getNode("/",1).setValue("/instrumentation/cdu/ident/model", "Follow me EV");
props.getNode("/",1).setValue("/instrumentation/cdu/ident/engines", "EV Motor");

props.getNode("/",1).setValue("services/service-truck/enable", 0);
props.getNode("controls/is-recharging", 1).setValue(0);
props.getNode("systems/welcome-message", 1).setValue(0);
props.getNode("systems/display-speed", 1).setValue(0);
props.getNode("systems/speedometer/type", 1).setValue("Type_A");
props.getNode("systems/battery-gauge/type", 1).setValue("Type_A");
props.getNode("systems/plate/file", 1).setValue("NONE");
props.getNode("systems/plate/name", 1).setValue("NONE");
props.getNode("controls/lighting/headlight-als", 1).setValue(0);
props.getNode("controls/lighting/highBeam", 1).setValue(0);
props.getNode("/controls/steering_wheel", 1).setValue(0);
props.getNode("controls/interior/luxury/storage_cover_pos", 1).setValue(0);
props.getNode("sim/remote/pilot-callsign", 1).setValue("");
props.getNode("systems/codriver-enable", 1).setValue(0);
props.getNode("systems/screen-enable", 1).setValue(0);
props.getNode("systems/pmodel-enable", 1).setValue(1);
props.getNode("systems/decorations-enable", 1).setValue(0);
props.getNode("systems/interior/type", 1).setValue("Default");
props.getNode("systems/safety/aeb_activated", 1).setValue(0);
props.getNode("systems/safety/aeb_on", 1).setValue(0);
props.getNode("systems/auto_hold_enabled", 1).setValue(0);
props.getNode("systems/auto_hold_working", 1).setValue(0);
props.getNode("controls/lighting/indicator/left_switch", 1).setValue(0);
props.getNode("controls/lighting/indicator/right_switch", 1).setValue(0);
props.getNode("controls/lighting/reverse_indicator", 1).setValue(0);
