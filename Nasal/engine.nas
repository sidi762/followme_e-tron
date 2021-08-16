#//Followme EV electric engine by Sidi Liang
#//Contact: sidi.liang@gmail.com

#//Bug log: engine still runs after battary drains up
#//Switching between D and R might fail?
#//Goes crazy when attampt to drive with brakes not released
#//Electrical system error message
#//Drain battary too fast?

var N2LBS = 0.2248089;
var Engine = {
    #//Class for any electric engine
    #//mTorque: Max torque, mPower: Max Power, rpmAtMPower: RPM at max power
    #//For this vehicle: maxPower: 375kW

    new: func(mTorque, mPower, rpmAtMPower) {
        var m = { parents:[Engine, followme.Appliance.new()]};

        m.applianceName = "Engine Module";
        m.applianceDescription = "This is the engine for the vehicle";

        m.engineNode = followme.vehicleInformation.engine;
        m.engineNode.throttleNode = props.getNode("/controls/engines/engine/throttle",1);
        m.engineNode.rpmNode = props.getNode("/controls/engines/engine/rpma",1);
        m.engineNode.isStarted = props.getNode("/controls/engines/engine/started",1);
        m.engineNode.direction = props.getNode("/controls/direction", 1);
        m.engineNode.mode = props.getNode("/controls/mode", 1);

        followme.vehicleInformation.lighting.reverseIndicator = props.getNode("/controls/lighting/reverse_indicator", 1);;
        m.reverseIndicatorNode = followme.vehicleInformation.lighting.reverseIndicator;

        m.maxTorque = mTorque;
        m.ratedPower = mPower;
        m.rpmAtMaxPower = rpmAtMPower;
        m.ratedVoltage = 402;#//Rated voltage, use this fixed value for now
        m.ratedCurrent = 659.21; #//Rated Current, calculated using https://www.jcalc.net/motor-current-calculator
        return m;
    },

    motorResistance: 0.2,#//No datasource, based on guess
    resistance: 0.2,
    protectionResistance: 0.5, #//temp solution

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
        me.engineNode.direction.setValue(me.direction);
        me.reverseIndicatorNode.setValue((me.direction < 0));
        if(followme.isInternalView()) followme.playAudio("change_gear.wav");
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

    frictionNode: props.getNode("/fdm/jsbsim/forces/fbx-gear-lbs", 1),
    wheelSpeedNode: props.getNode("/gear/gear/rollspeed-ms", 1),

    debugMode: 0,
    ratedVoltage: 0, #//Rated voltage
    ratedCurrent: 0, #//Rated Current, calculated when initializing

    errorMessage: nil,

    rpm_calculate: func(angularAcceleration){

        var direction = me.getDirection();

        var rpm = me.rpm;
        #//var rps = rpm / 60;

        var angularSpeed = rpm * 0.10471975; #//rps * 2 * 3.1415926

        var friction_lbs = me.frictionNode.getValue();
        var friction = 4.4492 * friction_lbs * 0.25;#//0.25: single wheel
        var angularDecelaeration = friction * me.wheel_radius * (1/me.wheel_moi); #//frictionTorque = friction * wheel_radius, angularDecelaeration = frictionTorque/wheel_moi;
        #print(angularAcceleration);
        #print("de"~angularDecelaeration);

        angularDecelaeration = math.abs(angularDecelaeration) * -1;#//Not accurate

        var totalAcceleration = angularAcceleration + angularDecelaeration;

        if(direction == 1){
            if(angularSpeed + totalAcceleration * 0.1 > 10){
                angularSpeed += totalAcceleration * 0.1;
            }else if(angularSpeed + totalAcceleration * 0.1 < 10){
                #print("angularSpeed + totalAcceleration * 0.1 < 10");
                angularSpeed += angularAcceleration * 0.1;
            }
        }else if(direction == -1){
            if(angularSpeed + totalAcceleration * 0.1 < -10){
                angularSpeed += totalAcceleration * 0.1;
            }else if(angularSpeed + totalAcceleration * 0.1 > -10){
                angularSpeed += angularAcceleration * 0.1;
            }
        }

        #angularSpeed += totalAcceleration * 0.1;

        var wheelSpeed_ms = me.wheelSpeedNode.getValue();
        var wheelAngularSpeed = wheelSpeed_ms / me.wheel_radius;

        var targetAngularSpeed = math.abs(wheelAngularSpeed) * me.gear;

        #print("WheelAngularSpeed x gear " ~ wheelAngularSpeed * me.gear);

        if(math.abs(angularSpeed) < targetAngularSpeed) angularSpeed = targetAngularSpeed;
        #print("AngularSpeed " ~ angularSpeed);


        #//rps = angularSpeed / 6.2831853;
        rpm = angularSpeed * 9.5492966; #//rps * 60

        #//Prevent the rpm goes too small
        #if(math.abs(rpm) < 50){
        #    rpm = 50 * direction;
        #}


        me.rpm = rpm;
        me.engineNode.rpmNode.setValue(rpm);
        me.angularSpeed = angularSpeed;

        return rpm;
    },

    update_engine: func(){
        var throttle = me.engineNode.throttleNode.getValue();
        var direction = me.getDirection();
        var mode = me.engineNode.mode.getValue();
        me.mode = mode;

        if(me.voltage <= 50){
            me.stopEngine();
            print("No Power");
            me.errorMessage = "NO POWER";
            #//To be improved
            smartInstruments.smartInstruments.showWarningMessage(me.errorMessage);
            return 0;
        }else{
            me.errorMessage = nil;
        }

        throttle = throttle * mode;
        #print("throttle:" ~throttle);

        me.controlResistance = (0 - throttle * 3000000000000) + 3000000000000;#//We do this for now as I still can't find out how is the speed of motor being controlled. Imagine this is a tunable resistor
        me.resistance = me.controlResistance + me.motorResistance + me.protectionResistance;

        var actualMaxTorque = me.current * (me.maxTorque / me.ratedCurrent); #//We can do this because torque is directly proportional to the current

        var cmdRpm = throttle * me.rpmAtMaxPower;
        #print("cmdRpm: "~cmdRpm);

        #var cmdPower = throttle * me.ratedPower;
        #print("cmdPower: "~cmdPower);

        me.cmdTorque = throttle * me.maxTorque;
        #//me.cmdTorque = actualMaxTorque;
        me.cmdPower = math.abs(me.rpm * me.cmdTorque / 9549);
        if(me.cmdPower >= me.ratedPower){
          me.cmdPower = me.ratedPower;
        }

        #//var cmdAngularAcceleration = me.cmdTorque / me.rotor_moi; #rad/s^2
        var angularAcceleration = me.cmdTorque / me.rotor_moi; #rad/s^2
        me.rpm = me.rpm_calculate(angularAcceleration);
        if(me.rpm) me.torque = ((9549 * me.cmdPower) / me.rpm) * direction;

        me.activePower_kW = math.abs(me.rpm * me.torque / 9549);

        #if(math.abs(me.rpm) < cmdRpm){
            #print("me.rpm < cmdRpm");
            #//me.torque = throttle * actualMaxTorque * direction;

        #}else if(throttle == 0){
        #    me.activePower_kW = 0;
        #    me.torque = 0;
        #    var angularAcceleration = direction * math.abs(me.torque) / me.rotor_moi; #rad/s^2
        #    me.rpm = me.rpm_calculate(angularAcceleration);
        #}else{
        #    var angularAcceleration = direction * math.abs(me.torque) / me.rotor_moi; #rad/s^2
        #    me.rpm = me.rpm_calculate(angularAcceleration);
        #    me.torque = throttle * direction * math.abs((9549 * me.activePower_kW) / me.rpm);
        #}

        var force = (1/me.wheel_radius) * me.torque * me.gear;#//unit: N

        me.outputForce = force;

        if(me.debugMode){
            me.printDebugInfo();
        }

        outputForce(me.outputForce * N2LBS);

        if(me.errorMessage){
            smartInstruments.smartInstruments.showWarningMessage(me.errorMessage);
        }else{
            smartInstruments.smartInstruments.hideWarningMessage();
        }

    },

    engineTimer: nil,

    startEngine: func(){
        if(me.engineTimer == nil) me.engineTimer = maketimer(0.1, func me.update_engine());
        me.engineSwitch.switchConnect();
        me.runningState = 1;
        me.engineNode.isStarted.setValue(1);
        me.engineTimer.simulatedTime = 1;
        me.rpm = 100 * me.getDirection();
        followme.playAudio("starter.wav");
        me.engineTimer.start();
        return 1;
    },

    stopEngine: func(){
        me.engineSwitch.switchDisconnect();
        me.engineTimer.stop();
        me.rpm = 0;
        me.torque = 0;
        me.outputForce = 0;
        outputForce(0);
        me.activePower_kW = 0;
        me.runningState = 0;
        me.engineNode.isStarted.setValue(0);
    },

    printDebugInfo: func(){
        print("rpm: "~me.rpm);
        print("torque: "~me.torque);
        print("power: "~me.activePower_kW);
        print("______________________________________________");
    },

};


var engine_1 = Engine.new(460, 375, 7750);
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
var mainSwitchStarted = 0;
var startEngine = func(my_engine){
    mainSwitchStarted = 1;
    smartInstruments.smartInstruments.startUp();
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
            my_engine.errorMessage = "START FAIL";
            smartInstruments.smartInstruments.showWarningMessage(my_engine.errorMessage);
        }

    }else if(followme.chargeTimer.isRunning){
        #screen.log.write("Battery is recharging, cannot start engine.", 0, 0.584, 1);
        setprop("/sim/sound/voices/pilot", "Battery is recharging, cannot start engine.");
    }
}

var stopEngine = func(my_engine){
    mainSwitchStarted = 0;
    my_engine.stopEngine();
    smartInstruments.smartInstruments.shutDown();
    followme.safety.stop();
    print("Engine stopped");
}

var toggleEngine = func(my_engine){
    if(mainSwitchStarted == 0){
        startEngine(my_engine);
    }else{
        stopEngine(my_engine);
    }
}
