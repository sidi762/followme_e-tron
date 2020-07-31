#//Followme EV electric engine by Sidi Liang
#//Contact: sidi.liang@gmail.com

var N2LBS = 0.2248089;
var Engine = {
    #//Class for any electric engine
    #//mTorque: Max torque, mPower: Max Power, rpmAtMPower: RPM at max power
    #//For this vehicle: maxPower: 375kW

    new: func(mTorque, mPower, rpmAtMPower) {
        return { parents:[Engine, followme.Appliance.new()], maxTorque: mTorque, ratedPower:mPower, rpmAtMaxPower:rpmAtMPower };
    },

    resistance: 0.1, #//No datasource, based on guess

    runningState: 0,

    engineSwitch: followme.Switch.new(0),

    isRunning: func(){
        return me.runningState;
    },

    direction: 1,
    setDirection: func(dir){
        me.direction = dir;
    },
    toggleDirection: func(){
        #//Toggle Direction, forward:1; barkward: -1
        me.direction *= -1;
        props.getNode("/",1).setValue("/controls/direction", me.direction);
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

    mode: 1,

    rotor_moi: 2.3,
    wheel_moi: 0.9,
    wheel_radius: 0.31,#//M

    rpm: 0,

    maxTorque: 460, #Nm

    rpmAtMaxPower: 6150, #rpm

    angularSpeed: 0, #rad/s
    torque: 0, #Nm
    outputForce: 0, #N

    debugMode: 0,

    rpm_calculate: func(angularAcceleration){

        var rpm = me.rpm;
        #//var rps = rpm / 60;


        var angularSpeed = rpm * 0.10471975; #//rps * 2 * 3.1415926

        var friction_lbs = props.getNode("/",1).getValue("fdm/jsbsim/forces/fbx-gear-lbs");
        var friction = 4.4492 * friction_lbs * 0.25;#//0.25: single wheel
        var angularDecelaeration = friction * me.wheel_radius * (1/me.wheel_moi); #//frictionTorque = friction * wheel_radius, angularDecelaeration = frictionTorque/wheel_moi;
        #print(angularAcceleration);
        #print("de"~angularDecelaeration);



        angularDecelaeration = math.abs(angularDecelaeration) * me.getDirection() * -1;



        var totalAcceleration = angularAcceleration + angularDecelaeration;

        if(me.getDirection() == 1){
            if(angularSpeed + totalAcceleration * 0.1 > 10){
                angularSpeed = angularSpeed + totalAcceleration * 0.1;
            }else if(angularSpeed + totalAcceleration * 0.1 < 10){
                #print("angularSpeed + totalAcceleration * 0.1 < 10");
                angularSpeed = angularSpeed + angularAcceleration * 0.1;
            }
        }else if(me.getDirection() == -1){
            if(angularSpeed + totalAcceleration * 0.1 < -10){
                angularSpeed = angularSpeed + totalAcceleration * 0.1;
            }else if(angularSpeed + totalAcceleration * 0.1 > -10){
                angularSpeed = angularSpeed + angularAcceleration * 0.1;
            }
        }

        #//rps = angularSpeed / 6.2831853;
        rpm = angularSpeed * 9.5492966; #//rps * 60

        me.rpm = rpm;
        props.getNode("/",1).setValue("/controls/engines/engine/rpma",rpm);
        me.angularSpeed = angularSpeed;

        return rpm;
    },

    update_engine: func(){
        var throttle = props.getNode("/",1).getValue("/controls/engines/engine/throttle");
        var direction = me.getDirection();
        var mode = props.getNode("/",1).getValue("/controls/mode");
        me.mode = mode;
        var volt = me.voltage;

        if(!volt){
            me.rpm = 0;
            props.getNode("/",1).setValue("/controls/engines/engine/rpma", 0);
            outputForce(0);
            return 0;
        }

        throttle = throttle * mode;
        #print("throttle:" ~throttle);

        var cmdRpm = throttle * me.rpmAtMaxPower;
        #print("cmdRpm: "~cmdRpm);

        var cmdPower = throttle * me.ratedPower;
        #print("cmdPower: "~cmdPower);
        me.activePower_kW = math.abs(me.rpm * me.torque / 9549);

        if(math.abs(me.rpm) < cmdRpm){
            #print("me.rpm < cmdRpm");
            me.torque = throttle * me.maxTorque * direction;
            var angularAcceleration = me.torque / me.rotor_moi; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
        }else if(throttle == 0){
            me.activePower_kW = 0;
            me.torque = 0;
            var angularAcceleration = direction * math.abs(me.torque) / me.rotor_moi; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
        }else{
            me.activePower_kW = cmdPower;
            var angularAcceleration = direction * math.abs(me.torque) / me.rotor_moi; #rad/s^2
            me.rpm = me.rpm_calculate(angularAcceleration);
            me.torque = direction * math.abs((9549 * me.activePower_kW) / me.rpm);
        }

        var force = (1/me.wheel_radius) * me.torque * me.gear;#//unit: N

        me.outputForce = force;

        if(me.debugMode){
            me.debugPrint();
        }


        outputForce(me.outputForce * N2LBS);

    },

    engineTimer: nil,

    startEngine: func(){
        if(me.engineTimer == nil) me.engineTimer = maketimer(0.1, func me.update_engine());
        me.engineSwitch.switchConnect();
        me.runningState = 1;
        props.getNode("/",1).setValue("/controls/engines/engine/started",1);
        me.engineTimer.simulatedTime = 1;
        me.rpm = 100 * me.getDirection();
        followme.playAudio("starter.wav");
        me.engineTimer.start();
        return 1;
    },

    stopEngine: func(){
        me.engineTimer.stop();
        me.rpm = 0;
        me.torque = 0;
        me.outputForce = 0;
        outputForce(0);
        me.activePower_kW = 0;
        me.runningState = 0;
        me.engineSwitch.switchDisconnect();
        props.getNode("/",1).setValue("/controls/engines/engine/started",0);
    },

    debugPrint: func(){
        print("rpm: "~me.rpm);
        print("torque: "~me.torque);
        print("power: "~me.activePower_kW);
        print("______________________________________________");
    },

};


var engine_1 = Engine.new(460, 375, 6150);
followme.circuit_1.addUnitToSeries(0, followme.Cable.new(5, 0.008));
followme.circuit_1.addUnitToSeries(0, engine_1);
followme.circuit_1.addUnitToSeries(0, engine_1.engineSwitch);
engine_1.engineSwitch.switchDisconnect();
followme.circuit_1.addUnitToSeries(0, followme.Cable.new(5, 0.008));

var outputForce = func(force){
    #//Four wheel drive

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

props.getNode("systems/welcome-message", 1).setValue(3);
var startEngine = func(my_engine){
    if(!props.getNode("/controls/is-recharging").getValue()){
        var signal = my_engine.startEngine();
        if(signal){
            print("Engine started");
            followme.safety.init();
            #//followme.safety.enableFrontRadar();
            if(props.getNode("systems/welcome-message", 1).getValue() == 1){
                props.getNode("/sim/messages/copilot", 1).setValue("Beijing di san tsui jiao tong wei ti xing nin, Dao lu tsian wan tiao, ann tsuan di yi tiao, xing che bull gui fun, tsin ren liang hang lei");
            }else if(props.getNode("systems/welcome-message", 1).getValue() == 2){
                props.getNode("/sim/messages/copilot", 1).setValue("This is a reminder from The Third District Traffic Commission of Beijing. There are thousands of roads, and the safety is the first. If you drive recklessly, your loved ones will be filled with tears.");
            }else if(props.getNode("systems/welcome-message", 1).getValue() == 3){
                props.getNode("/sim/messages/copilot", 1).setValue("Ben chea yee xeao do. This vehicle is disinfected.");
            }
        }else{
            print("Engine start failed");
        }

    }else if(followme.chargeTimer.isRunning){
        #screen.log.write("Battery is recharging, cannot start engine.", 0, 0.584, 1);
        setprop("/sim/sound/voices/pilot", "Battery is recharging, cannot start engine.");
    }
}

var stopEngine = func(my_engine){
    my_engine.stopEngine();
    followme.safety.stop();
    print("Engine stopped");
}

var toggleEngine = func(my_engine){
    if(my_engine.runningState == 0){
        startEngine(my_engine);
    }else{
        stopEngine(my_engine);
    }
}
