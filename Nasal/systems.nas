####    Follow Me   ####
####    Gijs de Rooy (Original)    ####
####    Sidi Liang    ####

io.include("library.nas");

props.getNode("/sim/gui/dialogs/vehicle_config/dialog",1);
var configDialog = gui.Dialog.new("/sim/gui/dialogs/vehicle_config/dialog", "Aircraft/followme_e-tron/gui/dialogs/config-dialog.xml");

aircraft.livery.init("Aircraft/followme_e-tron/Models/Messages");
var liveryPath = props.getNode("sim/aircraft-dir").getValue()~"/Models/Liveries/";
var liverySelector = followme.TextureSelector.new(path: liveryPath, fileType: ".xml", textureProp: "texture-fuse", defaultValue: "Yellow(Default)");
liverySelector.scanXML();
aircraft.livery.select("Blanco");

var tyreSmoke_0 = aircraft.tyresmoke.new(0, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_1 = aircraft.tyresmoke.new(1, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_2 = aircraft.tyresmoke.new(2, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_3 = aircraft.tyresmoke.new(3, auto = 1, diff_norm = 0.4, check_vspeed = 0);


var frontleft_door = aircraft.door.new("/controls/doors/frontleft", 1);
var frontright_door = aircraft.door.new("/controls/doors/frontright", 1);
var rearleft_door = aircraft.door.new("/controls/doors/rearleft", 1);
var rearright_door = aircraft.door.new("/controls/doors/rearright", 1);
aircraft.door.toggle = func(){
    var pos = me.getpos();
    if(pos == 0){
        me.open();
        playAudio('door_open.wav');
    }
    if(pos == 1){
        me.close();
        playAudio('door_shut.wav');
    }
}

beacon_switch = props.globals.getNode("controls/switches/warninglight", 2);
var beacon = aircraft.light.new( "/sim/model/lights/warning", [0.5, 0.5], "/controls/lighting/warning" );
beacon_switch = props.globals.getNode("controls/switches/indicator-left", 2);
var beacon = aircraft.light.new( "/sim/model/lights/indicator-left", [0.5, 0.5], "/controls/lighting/indicator-left");
beacon_switch = props.globals.getNode("controls/switches/indicator-right", 2);
var beacon = aircraft.light.new( "/sim/model/lights/indicator-right", [0.5, 0.5], "/controls/lighting/indicator-right");

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
props.getNode("systems/auto_hold_enabled", 1).setValue(0);
props.getNode("systems/auto_hold_working", 1).setValue(0);

#var Led = {
#
#    new: func() { return { parents:[Led] },
#    node: props.getNode("/sim/model/livery/texture",1),
#    blankTexture: "Messages/blanco.png",
#    currentMessage: "",
#    messageHistory : [],
#
#    display: func(content){
#        me.node.setValue(content);
#    },
#
#
#};

var Indicator = {

    #     Usage:                                        #
    #  var leftIndicator = Indicator.new("left");       #
    #  var rightIndicator = Indicator.new("right");     #
    #                                                   #

    type: "",
    new: func(type) { return { parents:[Indicator], type: type}; },
    state: 0,
    switchOn: func(){
        props.getNode("/", 1).setValue("/controls/lighting/indicator-"~me.type, 1);
        me.state = 1;
    },
    switchOff: func(){
        props.getNode("/", 1).setValue("/controls/lighting/indicator-"~me.type, 0);
        me.state = 0;
    },
    isOn: func(){
        return me.state;
    },
    isOff: func(){
        if(me.state){
            return 0;
        }else{
            return 1;
        }
    },
};

var IndicatorController = {

    #
    #   Usage:
    #       mode:
    #           0:Off
    #           1:Right without led
    #           2:Left without led
    #           3:both without led
    #           4:Right with led
    #           5:Left with led
    #           6:both with led(WIP)
    #       getMode(): Get currrent mode
    #       setMode(mode): Set mode(0,1,2), return 0 if fail
    #
    #
    #
    #
    #

    new: func() { return { parents:[IndicatorController]}; },

    leftIndicator : Indicator.new("left"),
    rightIndicator : Indicator.new("right"),

    mode:0,

    falseLight: 0,

    ledMessage: props.getNode("/sim/model/livery/texture",1),
    ledMessageFile: props.getNode("/sim/model/livery/file",1),
    ledMessageName: props.getNode("/sim/model/livery/name",1),


    savedMessage:{
        texture: "",
        file: "",
        name: "",
    },

    textureRight: {
        texture:"Messages/right.png",
        file: "right",
        name: "Right",
    },
    textureLeft: {
        texture:"Messages/left.png",
        file: "left",
        name: "Left",
    },

    saveLedMessage: func(){
        me.savedMessage.texture = me.ledMessage.getValue();
        me.savedMessage.file = me.ledMessageFile.getValue();
        me.savedMessage.name = me.ledMessageName.getValue();
    },
    getSavedMessage: func(){
        return me.savedMessage;
    },
    clearSavedMessage: func(){
        me.savedMessage.texture = "";
        me.savedMessage.file = "";
        me.savedMessage.name = "";
    },
    setLedMessage: func(content){
        me.ledMessage.setValue(content.texture);
        me.ledMessageFile.setValue(content.file);
        me.ledMessageName.setValue(content.name);
    },
    resumeLedMessage: func(){
        if(me.getSavedMessage().name != ""){
            me.setLedMessage(me.getSavedMessage());
            me.clearSavedMessage();
        }
    },

    getMode: func(){
        return me.mode;
    },
    setMode: func(targetMode){
        if(targetMode == 0){
            me.resumeLedMessage();
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOff();
            me.mode = targetMode;

            if(me.falseLight == 1){
                me.setMode(3);
            }

        }else if(targetMode == 1){
            me.resumeLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOff();
            me.mode = targetMode;
        }else if(targetMode == 2){
            me.resumeLedMessage();
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOn();
            me.mode = targetMode;
        }else if(targetMode == 3){
            me.resumeLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOn();
            me.mode = targetMode;
        }else if(targetMode == 4){

            me.resumeLedMessage();
            me.saveLedMessage();

            me.rightIndicator.switchOn();
            me.leftIndicator.switchOff();

            me.setLedMessage(me.textureRight);

            me.mode = targetMode;
        }else if(targetMode == 5){

            me.resumeLedMessage();
            me.saveLedMessage();

            me.rightIndicator.switchOff();
            me.leftIndicator.switchOn();

            me.setLedMessage(me.textureLeft);

            me.mode = targetMode;
        }else if(targetMode == 6){
            me.mode = targetMode;
        }else{
            return 0;
        }
    },

    right_indicator_toggle : func(){
        if(isInternalView()) playAudio('IndicatorEnd.wav');
        if(me.getMode() != 4){
            me.setMode(4);
        }else if(me.getMode() == 4){
            me.setMode(0);
        }
    },
    left_indicator_toggle : func(){
        if(isInternalView()) playAudio('IndicatorEnd.wav');
        if(me.getMode() != 5){
            me.setMode(5);
        }else if(me.getMode() == 5){
            me.setMode(0);
        }
    },

    falseLightOn : func(){
        if(isInternalView()) playAudio("electric_handbrake.wav");
        me.falseLight = 1;
        if(me.mode == 1 or me.mode == 2 or me.mode == 4 or me.mode == 5){
           print("falseLight mode on");
        }else{
            me.setMode(3);
            print("falseLight turned on");
        }

    },
    falseLightOff : func(){
        if(isInternalView()) playAudio("electric_handbrake.wav");
        me.falseLight = 0;
        if(me.mode == 1 or me.mode == 2 or me.mode == 4 or me.mode == 5){
           print("falseLight mode off");
        }else{
            me.setMode(0);
            print("falseLight turned off");
        }
    },
    false_light_toggle : func(){
        if(me.falseLight == 0){
            me.falseLightOn();
        }else if(me.falseLight == 1){
            me.falseLightOff();
        }
    },
};

var indicatorController = IndicatorController.new();

var BrakeController = {
    new: func() { return { parents:[BrakeController]}; },
    leftBrakeNode: props.getNode("/controls/gear/brake-left",1),
    rightBrakeNode: props.getNode("/controls/gear/brake-right",1),
    parkingBrakeNode: props.getNode("/controls/gear/brake-parking",1),

    applyingFeetBrake: 0,
    handBrakeIsOn: 0,
    leftBrakeValue: 0,
    rightBrakeValue: 0,

    applyLeftBrake: func(value){
        #For internal use
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
    },
    applyRightBrake: func(value){
        #For internal use
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
    },
    applyBrakes: func(value){
        #For internal use
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
    },
    applyFeetBrakes: func(value){
        #For feet brakes
        if(value) applyingFeetBrake = 1;
        else applyingFeetBrake = 0;
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
        if(value == 1) safety.emergencyMode();
    },

    enableHandBrake: func(){
        settimer(func(){ #Delay for 0.8 seconds
            me.parkingBrakeNode.setValue(1);
            me.handBrakeIsOn = 1;
        }, 0.8);
    },
    disableHandBrake: func(){
        settimer(func(){ #Delay for 0.8 seconds
            me.parkingBrakeNode.setValue(0);
            me.handBrakeIsOn = 0;
        }, 0.8);
    },
    toggleHandBrake: func(){
        #Toggle handbrake from button
        if(isInternalView()) playAudio("electric_handbrake.wav");
        if(!me.handBrakeIsOn){
            me.enableHandBrake();
        }else{
            me.disableHandBrake();
        }
    },
    activeEmergencyBrake: func(){
        me.applyLeftBrake(1);
        me.applyRightBrake(1);
        me.enableHandBrake();
        safety.emergencyMode();
    },
    keyboardBrake: func(){
        me.applyFeetBrakes(0.8);
    },
    keyboardBrakeRelease: func(){
        me.applyFeetBrakes(0);
    },
    releaseBrake: func(){
        me.applyLeftBrake(0);
        me.applyRightBrake(0);
    },
    releaseAllBrakes: func(){
        me.applyLeftBrake(0);
        me.applyRightBrake(0);
        me.disableHandBrake();
    },
};

var brakeController = BrakeController.new();

var toggleHandBrake = func(){
    #//Depreciated as BrakeController has it internally now
    if(isInternalView()) playAudio("electric_handbrake.wav");
    if(!brakeController.handBrakeIsOn){
        brakeController.enableHandBrake();
    }else{
        brakeController.disableHandBrake();
    }
}

var chargeBatterySec = func(){
    #//var battery = props.getNode("/systems/electrical/e-tron/battery-kWs");
    #//var currentBattery = battery.getValue();
    var battery = circuit_1.parallelConnection[0].units[0];
    var batteryRemaining = battery.remaining;
    var batteryElecForce = battery.ratedElectromotiveForce;
    if(batteryRemaining >= battery.electricalCapacity){
        screen.log.write("Battery is Successfully recharged!", 0, 0.584, 1);
        chargeBatteryStop(batteryElecForce);
    }
    #//battery.setValue(currentBattery+240);
    #//batteryRemaining += 240;
    circuit_1.parallelConnection[0].units[0].addToBattery(240);
}
var chargeTimer = maketimer(1, chargeBatterySec);
var chargeBatteryStart = func(){
    var battery = circuit_1.parallelConnection[0].units[0];
    var batteryRemaining = battery.remaining;
    var batteryTotal = battery.electricalCapacity;
    var batteryElecForce = battery.electromotiveForce;
    if(!props.getNode("/controls/is-recharging", 1).getValue()){
        if(props.getNode("/",1).getValue("services/service-truck/connect") == 1 and props.getNode("/",1).getValue("/controls/engines/engine/started") == 0){
            var deltaBattery = batteryTotal - batteryRemaining;
            battery.electromotiveForce = 0;
            var remainingTime = sprintf("%.0f", (deltaBattery / 240) / 60);      #Based on 20 mins from 0 to full
            screen.log.write("Recharging. About "~remainingTime~" mins remaining.", 0, 0.584, 1);
            setprop("/sim/sound/voices/pilot", "Recharging. About "~remainingTime~" mins remaining.");
            chargeTimer.start();
            props.getNode("/controls/is-recharging", 1).setValue(1);
        }else if(!props.getNode("/",1).getValue("services/service-truck/connect")){
            screen.log.write("Cannot recharge. Call service truck and connect the cable first.", 0, 0.584, 1);
            setprop("/sim/sound/voices/pilot", "Cannot recharge. Call service truck and connect the cable first.");
        }else if(props.getNode("/",1).getValue("/controls/engines/engine/started")){
            screen.log.write("Cannot recharge. Shut down the engine first.", 0, 0.584, 1);
            setprop("/sim/sound/voices/pilot", "Cannot recharge. Shut down the engine first.");
        }
    }else if(props.getNode("/controls/is-recharging", 1).getValue()){
        chargeBatteryStop(batteryElecForce);
    }
}
var chargeBatteryStop = func(bef){
   chargeTimer.stop();
   circuit_1.parallelConnection[0].units[0].electromotiveForce = bef;
   screen.log.write("Recharge Stopped", 0, 0.584, 1);
   setprop("/sim/sound/voices/pilot", "Recharge Stopped. Have a nice ride!");
   props.getNode("/controls/is-recharging", 1).setValue(0);
}

var calculateSpeed = func(){
    var gs = props.getNode("velocities/groundspeed-kt", 1).getValue();
    var speedKmh = 1.852 * gs;
    var calculated = 0;
    var output = 0;
    if(speedKmh <= 0){
        calculated = speedKmh * -1;
    }else if(speedKmh < 280){
        calculated = speedKmh;
    }else if(speedKmh >= 280){
        calculated = 280;
    }

    if(calculated <= 120){
        output = calculated * 3/2;
    }else if(calculated > 120){
        output = calculated * 3/4;
    }

    props.getNode("systems/display-speed", 1).setValue(output);
}
var calculateSpeedTimer = maketimer(0.1, calculateSpeed);

var resetOnPosition = func(){
    var latProp = props.getNode("/position/latitude-deg");
    var lonProp = props.getNode("/position/longitude-deg");
    var lat = latProp.getValue();
    var lon = lonProp.getValue();
    setprop("/fdm/jsbsim/simulation/pause", 1);
    setprop("/fdm/jsbsim/simulation/reset", 1);
    var groundAlt = props.getNode("/position/ground-elev-ft").getValue();
    props.getNode("/position/altitude-ft").setValue(groundAlt+7);
    latProp.setValue(lat);
    lonProp.setValue(lon);
    setprop("/fdm/jsbsim/simulation/pause", 0);
}

var brakesABS = func(){
    var gearFrtLftSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/wheel-speed-fps"));
    var gearFrtRgtSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[1]/wheel-speed-fps"));
    var gearBckLftSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[2]/wheel-speed-fps"));
    var gearBckRgtSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[3]/wheel-speed-fps"));
    if(gearFrtLftSpeed == 0 or gearBckLftSpeed == 0 or gearFrtRgtSpeed == 0 or gearBckRgtSpeed == 0){
        safety.emergencyMode();
        props.getNode("/",1).setValue("/controls/gear/brake-left", 0);
        props.getNode("/",1).setValue("/controls/gear/brake-right", 0);
    }else{
        props.getNode("/",1).setValue("/controls/gear/brake-left", 1);
        props.getNode("/",1).setValue("/controls/gear/brake-right", 1);
    }
}

var Safety = {
    new: func(airbagAccelerationLimit=140, sideAirbagAccelerationLimit=75){
        var newSafety = { parents:[Safety] };
        newSafety.airbagAccelerationLimit = airbagAccelerationLimit;
        newSafety.sideAirbagAccelerationLimit = sideAirbagAccelerationLimit;
        newSafety.frontRadar = Radar.new(0.3, 0, 0, 9, 0.1, 180, 0, 0);#For AEB
        newSafety.absTimer = maketimer(0.001, brakesABS);
        return newSafety;
    },
    isOn: 0,
    safetySystemTimer: nil,
    updateInterval: 0.01,
    frontRadarEnabled: 0,
    aebActivated: 0,
    lastRadarOutput:10000,
    throttleNode: props.getNode("/controls/engines/engine/throttle",1),
    #Airbag
    accXProp: props.getNode("/fdm/jsbsim/accelerations/a-pilot-x-ft_sec2", 1),
    accYProp: props.getNode("/fdm/jsbsim/accelerations/a-pilot-y-ft_sec2", 1),
    frontAirbagProp: props.getNode("/systems/safety/airbag/front", 1),
    sideAirbagProp: props.getNode("/systems/safety/airbag/side", 1),
    aebStateProp: props.getNode("/systems/safety/aeb_activated", 1),
    airbagAccelerationLimit: 140, #To be configured,m/s^2
    sideAirbagAccelerationLimit: 75, #To be configured,m/s^2

    #Frontwards radar
    frontRadar: nil,

    enableFrontRadar: func(){
        #Enables the front radar
        me.frontRadarEnabled = 1;
        me.frontRadar.init();
        me.frontRadar.stop();
        print("Front radar enabled");
    },
    disableFrontRadar: func(){
        #Disables the front radar
        if(me.frontRadarEnabled) me.frontRadar.stop();
        me.frontRadarEnabled = 0;
    },
    toggleFrontRadar: func(){
        if(!me.frontRadarEnabled){
            me.enableFrontRadar();
            playAudio("parking_radar_init.wav");
        }
        else me.disableFrontRadar();
    },

    aebActive: func(){
        me.aebActivated = 1;
        #engine.engine_1.engineSwitch.switchDisconnect();
        me.throttleNode.setValue(0);
        brakeController.activeEmergencyBrake();
        playAudio("parking_radar_init.wav");
        me.aebStateProp.setValue(1);
        print("AEB Activated!");
    },
    aebStop: func(){
        me.aebActivated = 0;
        print("AEB Stopped");
        me.aebStateProp.setValue(0);
        #engine.engine_1.engineSwitch.switchConnect();
        brakeController.releaseAllBrakes();
    },

    update: func(){
        #print("running");
        #Front airbag
        if(math.abs(me.accXProp.getValue() * FT2M) > me.airbagAccelerationLimit){
            #active Front
            me.frontAirbagProp.setValue(1);
            me.emergencyMode();
        }
        #side airbag
        if(math.abs(me.accYProp.getValue() * FT2M) > me.sideAirbagAccelerationLimit){
            #active side
            me.sideAirbagProp.setValue(1);
            me.emergencyMode();
        }

        var currentSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]")*1.852;#In km/h
        #AEB, Automatic Emergency Brake
        var radarOutput = me.frontRadar.radarOutput;
        var deltaX = me.lastRadarOutput - radarOutput;
        var reletiveSpeed = 3.6 * (deltaX / me.updateInterval);#In km/h
        if(currentSpeed > 30 and engine.engine_1.getDirection() == 1){
            #Enable AEB when speed is greater then 30kmh
            if(me.frontRadarEnabled){
                me.frontRadar.init();
                if(me.frontRadar.radarOutput <= 8 and reletiveSpeed > 30 and !me.aebActivated){
                    me.aebActive();
                }else if((me.frontRadar.radarOutput >= 8 or reletiveSpeed <= 0) and me.aebActivated){
                    me.aebStop();
                }
            }
        }else{
            if(me.frontRadarEnabled and me.frontRadar.radarTimer.isRunning) me.frontRadar.stop();
            if(reletiveSpeed <= 0 and me.aebActivated) me.aebStop();
        }

        #ABS
        #var brakeCmd = props.getNode("/",1).getValue("/controls/gear/brake-left");
        #if(brakeCmd and currentSpeed){
        #    me.absTimer.start();
        #}else{
        #    me.absTimer.stop();
        #}

    },

    emergencyMode: func(){
        indicatorController.setMode(3); #Active malfunction light
        indicatorController.falseLight = 1;
        if(autospeed.autoSpeedTimer.isRunning) autospeed.stopAutoSpeed();
        if(autopilot.road_check_timer.isRunning) autopilot.road_check_timer.stop();
    },

    reset: func(){
        #resetting stops the safety system
        me.safetySystemTimer.stop();
        if(me.frontRadarEnabled) me.frontRadar.stop();
        me.frontAirbagProp.setValue(0);
        me.sideAirbagProp.setValue(0);
        me.aebStateProp.setValue(0);
    },
    init: func(){
        #initialize or reinitialize
        me.frontAirbagProp.setValue(0);
        me.sideAirbagProp.setValue(0);
        me.aebStateProp.setValue(0);
        if(me.safetySystemTimer == nil) me.safetySystemTimer = maketimer(me.updateInterval, func me.update());
        me.safetySystemTimer.start();
        if(me.frontRadarEnabled) me.enableFrontRadar();
        me.isOn = 1;
        print("Safety system initialized");
    },
    stop: func(){
        me.isOn = 0;
        me.aebStateProp.setValue(0);
        me.disableFrontRadar();
        me.safetySystemTimer.stop();
        print("Safety system stoped");
    },
    toggle: func(){
        if(!me.isOn) me.init();
        else me.stop();
    },
};
var safety = Safety.new(140, 75);

var brakeWithABS = func(){ #//Doesn't seems to work because it seems that jsbsim wheels never overbrake?
#//abondoned since the new safety system
    var brakeCmd = props.getNode("/",1).getValue("/controls/gear/brake-left");
    if(brakeCmd){
        absTimer.start();
    }else{
        absTimer.stop();
    }
}

var testingProgram_1_Entry = func(){
    autospeed.startAutoSpeed();
    autospeed.targetSpeedChange(100);
    settimer(testingProgram_1, 10);
}

var testingProgram_1 = func(){
    props.getNode("/",1).setValue("/controls/gear/brake-left", 1);
    props.getNode("/",1).setValue("/controls/gear/brake-right", 1);
    props.getNode("/",1).setValue("/controls/gear/brake-parking", 1);
}

var testingProgram_2_Entry = func(){
    autospeed.startAutoSpeed();
    autospeed.targetSpeedChange(100);
    settimer(testingProgram_2, 10);
}

var testingProgram_2 = func(){
    props.getNode("/",1).setValue("/controls/gear/brake-left", 1);
    props.getNode("/",1).setValue("/controls/gear/brake-right", 1);
    #props.getNode("/",1).setValue("/controls/gear/brake-parking", 1);
}

#setlistener("/controls/gear/brake-left", brakeWithABS);
