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

props.getNode("/",1).setValue("/systems/horn",0);

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


