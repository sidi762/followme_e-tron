#//Auto speed system by Sidi Liang
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

print("Auto speed system loaded");
var active = 0;
var targetSpeed = 0;
var mode = 1;#//1:Hold 2:Auto Speed
var leftBrakes = props.getNode("/controls/gear/brake-left",1);
var rightBrakes = props.getNode("/controls/gear/brake-right",1);
var throttleNode = props.getNode("/controls/engines/engine/throttle",1);
var lastDeltaSpeed = 0;

var autoSpeedMainLoop = func(){
    if(leftBrakes.getValue() >= 0.8 or rightBrakes.getValue() >= 0.8 or throttleNode.getValue() == 1){  #//Stop if full brakes or full throttle are manually applied
        throttleNode.setValue(0);
        stopAutoSpeed();
    }
    var currentSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
    var deltaSpeed = targetSpeed - currentSpeed;
    var throttle = 0;
    var brakes = 0; #//range from 0 to 1;
    if(deltaSpeed > 0){
        throttle = calculateThrottle(deltaSpeed / targetSpeed); #// Max throttle 0.9
    }else if(deltaSpeed <= -1.852){
        throttle = 0;
        brakes = ((0 - deltaSpeed) / targetSpeed) - 0.21; #// Max brake 0.79
    }else{
        throttle = 0;
    }
    if(active) throttleNode.setValue(throttle);
    else throttleNode.setValue(0);
    leftBrakes.setValue(brakes);
    rightBrakes.setValue(brakes);
    lastDeltaSpeed = deltaSpeed;
}

var calculateThrottle = func(x){
    return x/(x+0.1);
}

var autoSpeedTimer = maketimer(0.05,autoSpeedMainLoop);

var startAutoSpeed = func(){
    autoSpeedTimer.start();
    active = 1;
}

var stopAutoSpeed = func(){
    active = 0;
    autoSpeedTimer.stop();
    props.getNode("/sim/messages/copilot",1).setValue("ze dong chao sue see tong yee guan bee. Auto Speeding System is off.");
    throttleNode.setValue(0);
}


var toggleAutoSpeed = func(){
    if(!autoSpeedTimer.isRunning)
    {
        mode = 2;
        startAutoSpeed();
        props.getNode("/sim/messages/copilot",1).setValue("ze dong chao sue see tong yee tse yung. Auto Speeding System Activated!");
    }
    else
    {
        stopAutoSpeed();
    }
}

var toggleSpeedHold = func(){
    if(!autoSpeedTimer.isRunning)
    {
        mode = 1;
        startAutoSpeed();
        targetSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
        props.getNode("/sim/messages/copilot",1).setValue("bao chie chao sue see tong yee tse yung. Keep Speeding System Activated! Target Speed: "~sprintf("%.1f", targetSpeed*1.852));
    }
    else
    {
        stopAutoSpeed();
    }
}
var targetSpeedChange = func(speed){
    if(autoSpeedTimer.isRunning){
        autoSpeedTimer.stop();
        targetSpeed = speed;
        autoSpeedTimer.start();
        return 0;
    }
    targetSpeed = speed;
}
