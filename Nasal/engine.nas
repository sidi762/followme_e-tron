var Engine = {
    
    new: func(mTorque, mPower, rpmAtMPower, elecI, elecV) { 
        return { parents:[Engine], maxTorque: mTorque, maxPower:mPower, rpmAtMaxPower:rpmAtMPower, elecNodeI:elecI, elecNodeV:elecV }; 
    },
    
    runningState: 0,
    
    isRunning: func(){
        return me.runningState;
    },
    
    direction: 1,
    setDirection: func(dir){
        me.direction = dir;
    },
    getDirection: func(){
        return me.direction;
    },
    
    gear: 9.73,
    setGear: func(g){
        me.gear = g;
    },
    getGear: func(){
        return me.gear;
    },
    
    rpm: 0,
    
    maxTorque: 460, #Nm
    maxPower: 375, #kW
    rpmAtMaxPower: 6150, #rpm
    
    angularSpeed: 0, #rad/s
    torque: 0, #Nm
    power: 0, #kW
    outputForce: 0, #N
    
    debugMode: 0,
    
    elecNodeI: nil,
    elecNodeV: nil,
    
    rpm_calculate: func(angularAcceleration){
   
        var rpm = me.rpm;
        var rps = rpm / 60;
        var angularSpeed = rps * 2 * 3.1415926;
    
        var friction_lbs = props.getNode("/",1).getValue("fdm/jsbsim/forces/fbx-gear-lbs");
        var friction = 4.4492 * friction_lbs;
        var frictionTorque = friction * 0.15 * 0.3;
        var angularDecelaeration = frictionTorque/0.625;
        #print(angularAcceleration);
        #print("de"~angularDecelaeration);
        if(angularDecelaeration > 0){
            angularDecelaeration *= -1;
        }
        var totalAcceleration = angularAcceleration + angularDecelaeration;
   
        if(angularSpeed + totalAcceleration * 0.1 > 10){
            angularSpeed = angularSpeed + totalAcceleration * 0.1;
        }else if(angularSpeed + totalAcceleration * 0.1 < 10){
            #print("angularSpeed + totalAcceleration * 0.1 < 10");
            angularSpeed = angularSpeed + angularAcceleration * 0.1;
        }
   
        rps = angularSpeed / 6.2831853;
        rpm = rps*60;
    
        me.rpm = rpm;
        
        me.angularSpeed = angularSpeed;
    
        return rpm;
    },
    
    
    
    update_engine: func(){
        var throttle = props.getNode("/",1).getValue("/controls/engines/engine/throttle");
        var direction = me.direction;
        var mode = props.getNode("/",1).getValue("/controls/mode");

        throttle = throttle * mode;
        #print("throttle:" ~throttle);
        
        var cmdRpm = throttle * me.rpmAtMaxPower;
        #print("cmdRpm: "~cmdRpm);
        
        var cmdPower = throttle * me.maxPower;
        #print("cmdPower: "~cmdPower);
        me.power = me.rpm * me.torque / 10824;
       
        if(me.rpm < cmdRpm){
            #print("me.rpm < cmdRpm");
            me.torque = throttle * me.maxTorque;
            #print("torque "~ me.torque);
            var angularAcceleration = me.torque / 0.175; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
        }else if(throttle == 0){
            me.torque = 0;
            var angularAcceleration = me.torque / 0.175; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
        }else{
            me.power = cmdPower;
            var angularAcceleration = me.torque / 0.175; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
            me.torque = me.power / me.rpm * 10824;
        }
    
        var force = 3.33 * direction * me.torque * me.gear;
    
        me.outputForce = force;
        
        if(me.debugMode){
            me.debugPrint();
        }
        
        if(me.elecNodeV.getValue()){
            me.elecNodeI.setValue(me.power*1000/me.elecNodeV.getValue());
        }
        
        outputForce(me.outputForce);
   
    },
    
    engineTimer: nil,
    
    timerCreated: 0,
    
    createTimer: func(){
        if(!me.timerCreated){
            me.engineTimer = maketimer(0.1, func me.update_engine());
            me.timerCreated = 1;
        }
    },
    
    startEngine: func(){
        me.createTimer();
        me.runningState = 1;
        me.engineTimer.simulatedTime = 1;
        me.rpm = 100;
        me.engineTimer.start();
        return 1;
    },
    
    stopEngine: func(){
        me.rpm = 0;
        me.torque = 0;
        me.outputForce = 0;
        me.power = 0;
        me.runningState = 0;
        me.engineTimer.stop();
    },
    
    debugPrint: func(){
        print("rpm: "~me.rpm);
        print("torque: "~me.torque);
        print("power: "~me.power);
        print("______________________________________________");
    },
    
};


var elecNodeI = props.getNode("/systems/electrical/e-tron/fwd-eng-I-A", 1);
var elecNodeV = props.getNode("/systems/electrical/e-tron/fwd-eng-U-V", 1);

var engine_1 = Engine.new(460, 375, 6150, elecNodeI, elecNodeV);

var outputForce = func(force){
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FL/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FL/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[1]/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[2]/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BL/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BL/magnitude", 0);
    }
    
    if(props.getNode("/",1).getValue("/fdm/jsbsim/gear/unit[3]/compression-ft") > 0){
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BR/magnitude", force/4);
    }else{
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/FR/magnitude", 0);
    }
}


var startEngine = func(){
    if(!props.getNode("/controls/is-recharging").getValue()){
        props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",1);
        props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",1);
        
        if(props.getNode("systems/welcome-message", 1).getValue() == 1){
            props.getNode("/sim/messages/copilot", 1).setValue("Beijing di san tsui jiao tong wei ti xing nin, Dao lu tsian wan tiao, ann tsuan di yi tiao, xing che bull gui fun, tsin ren liang hang lei");
        }else if(props.getNode("systems/welcome-message", 1).getValue() == 2){
            props.getNode("/sim/messages/copilot", 1).setValue("This is a reminder from The Third District Traffic Commission of Beijing. There are thousands of roads, and the safety is the first. If you drive recklessly, your loved ones will be filled with tears.");
        }
        
        var signal = engine_1.startEngine();
        if(signal){
            print("Engine started");
        }
    }else if(followme.chargeTimer.isRunning()){
        #screen.log.write("Battery is recharging, cannot start engine.", 0, 0.584, 1);
        setprop("/sim/sound/voices/pilot", "Battery is recharging, cannot start engine.");
    }
}

var stopEngine = func(){
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-fwd-eng",0);
    props.getNode("/",1).setValue("/systems/electrical/e-tron/switch/bat-bwd-eng",0);

    engine_1.stopEngine();
    print("Engine stopped");
}

