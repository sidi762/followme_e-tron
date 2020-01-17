#//Auto speed system by Sidi Liang
print("Auto speed system loaded");
var active = 0;
var targetSpeed = 0;
var autoSpeedMainLoop = func(){
    var currentSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
    var deltaSpeed = targetSpeed - currentSpeed;
    var throttle = 0;
    var brakes = 0; #//range from 0 to 1;
    if(deltaSpeed > 0){
        throttle = deltaSpeed / targetSpeed;
    }else if(deltaSpeed <= -1.852){
        throttle = 0;
        brakes = (0 - deltaSpeed) / targetSpeed;
    }else{
        throttle = 0;
    }
    props.getNode("/",1).setValue("/controls/engines/engine/throttle", throttle);
    props.getNode("/",1).setValue("/controls/gear/brakes-left", brakes);
    props.getNode("/",1).setValue("/controls/gear/brakes-right", brakes);
}

var autoSpeedTimer = maketimer(0.05,autoSpeedMainLoop);

var startAutoSpeed = func(){
    autoSpeedTimer.start();
    active = 1;
}

var stopAutoSpeed = func(){
    autoSpeedTimer.stop();
    active = 0;
}


var toggleAutoSpeed = func(){
    if(!autoSpeedTimer.isRunning)
    {
        startAutoSpeed();
        props.getNode("/sim/messages/copilot",1).setValue("ze dong chao sue see tong yee tse yung. Auto Speeding System Activated!");
    }
    else
    {
        stopAutoSpeed();
        props.getNode("/sim/messages/copilot",1).setValue("ze dong chao sue see tong yee guan bee. Auto Speeding System is off.");
    }
}

var toggleSpeedHold = func(){
    if(!autoSpeedTimer.isRunning)
    {
        startAutoSpeed();
        targetSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
        props.getNode("/sim/messages/copilot",1).setValue("bao chie chao sue see tong yee tse yung. Keep Speeding System Activated! Target Speed: "~sprintf("%.1f", targetSpeed*1.852));
    }
    else
    {
        stopAutoSpeed();
        props.getNode("/sim/messages/copilot",1).setValue("bao chie chao sue see tong yee guan bee. Keep Speeding System is off.");
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