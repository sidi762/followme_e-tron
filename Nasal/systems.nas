####    Follow Me   ####
####    Gijs de Rooy    ####

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

props.getNode("/",1).setValue("/systems/horn", 0);
props.getNode("/",1).setValue("/controls/mode", 1);

var frontleft_door = aircraft.door.new("/controls/doors/frontleft", 1);
var frontright_door = aircraft.door.new("/controls/doors/frontright", 1);
var rearleft_door = aircraft.door.new("/controls/doors/rearleft", 1);
var rearright_door = aircraft.door.new("/controls/doors/rearright", 1);

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
    
    currentMessage: "",
    
    textureRight: "Messages/right.png",
    
    textureLeft: "Messages/left.png",
    
    saveLedMessage: func(){
        me.currentMessage = me.ledMessage.getValue();
    },
    
    getSavedMessage: func(){
        return me.currentMessage;
    },
    
    clearSavedMessage: func(){
        me.currentMessage = "";
    },
    
    setLedMessage: func(content){
        me.ledMessage.setValue(content);
    },
    
    resumeLedMessage: func(){
        if(me.getSavedMessage()){
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
        if(me.getMode() != 4){
            me.setMode(4);
        }else if(me.getMode() == 4){
            me.setMode(0);
        }
    },
    
    left_indicator_toggle : func(){
        if(me.getMode() != 5){
            me.setMode(5);
        }else if(me.getMode() == 5){
            me.setMode(0);
        }
    },
    
    falseLightOn : func(){
        print("falseLight turned on");
        me.falseLight = 1;
        me.setMode(3);
    },
    
    falseLightOff : func(){
        print("falseLight turned off");
        me.falseLight = 0;
        me.setMode(0);
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



var chargeBatterySec = func(){
    var battery = props.getNode("/systems/electrical/e-tron/battery-kWs");
    var currentBattery = battery.getValue();
    if(currentBattery >= 288000){
        screen.log.write("Battery is Successfully recharged!", 0, 0.584, 1);
        chargeBatteryStop();
    }
    battery.setValue(currentBattery+240);
}
var chargeTimer = maketimer(1, chargeBatterySec);
var chargeBatteryStart = func(){
    if(!props.getNode("/controls/is-recharging", 1).getValue()){
        if(props.getNode("/",1).getValue("services/service-truck/connect") == 1 and props.getNode("/",1).getValue("/controls/engines/engine/started") == 0){
            var deltaBattery = 288000-props.getNode("/systems/electrical/e-tron/battery-kWs").getValue();
            var remainingTime = sprintf("%.0f", (deltaBattery / 240) / 60);      #Based on 20 mins from 0 to full
            #screen.log.write("Recharging. About "~remainingTime~" mins remaining.", 0, 0.584, 1);
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
        chargeBatteryStop();
    }
}

var chargeBatteryStop = func(){
   chargeTimer.stop();
   screen.log.write("Recharge Stopped", 0, 0.584, 1);
   setprop("/sim/sound/voices/pilot", "Recharge Stopped. Have a nice ride!");
   props.getNode("/controls/is-recharging", 1).setValue(0);
}



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

var brakeWithABS = func(){# Seems to have bugs
    var brakeCmd = props.getNode("/",1).getValue("/controls/gear/brake-cmd");
    if(brakeCmd){
        absTimer.start();
    }else{
        absTimer.stop();
    }
}

#setlistener("/controls/gear/brake-cmd", brakeWithABS);

