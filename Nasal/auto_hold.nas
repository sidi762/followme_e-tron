#//Auto hold system by Sidi Liang
#//Contact: sidi.liang@gmail.com

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

print("Auto hold system loaded");
var active = 0;
var activeNode = props.getNode("systems/auto_hold_enabled", 1);
var working = 0;
var workingNode = props.getNode("systems/auto_hold_working", 1);
var targetSpeed = 0;
var throttleNode = props.getNode("/controls/engines/engine/throttle",1);
var speedNode = props.getNode("sim/multiplay/generic/float[15]", 1);
var engineNode = props.getNode("/controls/engines/engine/started",1);
var door1 = followme.frontleft_door;
var door2 = followme.frontright_door;
var door3 = followme.rearleft_door;
var door4 = followme.rearright_door;
var autoHoldMainLoop = func(){
    if(active){
        throttle = throttleNode.getValue();
        currentSpeed = speedNode.getValue();
        if(!throttle and !math.round(currentSpeed)){
            if(!door1.getpos() and !door2.getpos() and !door3.getpos() and !door4.getpos() and engineNode.getValue()){
                followme.brakeController.applyBrakes(1);
                working = 1;
                workingNode.setIntValue(1);
            }else{
                stopAndSwitchToParking();
            }
        }else if(!math.round(currentSpeed)){
            followme.brakeController.applyBrakes(0);
            working = 0;
            workingNode.setIntValue(0);
        }
    }
}
var stopAndSwitchToParking = func(){
    followme.brakeController.applyBrakes(0);
    working = 0;
    workingNode.setIntValue(0);
    followme.brakeController.enableHandBrake();
}

var autoHoldTimer = maketimer(0.05,autoHoldMainLoop);

var startAutoHold = func(){
    autoHoldTimer.start();
    active = 1;
    activeNode.setIntValue(1);
}

var stopAutoHold = func(){
    active = 0;
    activeNode.setIntValue(0);
    autoHoldTimer.stop();
    currentSpeed = speedNode.getValue();
    if(followme.brakeController.applyingFeetBrake){
        working = 0;
        workingNode.setIntValue(0);
        followme.brakeController.applyBrakes(0);
    }else if(!math.round(currentSpeed)){
        stopAndSwitchToParking();
    }
}


var toggleAutoHold = func(){
    if(!autoHoldTimer.isRunning) startAutoHold();
    else stopAutoHold();
}
