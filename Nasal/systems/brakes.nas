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
    new: func() { return { parents:[BrakeController]}; },
    leftBrakeNode: props.getNode("/controls/gear/brake-left",1),
    rightBrakeNode: props.getNode("/controls/gear/brake-right",1), # These are the rear brakes since the last FDM update
    parkingBrakeNode: props.getNode("/controls/gear/brake-parking",1),

    applyingFeetBrake: 0,
    _handBrakeIsOn: 0,
    _manualHandBrakeIsPulled: 0,
    leftBrakeValue: 0,
    rightBrakeValue: 0,
    
    #//Decides how much brakings to be applied, can be adjusted via GUI and defaults to be 0.8
    keyboardBrakeIntensity: Variable.new("keyboardBrakeIntensity", 0.8, 
                                          "Braking Intensity when using s key", 
                                          0, 1, 1, 
                                          "/systems/BrakeController/keyboardBrakeIntensity"), 

    _applyLeftBrake: func(value){
        # For internal use
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
    },
    _applyRightBrake: func(value){
        # For internal use
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
    },
    _applyBrakes: func(value){
        # For internal use
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
    },
    applyBrakes: func(value){
        me._applyBrakes(value);
    },
    applyFeetBrakes: func(value){
        # For feet brakes
        if(value) me.applyingFeetBrake = 1;
        else me.applyingFeetBrake = 0;
        me.rightBrakeNode.setValue(value);
        me.rightBrakeValue = value;
        me.leftBrakeNode.setValue(value);
        me.leftBrakeValue = value;
        # Double blink when applying full brakes, should look for a better solution
        if(value == 1) settimer(func{if(me.applyingFeetBrake) safety.emergencyMode();}, 0.6);
    },

    manualHandBrakePull: func(){
        me._manualHandBrakeIsPulled = 1;
        # Right Brakes are the rear brakes since the last FDM update
        me._applyRightBrake(1); 
    },

    manualHandBrakeRelease: func(){
        me._manualHandBrakeIsPulled = 0;
        # Right Brakes are the rear brakes since the last FDM update
        me._applyRightBrake(0);
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
        me._applyLeftBrake(1);
        me._applyRightBrake(1);
        me.enableHandBrake();
        safety.emergencyMode();
    },
    keyboardBrake: func(){
        me.applyFeetBrakes(me.keyboardBrakeIntensity.getValue());
    },
    keyboardBrakeRelease: func(){
        me.applyFeetBrakes(0);
        if(vInfo.getSpeedKMH() > 10 and safety.emergencyModeState) safety.disableEmergencyMode();
    },
    releaseBrake: func(){
        me._applyLeftBrake(0);
        me._applyRightBrake(0);
    },
    releaseAllBrakes: func(){
        me._applyLeftBrake(0);
        me._applyRightBrake(0);
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
