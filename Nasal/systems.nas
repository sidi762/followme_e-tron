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

# Wiper
io.include("systems/wiper.nas");
frontWiper = wiper.new("/controls/wiper/frontwiper");

# Lights
io.include("systems/lights.nas");
var indicatorController = IndicatorController.new();

# Brakes
io.include("systems/brakes.nas");
var brakeController = BrakeController.new();

# Recharge (Todo: Implement a better system)
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

# Parking Radar
var parkingRadar = Radar.new(0.3, 0, 3.8, 3, 3);
var isParkingRadarActive = Variable.new("isParkingRadarActive", 0, "Indicates the status of the parking radar", 0, 1, 0, "/systems/isParkingRadarActive");
var toggleParkingRadar = func(){
    parkingRadar.toggle();
    isParkingRadarActive.setValue(parkingRadar.isRunning);
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
