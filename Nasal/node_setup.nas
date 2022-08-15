#//Node Management system and setting up these nodes
#//Sidi Liang, 2021
io.include("library.nas");

var VehicleInformationManager = {
    new: func(){
        var m = {parents:[VehicleInformationManager]};
        m._speedKTSNode = props.getNode("/sim/multiplay/generic/float[15]", 1);
        m._odometerNMNode = props.getNode("instrumentation/gps/odometer", 1);
        m._headingNode = props.getNode("orientation/heading-deg",1);
        m._altitudeFTNode = props.getNode("/position/altitude-ft",1);
		m._timeHourNode = props.getNode("sim/time/real/hour", 1);
		m._timeMinuteNode = props.getNode("sim/time/real/minute", 1);
        return m;
    },
    registerNode: func(){

    },
    getSpeedKMH: func(){
        return me._speedKTSNode.getValue()*1.852;
    },
    getSpeedKTS: func(){
        return me._speedKTSNode.getValue();
    },
    getOdometerKM: func(){
        return me._odometerNMNode.getValue()*1.852;
    },
    getHeadingDEG: func(){
        return me._headingNode.getValue();
    },
    getAltitudeFT: func(){
        return me._altitudeFTNode.getValue();
    },
    getAltitudeMETERS: func(){
        return me._altitudeFTNode.getValue() * FT2M;
    },
	getTimeHour: func(){
		return me._timeHourNode.getValue();
	},
	getTimeMinute: func(){
		return me._timeMinuteNode.getValue();
	},
};

var vehicleInformation = VehicleInformationManager.new();


#//Environment
vehicleInformation.environment = props.getNode("/environment", 1);
vehicleInformation.environment.temperature = props.getNode("/environment/temperature-degc", 1);

#//Engine
vehicleInformation.engine = {};
vehicleInformation.engine.throttleNode = props.getNode("/controls/engines/engine/throttle",1);
vehicleInformation.engine.rpmNode = props.getNode("/controls/engines/engine/rpma",1);
vehicleInformation.engine.isStarted = props.getNode("/controls/engines/engine/started",1);
vehicleInformation.engine.direction = props.getNode("/controls/direction", 1);
vehicleInformation.engine.mode = props.getNode("/controls/mode", 1);

#//Controls
vehicleInformation.controls = props.getNode("/controls", 1);
vehicleInformation.controls.lighting = vehicleInformation.controls.getNode("lighting", 1);
vehicleInformation.controls.doors = vehicleInformation.controls.getNode("doors", 1);

#//Doors
vehicleInformation.controls.doors.FL = vehicleInformation.controls.doors.getNode("FL", 1);
vehicleInformation.controls.doors.FR = vehicleInformation.controls.doors.getNode("FR", 1);
vehicleInformation.controls.doors.RL = vehicleInformation.controls.doors.getNode("RL", 1);
vehicleInformation.controls.doors.RR = vehicleInformation.controls.doors.getNode("RR", 1);
vehicleInformation.controls.doors.charging_cap = vehicleInformation.controls.doors.getNode("charging_cap", 1);

#//Shortcut for Lignting
vehicleInformation.lighting = vehicleInformation.controls.lighting;
vehicleInformation.lighting.reverseIndicator = vehicleInformation.lighting.getNode("reverse_indicator", 1);
vehicleInformation.lighting.highBeam = vehicleInformation.lighting.getNode("highBeam", 1);
vehicleInformation.lighting.indicator = vehicleInformation.lighting.getNode("indicator", 1);
vehicleInformation.lighting.indicator.leftSwitch = vehicleInformation.lighting.indicator.getNode("left_switch", 1);
vehicleInformation.lighting.indicator.rightSwitch = vehicleInformation.lighting.indicator.getNode("right_switch", 1);
vehicleInformation.lighting.indicator.left = vehicleInformation.lighting.getNode("indicator-left", 1);
vehicleInformation.lighting.indicator.right = vehicleInformation.lighting.getNode("indicator-right", 1);

