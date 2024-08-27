####    Follow Me EV Safety System   ####
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

var Safety = {
    new: func(airbagAccelerationLimit=140, sideAirbagAccelerationLimit=75){
        var newSafety = { parents:[Safety] };
        newSafety.airbagAccelerationLimit = airbagAccelerationLimit;
        newSafety.sideAirbagAccelerationLimit = sideAirbagAccelerationLimit;
        newSafety.frontRadar = Radar.new(0.3, 0, 0, 15, 0.1, 180, 0, 0.001);#For AEB
        newSafety.absTimer = maketimer(0.001, brakesABS);
        newSafety.aebTimer = maketimer(0.001, func newSafety.aebUpdate());
        return newSafety;
    },
    isOn: 0,
    isEnabled: 1,
    safetySystemTimer: nil,
    updateInterval: 0.01,
    aebEnabled: 0,
    aebActivated: 0,
    lastRadarOutput:10000,
    throttleNode: vInfo.engine.throttleNode,
    emergencyModeState: 0,
    #Airbag
    accXProp: props.getNode("/fdm/jsbsim/accelerations/a-pilot-x-ft_sec2", 1),
    accYProp: props.getNode("/fdm/jsbsim/accelerations/a-pilot-y-ft_sec2", 1),
    frontAirbagProp: props.getNode("/systems/safety/airbag/front", 1),
    sideAirbagProp: props.getNode("/systems/safety/airbag/side", 1),
    aebStateProp: props.getNode("/systems/safety/aeb_activated", 1),
    aebOnProp: props.getNode("/systems/safety/aeb_on", 1),
    airbagAccelerationLimit: 140, #To be configured,m/s^2
    sideAirbagAccelerationLimit: 75, #To be configured,m/s^2

    #Frontwards radar
    frontRadar: nil,

    enableAEB: func(){
        #Enables the front radar
        me.aebTimer.start();
        me.aebEnabled = 1;
        me.frontRadar.initWithoutStarting();
        #//me.frontRadar.stop();
        me.aebOnProp.setIntValue(1);
        print("AEB enabled");
    },
    disableAEB: func(){
        #Disables the front radar
        me.aebTimer.stop();
        if(me.aebEnabled) me.frontRadar.stop();
        me.aebEnabled = 0;
        me.aebOnProp.setIntValue(0);
        print("AEB disabled");
    },
    toggleAEB: func(){
        if(!me.aebEnabled){
            me.enableAEB();
            playAudio(file: "parking_radar_init.wav", queue: "fx_aeb");
        }
        else me.disableAEB();
    },

    aebThreshold: 9,
    aebFullThreshold: 8,
    aebMode: 1, #//1: slow mode 2: fast mode
    aebCount: 0,
    aebSlowMode: func(){
        me.frontRadar.maxRange = 10;
        #me.frontRadar.maxWidth = 0.1;
        me.aebThreshold = 10;
        me.aebFullThreshold = 10;
        me.aebMode = 1;
        print("AEB Slow Mode");
    },
    aebFastMode: func(){
        me.frontRadar.maxRange = 20;
        #me.frontRadar.maxWidth = 0.05;
        me.aebThreshold = 20;
        me.aebFullThreshold = 16;
        me.aebMode = 2;
        print("AEB Fast Mode");
    },
    aebJudge: func(){
        if(me.frontRadar.radarOutput <= me.aebThreshold and !me.aebActivated) return 1;
        else return 0;
    },
    aebActive: func(){
        me.aebActivated = 1;
        #engine.engine_1.engineSwitch.switchDisconnect();
        brakeController._applyBrakes(0.8);#//Pre brake
        me.throttleNode.setValue(0);
        me.aebWarning();
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
    aebWarning: func(){
        playAudio(file: "parking_radar_high.wav", queue: "fx_aeb");
        playAudio(file: "parking_radar_high.wav", queue: "fx_aeb");
        playAudio(file: "parking_radar_high.wav", queue: "fx_aeb");
    },
    aebFullBrake: func(){
        brakeController.activeEmergencyBrake();
        #playAudio("parking_radar_high.wav");
        print("AEB Full Brake Activated!");
    },

    aebUpdate: func(){
        #//AEB Loop

        var currentSpeed = vInfo.getSpeedKMH();#In km/h
        var radarOutput = me.frontRadar.radarOutput;
        #print("radar output: " ~ radarOutput);
        #print("last radar output: " ~ me.lastRadarOutput);
        if(me.lastRadarOutput <= radarOutput) me.aebCount += 1;
        else me.aebCount = 0;
        if(radarOutput != 10000) me.lastRadarOutput = radarOutput;
        #var deltaX = me.lastRadarOutput - radarOutput;
        #var reletiveSpeed = 3.6 * (deltaX / me.updateInterval);#In km/h
        #if(reletiveSpeed) print(reletiveSpeed);
        if(currentSpeed > 30 and engine.engine_1.getDirection() == 1){
            #Enable AEB when speed is greater then 30kmh and in D gear
            if(me.aebEnabled){
                if(!me.frontRadar.isRunning) me.frontRadar.start();
                if(currentSpeed >= 48 and me.aebMode == 1) me.aebFastMode();
                else if(currentSpeed < 48 and me.aebMode == 2) me.aebSlowMode();#//Adjust mode dynamically according to speed

                if(me.aebJudge()){
                    me.aebActive();
                    if(me.frontRadar.radarOutput <= me.aebFullThreshold){ #//Phase two of braking
                        me.aebFullBrake();
                    }
                }

                if(me.aebActivated){
                    #if(currentSpeed <= 0 or me.aebCount >= 10) me.aebStop();
                    if(currentSpeed <= 0){
                        me.aebStop();
                        #print("1");
                    }else if(me.aebCount >= 15){
                        me.aebStop();
                        #print("2");
                    }
                }
            }
        }else{
            if(me.aebActivated){
                if(currentSpeed <= 0){
                    me.aebStop();
                    #print("11");
                }else if(me.aebCount >= 15){
                    me.aebStop();
                    #print("22");
                }
            }
            if(me.aebEnabled and me.frontRadar.isRunning) me.frontRadar.stop();
        }
    },

    update: func(){
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
        #AEB, Automatic Emergency Brake
        #Moved out of the main loop

        #ABS
        #var brakeCmd = props.getNode("/",1).getValue("/controls/gear/brake-left");
        #if(brakeCmd and currentSpeed){
        #    me.absTimer.start();
        #}else{
        #    me.absTimer.stop();
        #}

    },

    emergencyMode: func(){
        print("Safety system emergency mode!");
        me.emergencyModeState = 1;
        indicatorController.setMode(3); #Active malfunction light
        indicatorController.falseLight = 1;
        if(autospeed.autoSpeedTimer.isRunning) autospeed.stopAutoSpeed();
        if(autopilot.road_check_timer.isRunning) autopilot.road_check_timer.stop();
    },
    disableEmergencyMode: func(){
        print("Safety system emergency mode disabled!");
        me.emergencyModeState = 0;
        indicatorController.falseLight = 0;
        indicatorController.setMode(0); #Deactive malfunction light
    },

    reset: func(){
        #resetting stops and disables the safety system
        me.stop();
        me.isEnabled = 0;
        me.frontAirbagProp.setValue(0);
        me.sideAirbagProp.setValue(0);
        me.aebStateProp.setValue(0);
    },
    init: func(){
        #initialize or reinitialize (which re-enables the system if disabled earlier)
        me.frontAirbagProp.setValue(0);
        me.sideAirbagProp.setValue(0);
        me.aebStateProp.setValue(0);
        if(me.safetySystemTimer == nil) me.safetySystemTimer = maketimer(me.updateInterval, func me.update());
        me.safetySystemTimer.start();
        #if(me.aebEnabled) me.enableAEB();
        me.isEnabled = 1;
        me.isOn = 1;
        print("Safety system initialized");
    },
    stop: func(){
        me.isOn = 0;
        me.aebStateProp.setValue(0);
        if(me.aebEnabled) me.disableAEB();
        me.safetySystemTimer.stop();
        print("Safety system stoped");
    },
    toggle: func(){
        if(!me.isOn) me.init();
        else me.stop();
    },
};