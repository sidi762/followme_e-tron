var gearratio = 9.73;
props.getNode("/",1).setValue("/controls/engines/engine/rpm1",0);
props.getNode("/",1).setValue("/controls/engines/engine/direction",1);
props.getNode("/",1).setValue("/controls/engines/engine/started",0);
props.getNode("/",1).setValue("/controls/gear/brake-cmd",0);



var update_engine = func(){
    var throttle = props.getNode("/",1).getValue("/controls/engines/engine/throttle");
    var direction = props.getNode("/",1).getValue("/controls/engines/engine/direction");
    
    var fwdUNode = props.getNode("/systems/electrical/e-tron/fwd-eng-U-V",1);
    var fwdANode = props.getNode("/systems/electrical/e-tron/fwd-eng-I-A",1);
    var bwdUNode = props.getNode("/systems/electrical/e-tron/bwd-eng-U-V",1);
    var bwdANode = props.getNode("/systems/electrical/e-tron/bwd-eng-I-A",1);
    
    var fwdMaxU = props.getNode("/",1).getValue("/systems/electrical/e-tron/fwd-eng-U-V-max");
    var fwdMaxA = props.getNode("/",1).getValue("/systems/electrical/e-tron/fwd-eng-I-A-max");
    var bwdMaxU = props.getNode("/",1).getValue("/systems/electrical/e-tron/bwd-eng-U-V-max");
    var bwdMaxA = props.getNode("/",1).getValue("/systems/electrical/e-tron/bwd-eng-I-A-max");
    
    fwdUNode.setValue(throttle * fwdMaxU);
    fwdANode.setValue(throttle * fwdMaxA);
    bwdUNode.setValue(throttle * bwdMaxU);
    bwdANode.setValue(throttle * bwdMaxA);
    
    var fwdPower = fwdUNode.getValue() * fwdANode.getValue();
    var bwdPower = bwdUNode.getValue() * bwdANode.getValue();
    
    var cmd_P_kW = (fwdPower + bwdPower)/1000;
    
    
    #var cmd_P_kW = throttle*max_P_kW;
    
    var rpm = props.getNode("/",1).getValue("/controls/engines/engine/rpm1");
    var rpm_rate = cmd_P_kW * 0.06;
    var max_rpm = cmd_P_kW * 90 + 1000;
    if(rpm > max_rpm){
        rpm_rate = -20;
    }else if(rpm == max_rpm){
        rpm_rate = 0;
    }else{
        rpm_rate = cmd_P_kW*  0.06;
    }
    var rpmActual = rpm_calculate(rpm_rate);
    var torque = 0;
    if(rpmActual == 0){
        torque = 0;
    }else{
        torque = (cmd_P_kW * 1000) / (rpmActual * 6.283 * 0.1667);#max 967
    }
    var force = 3.33*direction*torque*gearratio;
    #print("torque:"~torque);
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FL/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FL/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BL/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BL/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BR/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", 0);
    }
   
}

var engineTimer = maketimer(0.001, update_engine);


var rpm_calculate = func(rpm_rate){
    var rpm = getprop("/controls/engines/engine/rpm1");
    var rpm2 = 0;
    var gearspeed = math.round(props.getNode("/",1).getValue("/gear/gear/rollspeed-ms"));
    var rpm2 = (gearspeed/0.3)*9.8;
    #print(rpm2);
    rpm_rate = rpm_rate/1000;
    rpm = rpm + rpm * rpm_rate;
    var rpmActual = (rpm + rpm2)/2;
    props.getNode("/",1).setValue("/controls/engines/engine/rpm1",rpm);
    props.getNode("/",1).setValue("/controls/engines/engine/rpma",rpmActual);
    return rpmActual;
}


var startEngine = func(){
    props.getNode("/",1).setValue("/controls/engines/engine/rpm1",1000);
    props.getNode("/",1).setValue("/controls/engines/engine/started",1);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",1);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",1);
    engineTimer.simulatedTime = 1;
    engineTimer.start();
    print("Engine started");
}
var stopEngine = func(){
    props.getNode("/",1).setValue("/controls/engines/engine/started",0);
    props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/engine/magnitude", 0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",0);
    engineTimer.stop();
    print("Engine stopped");
}