#//Systems
vehicleInformation.systems = props.getNode("/systems", 1);
vehicleInformation.systems.welcomeMessage = vehicleInformation.systems.getNode("welcome-message", 1);
vehicleInformation.systems.horn = vehicleInformation.systems.getNode("horn", 1);
vehicleInformation.systems.speedometer = vehicleInformation.systems.getNode("speedometer", 1);
vehicleInformation.systems.speedometer.type = vehicleInformation.systems.speedometer.getNode("type", 1);
vehicleInformation.systems.batteryGauge = vehicleInformation.systems.getNode("battery-gauge", 1);
vehicleInformation.systems.batteryGauge.type = vehicleInformation.systems.batteryGauge.getNode("type", 1);
vehicleInformation.systems.electrical = {};

#//Safety
vehicleInformation.systems.safety = vehicleInformation.systems.getNode("safety", 1);
vehicleInformation.systems.safety.aebActivated = vehicleInformation.systems.safety.getNode("aeb_activated", 1);
vehicleInformation.systems.safety.isAebOn = vehicleInformation.systems.safety.getNode("aeb_on", 1);
#//Automatic driving
vehicleInformation.systems.isAutoholdEnabled = vehicleInformation.systems.getNode("auto_hold_enabled", 1);
vehicleInformation.systems.isAutoholdWorking = vehicleInformation.systems.getNode("auto_hold_working", 1);


#//Initialization
#//Lignting
vehicleInformation.lighting.reverseIndicator.setValue(0);
vehicleInformation.lighting.highBeam.setValue(0);
vehicleInformation.lighting.indicator.left.setValue(0);
vehicleInformation.lighting.indicator.right.setValue(0);
vehicleInformation.lighting.indicator.left.setValue(0);
vehicleInformation.lighting.indicator.right.setValue(0);

#//Systems
vehicleInformation.systems.welcomeMessage.setValue(0);
vehicleInformation.systems.speedometer.type.setValue("None");
vehicleInformation.systems.batteryGauge.type.setValue("None");

vehicleInformation.systems.safety.aebActivated.setValue("0");
vehicleInformation.systems.safety.isAebOn.setValue("0");

vehicleInformation.systems.isAutoholdEnabled.setValue("0");
vehicleInformation.systems.isAutoholdWorking.setValue("0");

#//Doors
vehicleInformation.controls.doors.FL.setValue(0);
vehicleInformation.controls.doors.FR.setValue(0);
vehicleInformation.controls.doors.RL.setValue(0);
vehicleInformation.controls.doors.RR.setValue(0);


props.getNode("/",1).setValue("/controls/mode", 1);
props.getNode("/",1).setValue("/controls/direction", 1);
props.getNode("/",1).setValue("/systems/instruments/enable_switches", 0);


props.getNode("/",1).setValue("services/service-truck/enable", 0);
props.getNode("controls/is-recharging", 1).setValue(0);



props.getNode("systems/plate/file", 1).setValue("NONE");
props.getNode("systems/plate/name", 1).setValue("NONE");

props.getNode("/controls/steering_wheel", 1).setValue(0);
props.getNode("controls/interior/luxury/storage_cover_pos", 1).setValue(0);
props.getNode("sim/remote/pilot-callsign", 1).setValue("");
props.getNode("systems/codriver-enable", 1).setValue(0);
props.getNode("systems/screen-enable", 1).setValue(0);
props.getNode("systems/pmodel-enable", 1).setValue(1);
props.getNode("systems/decorations-enable", 1).setValue(0);
props.getNode("systems/interior/type", 1).setValue("404Design (Default)");


#Keep or abandon?
props.getNode("controls/lighting/headlight-als", 1).setValue(0);
props.getNode("systems/display-speed", 1).setValue(0);
props.getNode("/",1).setValue("/systems/instruments/enable_cdu", 0);
props.getNode("/",1).setValue("/instrumentation/cdu/ident/model", "Follow me EV");
props.getNode("/",1).setValue("/instrumentation/cdu/ident/engines", "EV Motor");
