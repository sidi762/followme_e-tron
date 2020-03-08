####    Follow Me   ####
####    Gijs de Rooy (Original)    ####
####    Sidi Liang    ####

props.getNode("/sim/gui/dialogs/vehicle_config/dialog",1);
var configDialog = gui.Dialog.new("/sim/gui/dialogs/vehicle_config/dialog", "Aircraft/followme_e-tron/gui/dialogs/config-dialog.xml");

var liveryFuse = {
	init: func(dir, nameprop = "sim/model/livery/name", sortprop = nil) {
		me.parents = [gui.OverlaySelector.new("Select Livery", dir, nameprop,
				sortprop, "sim/model/livery/file")];
		me.dialog = me.parents[0];
	},
};
var liveryFuse_update = {
	new: func(liveriesdir, interval = 10.01, callback = nil) {
		var m = { parents: [liveryFuse_update, aircraft.overlay_update.new()] };
		m.parents[1].add(liveriesdir, "sim/model/livery/file", callback);
		m.parents[1].interval = interval;
		return m;
	},
	stop: func {
		me.parents[1].stop();
	},
};

aircraft.livery.init("Aircraft/followme_e-tron/Models/Messages");
liveryFuse.init("Aircraft/followme_e-tron/Models/Texture");

aircraft.livery.select("Blanco");

var tyreSmoke_0 = aircraft.tyresmoke.new(0, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_1 = aircraft.tyresmoke.new(1, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_2 = aircraft.tyresmoke.new(2, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_3 = aircraft.tyresmoke.new(3, auto = 1, diff_norm = 0.4, check_vspeed = 0);


props.getNode("/",1).setValue("/systems/horn", 0);
props.getNode("/",1).setValue("/controls/mode", 1);
props.getNode("/",1).setValue("/controls/direction", 1);
props.getNode("/",1).setValue("/systems/instruments/enable_switches", 0);
props.getNode("/",1).setValue("/systems/instruments/enable_cdu", 0);
props.getNode("/",1).setValue("/instrumentation/cdu/ident/model", "Follow me EV");
props.getNode("/",1).setValue("/instrumentation/cdu/ident/engines", "EV Motor");

var isInternalView = func(){ #// return 1 if is in internal view, otherwise return 0.
    return props.getNode("sim/current-view/internal", 1).getValue();
}

var Sound = {
    new: func(filename, volume = 1, path=nil) {
        var m = props.Node.new({
            path : path,
            file : filename,
            volume : volume,
        });
        return m;
     },
};

var playAudio = func(file){ #//Plays audio files in Aircrafts/Sounds
    fgcommand("play-audio-sample", Sound.new(filename: file, volume: 1, path: props.getNode("/",1).getValue("sim/aircraft-dir") ~ '/Sounds'));
}

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
var beacon = aircraft.light.new( "/sim/model/lights/indicator-left", [0.8, 0.5], "/controls/lighting/indicator-left");
beacon_switch = props.globals.getNode("controls/switches/indicator-right", 2);
var beacon = aircraft.light.new( "/sim/model/lights/indicator-right", [0.8, 0.5], "/controls/lighting/indicator-right");

props.getNode("/",1).setValue("/controls/lighting/indicator-left", 0);
props.getNode("/",1).setValue("/controls/lighting/indicator-right", 0);

props.getNode("/",1).setValue("services/service-truck/enable", 0);
props.getNode("/controls/is-recharging", 1).setValue(0);
props.getNode("systems/welcome-message", 1).setValue(0);
props.getNode("systems/display-speed", 1).setValue(0);
props.getNode("systems/speedometer/type", 1).setValue("Type_A");
props.getNode("systems/battery-gauge/type", 1).setValue("Type_A");
props.getNode("systems/plate/file", 1).setValue("NONE");
props.getNode("systems/plate/name", 1).setValue("NONE");
props.getNode("controls/lighting/headlight-als", 1).setValue(0);
props.getNode("sim/remote/pilot-callsign", 1).setValue("");
props.getNode("/systems/codriver-enable", 1).setValue(0);
props.getNode("systems/screen-enable", 1).setValue(0);
props.getNode("systems/interior/type", 1).setValue("Default");

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
        me.falseLight = 1;
        if(me.mode == 1 or me.mode == 2 or me.mode == 4 or me.mode == 5){
           print("falseLight mode on");
        }else{
            me.setMode(3);
            print("falseLight turned on");
        }

    },
    falseLightOff : func(){
        me.falseLight = 0;
        if(me.mode == 1 or me.mode == 2 or me.mode == 4 or me.mode == 5){
           print("falseLight mode off");
        }else{
            me.setMode(0);
            print("falseLight turned off");
        }
    },
    false_light_toggle : func(){
        if(isInternalView()) playAudio('IndicatorEnd.wav');
        if(me.falseLight == 0){
            me.falseLightOn();
        }else if(me.falseLight == 1){
            me.falseLightOff();
        }
    },
};

var indicatorController = IndicatorController.new();

var toggleHandBrake = func(){
    if(isInternalView()) playAudio("electric_handbrake.wav");
    var handBrake = props.getNode("/controls/gear/brake-parking", 1);
    if(!handBrake.getValue()){
        handBrake.setValue(1);
    }else{
        handBrake.setValue(0);
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




var brakesABS = func(){
    var gearFrtLftSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/wheel-speed-fps"));
    var gearFrtRgtSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[1]/wheel-speed-fps"));
    var gearBckLftSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[2]/wheel-speed-fps"));
    var gearBckRgtSpeed = math.round(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[3]/wheel-speed-fps"));
    if(gearFrtLftSpeed == 0 or gearBckLftSpeed == 0 or gearFrtRgtSpeed == 0 or gearBckRgtSpeed == 0){
        props.getNode("/",1).setValue("/controls/gear/brake-left", 0);
        props.getNode("/",1).setValue("/controls/gear/brake-right", 0);
    }else{
        props.getNode("/",1).setValue("/controls/gear/brake-left", 1);
        props.getNode("/",1).setValue("/controls/gear/brake-right", 1);
    }
}

var absTimer = maketimer(0.001, brakesABS);

var brakeWithABS = func(){ #//Doesn't seems to work because it seems that jsbsim wheels never overbrake?
    var brakeCmd = props.getNode("/",1).getValue("/controls/gear/brake-cmd");
    if(brakeCmd){
        absTimer.start();
    }else{
        absTimer.stop();
    }
}

#setlistener("/controls/gear/brake-cmd", brakeWithABS);
