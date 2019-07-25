var max_P_KW = 568;
var gearratio = 9.73;
props.getNode("/",1).setValue("/controls/engines/engine/rpm1",1000);
props.getNode("/",1).setValue("/controls/engines/engine/direction",1);
props.getNode("/",1).setValue("/controls/engines/engine/started",0);

var update_engine = func(){
    var direction = getprop("/controls/engines/engine/direction");
    var throttle = getprop("/controls/engines/engine/throttle");
    var rpm = getprop("/controls/engines/engine/rpm1");
    var rpm_rate = throttle*max_P_KW*0.06;
    var max_rpm = throttle*max_P_KW*90+1000;
    if(rpm > max_rpm){
        rpm_rate = -20;
    }else if(rpm == max_rpm){
        rpm_rate = 0;
    }else{
        rpm_rate = throttle*max_P_KW*0.053;
    }
    var rpmActual = rpm_calculate(rpm_rate);
    var torque = 0;
    if(rpmActual == 0){
        torque = 0;
    }else{
        torque = (throttle*max_P_KW*1000)/(rpmActual*6.283*0.1667);#max 967
    }
    var force = 3.33*direction*torque*gearratio;
    #print("torque:"~torque);
    props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/engine/magnitude", force);
}
var rpm_calculate = func(rpm_rate){
    var rpm = getprop("/controls/engines/engine/rpm1");
    var rpm2 = 0;
    var gearspeed = math.round(getprop("/gear/gear/rollspeed-ms"));
    var rpm2 = (gearspeed/0.3)*9.8;
    #print(rpm2);
    rpm_rate = rpm_rate/1000;
    rpm = rpm + rpm * rpm_rate;
    var rpmActual = (rpm + rpm2)/2;
    props.getNode("/",1).setValue("/controls/engines/engine/rpm1",rpm);
    props.getNode("/",1).setValue("/controls/engines/engine/rpma",rpmActual);
    return rpmActual;
}

var engineTimer = maketimer(0.001, update_engine);
var startEngine = func(){
    props.getNode("/",1).setValue("/controls/engines/engine/started",1);
    engineTimer.start();
    print("Engine started");
}
var stopEngine = func(){
    props.getNode("/",1).setValue("/controls/engines/engine/started",0);
    props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/engine/magnitude", 0);
    engineTimer.stop();
    print("Engine stopped");
}



