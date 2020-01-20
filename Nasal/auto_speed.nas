#//Auto speed system by Sidi Liang
print("Auto speed system loaded");
var active = 0;
var targetSpeed = 0;
var mode = 1;#//1:Hold 2:Auto Speed
var leftBrakes = props.getNode("/controls/gear/brake-left",1);
var rightBrakes = props.getNode("/controls/gear/brake-right",1);
var throttleNode = props.getNode("/controls/engines/engine/throttle",1);

var autoSpeedMainLoop = func(){
    if(leftBrakes.getValue() == 1 or rightBrakes.getValue() == 1 or throttleNode.getValue() == 1){  #//Stop if full brakes or full throttle are manually applied
        stopAutoSpeed();
    }
    var currentSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
    var deltaSpeed = targetSpeed - currentSpeed;
    var throttle = 0;
    var brakes = 0; #//range from 0 to 1;
    if(deltaSpeed > 0){
        throttle = deltaSpeed/targetSpeed - 0.05; #// Max throttle 0.95
    }else if(deltaSpeed <= -1.852){
        throttle = 0;
        brakes = ((0 - deltaSpeed) / targetSpeed) - 0.2; #// Max brake 0.8
    }else{
        throttle = 0;
    }
    throttleNode.setValue(throttle);
    leftBrakes.setValue(brakes);
    rightBrakes.setValue(brakes);
}

var autoSpeedTimer = maketimer(0.05,autoSpeedMainLoop);

var startAutoSpeed = func(){
    autoSpeedTimer.start();
    active = 1;
}

var stopAutoSpeed = func(){
    autoSpeedTimer.stop();
    props.getNode("/sim/messages/copilot",1).setValue("ze dong chao sue see tong yee guan bee. Auto Speeding System is off.");
    active = 0;
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