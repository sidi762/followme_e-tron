#//Auto hold system by Sidi Liang
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
                workingNode.setValue(1);
            }else{
                stopAndSwitchToParking();
            }
        }else if(!math.round(currentSpeed)){
            followme.brakeController.applyBrakes(0);
            working = 0;
            workingNode.setValue(0);
        }
    }
}
var stopAndSwitchToParking = func(){
    followme.brakeController.applyBrakes(0);
    working = 0;
    workingNode.setValue(0);
    followme.brakeController.enableHandBrake();
}

var autoHoldTimer = maketimer(0.05,autoHoldMainLoop);

var startAutoHold = func(){
    autoHoldTimer.start();
    active = 1;
    activeNode.setValue(1);
}

var stopAutoHold = func(){
    active = 0;
    activeNode.setValue(0);
    autoHoldTimer.stop();
    currentSpeed = speedNode.getValue();
    if(followme.brakeController.applyingFeetBrake){
        working = 0;
        workingNode.setValue(0);
        followme.brakeController.applyBrakes(0);
    }else if(!math.round(currentSpeed)){
        stopAndSwitchToParking();
    }
}


var toggleAutoHold = func(){
    if(!autoHoldTimer.isRunning) startAutoHold();
    else stopAutoHold();
}
