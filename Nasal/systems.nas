####    Follow Me   ####
####    Gijs de Rooy (Original)    ####
####    Sidi Liang    ####

#// This program is free software: you can redistribute it and/or modify
#// it under the terms of the GNU General Public License as published by
#// the Free Software Foundation, either version 2 of the License, or
#// (at your option) any later version.

#// This program is distributed in the hope that it will be useful,
#// but WITHOUT ANY WARRANTY; without even the implied warranty of
#// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#// GNU General Public License for more details.

#// You should have received a copy of the GNU General Public License
#// along with this program.  If not, see <https://www.gnu.org/licenses/>.

io.include("library.nas");

# GUI
props.getNode("/sim/gui/dialogs/vehicle_config/dialog",1);
var configDialog = gui.Dialog.new("/sim/gui/dialogs/vehicle_config/dialog", "Aircraft/followme_e-tron/gui/dialogs/config-dialog.xml");

# Tyre Smoke
var tyreSmoke_0 = aircraft.tyresmoke.new(0, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_1 = aircraft.tyresmoke.new(1, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_2 = aircraft.tyresmoke.new(2, auto = 1, diff_norm = 0.4, check_vspeed = 0);
var tyreSmoke_3 = aircraft.tyresmoke.new(3, auto = 1, diff_norm = 0.4, check_vspeed = 0);

# Doors setup
var frontleft_door = aircraft.door.new("/controls/doors/frontleft", 1);
frontleft_door.informationNode = vInfo.controls.doors.FL;
frontleft_door.doorNum = "1";
var frontright_door = aircraft.door.new("/controls/doors/frontright", 1);
frontright_door.informationNode = vInfo.controls.doors.FR;
frontright_door.doorNum = "2";
var rearleft_door = aircraft.door.new("/controls/doors/rearleft", 1);
rearleft_door.informationNode = vInfo.controls.doors.RL;
rearleft_door.doorNum = "3";
var rearright_door = aircraft.door.new("/controls/doors/rearright", 1);
rearright_door.informationNode = vInfo.controls.doors.RR;
rearright_door.doorNum = "4";

var charging_cap = aircraft.door.new("/controls/doors/charging_cap", 1);
charging_cap.doorNum = 0;
charging_cap.informationNode = vInfo.controls.doors.charging_cap;

aircraft.door.toggle = func(){
    var pos = me.getpos();
    me.informationNode.setValue(1 - me.getpos());
    if(pos == 0){
        me.open();
        if(me.doorNum) playAudio(file: 'door_open.wav', queue: 'fx_door_'~me.doorNum);
    }
    if(pos == 1){
        me.close();
        if(me.doorNum) playAudio(file: 'door_shut.wav', queue: 'fx_door_'~me.doorNum);
    }
}

# Keep the driver switch position when the accessory bus loses power.
# The passenger aircraft also loads this file and has no local battery model.
var poweredAuxSwitch = func(path) {
    var request = props.globals.getNode(path, 1);
    var output = request.getNode("powered", 1);
    var bus = props.globals.initNode("/systems/electrical/e-tron/aux-bus-powered", 1, "BOOL");
    var refresh = func { output.setBoolValue(request.getBoolValue() and bus.getBoolValue()); };
    setlistener(request, refresh);
    setlistener(bus, refresh, 1);
    return output;
};

# Wiper
io.include("systems/wiper.nas");
frontWiper = wiper.new("/controls/wiper/frontwiper");

# Lights
io.include("systems/lights.nas");
var indicatorController = IndicatorController.new();

# Brakes
io.include("systems/brakes.nas");
var brakeController = BrakeController.new();

# External service-truck charger, kW delivered to the pack.
var chargerPowerKW = 240;
var chargeBatteryStop = func {
    vInfo.electrical.isRecharging.setValue(0);
    screen.log.write("Recharge Stopped", 0, 0.584, 1);
    setprop("/sim/sound/voices/pilot", "Recharge Stopped. Have a nice ride!");
};

var updateCharging = func(dt) {
    if (!supplyCableConnected or powerState != "off") {
        chargeBatteryStop();
        return;
    }
    cSource.addToBattery(chargerPowerKW * dt);
    if (cSource.remaining >= cSource.electricalCapacity) {
        chargeBatteryStop();
        screen.log.write("Battery is Successfully recharged!", 0, 0.584, 1);
    }
};

# The charge button toggles a session. Settle the old state at the time of the click.
var chargeBatteryStart = func {
    var wasCharging = vInfo.electrical.isRecharging.getValue();
    updateElectrical();
    if (wasCharging) {
        if (vInfo.electrical.isRecharging.getValue()) chargeBatteryStop();
        return;
    }
    var message = "";
    if (!getprop("/services/service-truck/connect")) {
        message = "Cannot recharge. Call service truck and connect the cable first.";
    } elsif (powerState != "off") {
        message = "Cannot recharge. Shut down the engine first.";
    } elsif (cSource.remaining >= cSource.electricalCapacity) {
        message = "Battery is fully charged.";
    } else {
        var minutes = (cSource.electricalCapacity - cSource.remaining) / chargerPowerKW / 60;
        message = sprintf("Recharging. About %.0f mins remaining.", minutes);
        vInfo.electrical.isRecharging.setValue(1);
    }
    screen.log.write(message, 0, 0.584, 1);
    setprop("/sim/sound/voices/pilot", message);
};

# Parking Radar
#//Rear: covers the 1.5 m bumper and widens to 3 m at the 3 m range
var parkingRadar = Radar.new(height: 0.3, installCoordX: 0, installCoordY: 3.8, maxRange: 3, maxWidth: 3,
    baseWidth: 1.5, updateInterval: 0.1, reportSectors: 1);
#//Front: shorter range, with the higher front tone recorded from an Audi A4L B8 (no long sample, so it
#//repeats the beep when close) on its own queue so that both ends can sound together
var frontParkingRadar = Radar.new(height: 0.3, installCoordX: 0, installCoordY: 0, maxRange: 1.2, maxWidth: 2,
    baseWidth: 1.4, orientationMode: 180, updateInterval: 0.1, beepSound: "parking_radar_high.wav",
    continuousSound: "parking_radar_high.wav", continuousDistance: 0.3, audioQueue: "fx_radar_front",
    reportSectors: 1);
var isParkingRadarActive = Variable.new("isParkingRadarActive", 0, "Indicates the status of the parking radar", 0, 1, 0, "/systems/isParkingRadarActive");
var parkingAssist = ParkingAssist.new(parkingRadar, frontParkingRadar, isParkingRadarActive);
var toggleParkingRadar = func(){
    parkingAssist.toggle();
}

# Safety System
io.include("systems/safety.nas");
var safety = Safety.new(140, 75);

# Magic bush tyres
var reduceRollingFriction = func(){
    print("rolling_friction-coeff reduced to 0.006");
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit/rolling_friction_coeff", 0.006);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[1]/rolling_friction_coeff", 0.006);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[2]/rolling_friction_coeff", 0.006);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[3]/rolling_friction_coeff", 0.006);
}
var resumeRollingFriction = func(){
    print("rolling_friction-coeff resumed to 0.06");
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit/rolling_friction_coeff", 0.06);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[1]/rolling_friction_coeff", 0.06);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[2]/rolling_friction_coeff", 0.06);
    props.getNode("/",1).setValue("/fdm/jsbsim/gear/unit[3]/rolling_friction_coeff", 0.06);
}

