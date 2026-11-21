####    Follow Me EV Braking System   ####
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

var BrakeController = {
	new: func() {
		var controller = {parents: [BrakeController]};
		foreach (var pedal; [controller.leftBrakeNode, controller.rightBrakeNode]) {
			setlistener(pedal, func { controller.updateBrakeOutputs(); }, 0, 0);
		}
		controller.updateBrakeOutputs();
		return controller;
	},
	leftBrakeNode: props.getNode("/controls/gear/brake-left", 1),
	rightBrakeNode: props.getNode("/controls/gear/brake-right", 1),
	parkingBrakeNode: props.getNode("/controls/gear/brake-parking", 1),
	autoBrake: props.getNode("/autopilot/autobrake", 1),
	pedalPressed: props.getNode("/systems/BrakeController/pedal-pressed", 1),
	pedalPosition: props.getNode("/systems/BrakeController/pedal-position-norm", 1),
	frontBrakeOutput: props.getNode("/systems/BrakeController/front-brake-output", 1),
	applyingFeetBrake: 0,
	_handBrakeIsOn: 0,
	_manualHandBrakeIsPulled: 0,
	aebDemand: 0,
	holdDemand: 0,
	cruiseDemand: 0,
	leftBrakeValue: 0,
	rightBrakeValue: 0,

    #//Decides how much brakings to be applied, can be adjusted via GUI and defaults to be 0.8
    keyboardBrakeIntensity: Variable.new("keyboardBrakeIntensity", 0.8, 
                                          "Braking Intensity when using s key", 
                                          0, 1, 1, 
                                          "/systems/BrakeController/keyboardBrakeIntensity"), 

	# FlightGear passes the autobrake outputs to JSBSim while engaged. The pedal
	# nodes remain driver inputs, including joystick axes and the S key.
	updateBrakeOutputs: func() {
		var left = me.leftBrakeNode.getValue();
		var right = me.rightBrakeNode.getValue();
		var automatic = math.max(me.aebDemand, me.holdDemand, me.cruiseDemand);
		me.leftBrakeValue = math.max(left, automatic);
		me.rightBrakeValue = math.max(right, automatic, me._manualHandBrakeIsPulled);
		me.autoBrake.setValue("brake-left-output", me.leftBrakeValue);
		me.autoBrake.setValue("brake-right-output", me.rightBrakeValue);
		me.autoBrake.setValue("engaged", automatic > 0 or me._manualHandBrakeIsPulled);
		me.frontBrakeOutput.setDoubleValue(me.leftBrakeValue);
		# Static Auto Hold maintains wheel pressure with the driver's pedal free to return.
		me.pedalPosition.setDoubleValue(math.max(left, right, me.aebDemand, me.cruiseDemand));
		me.applyingFeetBrake = left > 0 or right > 0;
		me.pedalPressed.setBoolValue(me.applyingFeetBrake);
	},
	applyBrakes: func(value) {
		me.holdDemand = value;
		me.updateBrakeOutputs();
	},
	setCruiseBrakes: func(value) {
		me.cruiseDemand = value;
		me.updateBrakeOutputs();
	},
	setAebBrakes: func(value) {
		me.aebDemand = value;
		me.updateBrakeOutputs();
	},
	applyFeetBrakes: func(value) {
		me.leftBrakeNode.setValue(value);
		me.rightBrakeNode.setValue(value);
        # Double blink when applying full brakes, should look for a better solution
        if(value == 1) settimer(func{if(me.applyingFeetBrake) safety.emergencyMode();}, 0.6);
    },

    manualHandBrakePull: func(){
        me._manualHandBrakeIsPulled = 1;
        # Right Brakes are the rear brakes since the last FDM update
        me.updateBrakeOutputs();
    },

    manualHandBrakeRelease: func(){
        me._manualHandBrakeIsPulled = 0;
        # Right Brakes are the rear brakes since the last FDM update
        me.updateBrakeOutputs();
    },

    _activeHandBrake: func(){
        # for internal use
        me._handBrakeIsOn = 1;
        if(isInternalView()) playAudio("handbrake_on.wav");
        settimer(func(){ #Delay for 0.5 seconds
            me.parkingBrakeNode.setValue(1);
        }, 0.5);
    },
    _deactiveHandBrake: func(){
        # for internal use
        me._handBrakeIsOn = 0;
        if(isInternalView()) playAudio("handbrake_off.wav");
        settimer(func(){ #Delay for 0.5 seconds
            me.parkingBrakeNode.setValue(0);
        }, 0.5);
    },
    enableHandBrake: func(){
        # enable handbrake from button
        if(!me._handBrakeIsOn){
            me._activeHandBrake();
        }
    },
    disableHandBrake: func(){
        # disable handbrake from button
        if(me._handBrakeIsOn){
            me._deactiveHandBrake();
        }
    },
    toggleHandBrake: func(){
        # Toggle handbrake from button
        if(isInternalView()) playAudio("electric_handbrake.wav");
        if(!me._handBrakeIsOn){
            me.enableHandBrake();
        }else{
            me.disableHandBrake();
        }
    },
    activeEmergencyBrake: func(){
        me.setAebBrakes(1);
        safety.emergencyMode();
    },
    keyboardBrake: func(){
        me.applyFeetBrakes(me.keyboardBrakeIntensity.getValue());
    },
    keyboardBrakeRelease: func(){
        me.applyFeetBrakes(0);
        if(vInfo.getSpeedKMH() > 10 and safety.emergencyModeState) safety.disableEmergencyMode();
    },
	releaseAebBrakes: func() {
		me.setAebBrakes(0);
	},
	releaseBrake: func() {
		me.applyBrakes(0);
		me.setCruiseBrakes(0);
		me.applyFeetBrakes(0);
	},
	releaseAllBrakes: func() {
		me.releaseBrake();
		me.disableHandBrake();
	},
    handBrakeIsOn: func(){
        return me._handBrakeIsOn;
    },
    manualHandBrakeIsPulled: func(){
        return me._manualHandBrakeIsPulled;
    },
};

var brakesABS = func(){
    # Does not seems to work since it appears that JSBSim does ABS by default
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
