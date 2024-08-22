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

#// vehicle information
var vInfo = VehicleInformationManager.new();


#//Environment
vInfo.environment = props.getNode("/environment", 1);
vInfo.environment.temperature = props.getNode("/environment/temperature-degc", 1);

#//Engine
vInfo.engine = {};
vInfo.engine.throttleNode = props.getNode("/controls/engines/engine/throttle",1);
vInfo.engine.rpmNode = props.getNode("/controls/engines/engine/rpma",1);
vInfo.engine.isStarted = props.getNode("/controls/engines/engine/started",1);
vInfo.engine.direction = props.getNode("/controls/direction", 1);
vInfo.engine.mode = props.getNode("/controls/mode", 1);

#//Controls
vInfo.controls = props.getNode("/controls", 1);
vInfo.controls.lighting = vInfo.controls.getNode("lighting", 1);
vInfo.controls.doors = vInfo.controls.getNode("doors", 1);

#//Doors
vInfo.controls.doors.FL = vInfo.controls.doors.getNode("FL", 1);
vInfo.controls.doors.FR = vInfo.controls.doors.getNode("FR", 1);
vInfo.controls.doors.RL = vInfo.controls.doors.getNode("RL", 1);
vInfo.controls.doors.RR = vInfo.controls.doors.getNode("RR", 1);
vInfo.controls.doors.charging_cap = vInfo.controls.doors.getNode("charging_cap", 1);

#//Shortcut for Lignting
vInfo.lighting = vInfo.controls.lighting;
vInfo.lighting.reverseIndicator = vInfo.lighting.getNode("reverse_indicator", 1);
vInfo.lighting.highBeam = vInfo.lighting.getNode("highBeam", 1);
vInfo.lighting.indicator = vInfo.lighting.getNode("indicator", 1);
vInfo.lighting.indicator.leftSwitch = vInfo.lighting.indicator.getNode("left_switch", 1);
vInfo.lighting.indicator.rightSwitch = vInfo.lighting.indicator.getNode("right_switch", 1);
vInfo.lighting.indicator.left = vInfo.lighting.getNode("indicator-left", 1);
vInfo.lighting.indicator.right = vInfo.lighting.getNode("indicator-right", 1);
vInfo.lighting.warningLight = props.getNode("/warninglight/start");

#//Systems
vInfo.systems = props.getNode("/systems", 1);
vInfo.systems.welcomeMessage = vInfo.systems.getNode("welcome-message", 1);
vInfo.systems.horn = vInfo.systems.getNode("horn", 1);
vInfo.systems.speedometer = vInfo.systems.getNode("speedometer", 1);
vInfo.systems.speedometer.type = vInfo.systems.speedometer.getNode("type", 1);
vInfo.systems.batteryGauge = vInfo.systems.getNode("battery-gauge", 1);
vInfo.systems.batteryGauge.type = vInfo.systems.batteryGauge.getNode("type", 1);
vInfo.systems.driftSoundEnabled = vInfo.systems.getNode("drifting-sound", 1);

#//Electrical
vInfo.systems.electrical = props.getNode("/systems/electrical/", 1);
vInfo.systems.electrical.etron = vInfo.systems.electrical.getNode("e-tron", 1);
vInfo.electrical = vInfo.systems.electrical.etron; #Shortcut
vInfo.electrical.batteryRemainingPercent = vInfo.electrical.getNode("battery-remaining-percent", 1);
vInfo.electrical.batteryRemainingPercentFloat = vInfo.electrical.getNode("battery-remaining-percent-float", 1);

#//Safety
vInfo.systems.safety = vInfo.systems.getNode("safety", 1);
vInfo.systems.safety.aebActivated = vInfo.systems.safety.getNode("aeb_activated", 1);
vInfo.systems.safety.isAebOn = vInfo.systems.safety.getNode("aeb_on", 1);
#//Automatic driving
vInfo.systems.isAutoholdEnabled = vInfo.systems.getNode("auto_hold_enabled", 1);
vInfo.systems.isAutoholdWorking = vInfo.systems.getNode("auto_hold_working", 1);


#//Initialization
#//Lignting
vInfo.lighting.reverseIndicator.setValue(0);
vInfo.lighting.highBeam.setValue(0);
vInfo.lighting.indicator.left.setValue(0);
vInfo.lighting.indicator.right.setValue(0);
vInfo.lighting.indicator.left.setValue(0);
vInfo.lighting.indicator.right.setValue(0);
vInfo.lighting.warningLight.setValue(0);

#//Systems
vInfo.systems.welcomeMessage.setValue(0);
vInfo.systems.speedometer.type.setValue("None");
vInfo.systems.batteryGauge.type.setValue("None");

vInfo.systems.safety.aebActivated.setValue("0");
vInfo.systems.safety.isAebOn.setValue("0");

vInfo.systems.isAutoholdEnabled.setValue("0");
vInfo.systems.isAutoholdWorking.setValue("0");

vInfo.systems.driftSoundEnabled.setValue(0);

#//Doors
vInfo.controls.doors.FL.setValue(0);
vInfo.controls.doors.FR.setValue(0);
vInfo.controls.doors.RL.setValue(0);
vInfo.controls.doors.RR.setValue(0);

props.getNode("/",1).setValue("/controls/mode", 1);
props.getNode("/",1).setValue("/controls/direction", 1);
props.getNode("/",1).setValue("/systems/instruments/enable_switches", 0);


props.getNode("/",1).setValue("services/service-truck/enable", 0);
props.getNode("controls/is-recharging", 1).setValue(0);
props.getNode("services/service-truck/connect", 1).setValue(0);


props.getNode("systems/plate/file", 1).setValue("NONE");
props.getNode("systems/plate/name", 1).setValue("NONE");

props.getNode("/controls/steering_wheel", 1).setValue(0);
props.getNode("controls/interior/luxury/storage_cover_pos", 1).setValue(0);
props.getNode("controls/interior/armrest_cover_pos", 1).setValue(0);
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
