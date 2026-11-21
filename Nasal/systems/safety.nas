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
        #//For AEB: a corridor as wide as the car straight ahead
        newSafety.frontRadar = Radar.new(height: 0.3, installCoordX: 0, installCoordY: 0, maxRange: 15,
            maxWidth: 1.6, baseWidth: 1.6, orientationMode: 180, warnEnabled: 0, updateInterval: 0.1,
            lateralSamples: 1);
        newSafety.absTimer = maketimer(0.001, brakesABS);
        newSafety.aebTimer = maketimer(0.001, func newSafety.aebUpdate());
		newSafety.aebHoldTimer = maketimer(2, func {
			# Let Auto Hold establish its pressure before removing AEB's contribution.
			autohold.autoHoldMainLoop();
			brakeController.releaseAebBrakes();
		});
		newSafety.aebHoldTimer.simulatedTime = 1;
		newSafety.aebHoldTimer.singleShot = 1;
        return newSafety;
    },
    isOn: 0,
    isEnabled: 1,
    safetySystemTimer: nil,
    updateInterval: 0.01,
    aebEnabled: 0,
    aebActivated: 0,
    lastRadarOutput:10000,
    lastScanCount: 0,
    aebReleaseScans: 3, # Clear or receding scans. Equal range holds the count, closing resets it.
    aebStandstillKmh: 0.5, # Groundspeed can jitter above zero at rest.
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
        if (me.aebActivated or me.aebHoldTimer.isRunning) me.aebStop();
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
        me.aebCount = 0;
        #engine.engine_1.engineSwitch.switchDisconnect();
        if (autospeed.active) autospeed.stopAutoSpeed();
        brakeController.setAebBrakes(0.8);
        me.throttleNode.setValue(0);
        me.aebWarning();
        me.aebStateProp.setValue(1);
        print("AEB Activated!");
    },
    aebStop: func(){
        me.aebHoldTimer.stop();
        me.aebActivated = 0;
        print("AEB Stopped");
        me.aebStateProp.setValue(0);
        #engine.engine_1.engineSwitch.switchConnect();
        brakeController.releaseAebBrakes();
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

	aebUpdate: func() {
		if (!me.aebEnabled or me.aebHoldTimer.isRunning) return;
		var speedKmh = vInfo.getSpeedKMH();
		var forward = engine.engine_1.getDirection() == 1;
		var canStart = forward and speedKmh > 30;
		if (me.aebActivated and forward and speedKmh <= me.aebStandstillKmh) {
			# End the collision alert but retain the existing service brake demand until handoff.
			me.aebHoldTimer.start();
			me.aebActivated = 0;
			me.aebStateProp.setBoolValue(0);
			if (me.frontRadar.isRunning) me.frontRadar.stop();
			return;
		}
		# While still moving, keep scanning below the activation speed until the hazard clears.
		if (!forward or (!canStart and !me.aebActivated)) {
			if (me.aebActivated) me.aebStop();
			if (me.frontRadar.isRunning) me.frontRadar.stop();
			return;
		}

		if (!me.frontRadar.isRunning) me.frontRadar.start();
		if (speedKmh >= 48 and me.aebMode == 1) me.aebFastMode();
		elsif (speedKmh < 48 and me.aebMode == 2) me.aebSlowMode();

		# The AEB loop runs every frame. Each range reading can trigger or release the brakes only once.
		if (me.frontRadar.scanCount == me.lastScanCount) return;
		me.lastScanCount = me.frontRadar.scanCount;
		var distance = me.frontRadar.radarOutput;
		if (me.aebActivated) {
			if (distance > me.lastRadarOutput) me.aebCount += 1;
			elsif (distance < me.lastRadarOutput) me.aebCount = 0;
			if (me.aebCount >= me.aebReleaseScans) me.aebStop();
		} elsif (me.aebJudge()) {
			me.aebActive();
			if (distance <= me.aebFullThreshold) me.aebFullBrake();
		}
		if (distance != 10000) me.lastRadarOutput = distance;
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
        if (me.aebActivated or me.aebHoldTimer.isRunning) me.aebStop();
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
        if (me.aebActivated or me.aebHoldTimer.isRunning) me.aebStop();
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