# Service Staion
io.include("service.nas");
#var stationPath = getprop("sim/aircraft-dir")~'/Models/Service-Station/Service-Staion.ac';
#var stationCoord = geo.aircraft_position();
#var stationCourse = getprop("/orientation/heading-deg");
#stationCoord.apply_course_distance(stationCourse, 100); # Model to be added 100 m ahead
#var model = geo.put_model(stationPath, stationCoord, stationCourse); # Place the default glider

# Testing
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

# Others
var resetOnPosition = func(){
    var lat = props.getNode("/position/latitude-deg").getValue();
    var lon = props.getNode("/position/longitude-deg").getValue();
    #// Clear the other presets to prevent issues
    props.getNode("/sim/presets/carrier", 1).setValue("");
    props.getNode("/sim/presets/parkpos", 1).setValue("");
    props.getNode("/sim/presets/airport-id", 1).setValue("");
    props.getNode("/sim/presets/runway", 1).setValue("");
    props.getNode("/sim/presets/runway-requested", 1).setValue(0);
    props.getNode("/sim/presets/altitude-ft", 1).setValue("-9999");
    props.getNode("/sim/presets/airspeed-kt", 1).setValue(0);
    #// Set the latlon in the presets
    props.getNode("/sim/presets/latitude-deg", 1).setValue(lat);
    props.getNode("/sim/presets/longitude-deg", 1).setValue(lon);
    fgcommand("reposition");

    #//The old method, kept for educational purposes
    #//var groundAlt = props.getNode("/position/ground-elev-ft").getValue();
    #//setprop("/fdm/jsbsim/simulation/reset", 1); #This will position the aircraft back to the initial spawn point
    #//props.getNode("/position/altitude-ft").setValue(groundAlt+7);
    #latProp.setValue(lat);
    #lonProp.setValue(lon);
}
