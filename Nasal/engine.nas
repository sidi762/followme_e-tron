#//Followme EV electric engine by Sidi Liang
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

io.include("library.nas");
io.include("lib_elec.nas");
var N2LBS = 0.2248089;

#//Link to the tyre and driveline model inside the FDM, see dev/tyre-model/README.md
#//These properties only exist with the followme_e-tron-tyre FDM. With any other FDM
#//tyreModel stays nil and the engine drives the car the classic way, by writing
#//forces straight into external_reactions.
var tyreModel = nil;
if(props.getNode("/fdm/jsbsim/driveline/in/throttle_norm") != nil){
    tyreModel = {
        throttle: props.getNode("/fdm/jsbsim/driveline/in/throttle_norm"),
        direction: props.getNode("/fdm/jsbsim/driveline/in/direction"),
        motorOn: props.getNode("/fdm/jsbsim/driveline/in/motor_on"),
        driveMode: props.getNode("/fdm/jsbsim/driveline/in/drive_mode"),
        gear: props.getNode("/fdm/jsbsim/driveline/par/gear"),
        maxTorque: props.getNode("/fdm/jsbsim/driveline/par/max_torque_nm"),
        maxPower: props.getNode("/fdm/jsbsim/driveline/par/max_power_w"),
        driveTorque: props.getNode("/fdm/jsbsim/driveline/drive_torque_nm"),
        motorSpeed: props.getNode("/fdm/jsbsim/driveline/motor_rad_sec"),
    };
    tyreModel.motorOn.setValue(0);#//The motor stays off until the engine is started
    print("Engine: using the tyre and driveline model of the FDM");
}

var Engine = {
    #//Class for any electric power unit (engine and gear box)
    #//mTorque: Max torque, mPower: Max Power, rpmAtMPower: RPM at max power
    #//For this vehicle: maxPower: 375kW

    new: func(mTorque, mPower, rpmAtMPower) {
        var m = { parents:[Engine, Appliance]};

        m.applianceName = "Engine Module";
        m.applianceDescription = "This is the engine for the vehicle";


        m.engineNode = followme.vInfo.engine;
        m.engineNode.throttleNode = props.getNode("/controls/engines/engine/throttle",1);
        m.engineNode.rpmNode = props.getNode("/controls/engines/engine/rpma",1);
        m.engineNode.isStarted = props.getNode("/controls/engines/engine/started",1);
        m.engineNode.direction = props.getNode("/controls/direction", 1);
        m.engineNode.mode = props.getNode("/controls/mode", 1);

        followme.vInfo.lighting.reverseIndicator = props.getNode("/controls/lighting/reverse_indicator", 1);;
        m.reverseIndicatorNode = followme.vInfo.lighting.reverseIndicator;

        m.maxTorque = mTorque;
        m.ratedPower = mPower;
        m.rpmAtMaxPower = rpmAtMPower;
        m.ratedVoltage = 402;#//Rated voltage, use this fixed value for now
        m.ratedCurrent = 659.21; #//Rated Current, calculated using https://www.jcalc.net/motor-current-calculator
        return m;
    },

    # Motor/inverter is a power load on the DC bus.
    isPowerLoad: 1,
    resistance: 0,

    loadPowerW: func() {
        if (tyreModel != nil) {
            # Sample the FDM at the instant the electrical bus is solved.
            # Coasting and braking dissipate energy.
            var shaftW = me.runningState ? tyreModel.driveTorque.getValue() * tyreModel.motorSpeed.getValue() : 0;
            me.activePower_kW = math.max(0, shaftW) / 1000;
        }
        return 1000 * me.activePower_kW;
    },

    runningState: 0,

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
    isInLGear: Variable.new("isInLGear", 0, "isInLGear", 0, 1, 1, "/controls/engines/engine/isInLGear"),

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

        if(tyreModel != nil){
            #//The FDM integrates the wheels itself, so the motor speed comes from there
            var rpm = tyreModel.motorSpeed.getValue() * 9.5492966;#//rad/s to rpm
            #//Same floor as the classic path below: update_engine divides by the rpm
            if(math.abs(rpm) < 100) rpm = 100 * direction;
            me.rpm = rpm;
            me.engineNode.rpmNode.setValue(rpm);
            me.angularSpeed = rpm * 0.10471975;
            return rpm;
        }

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
            if(angularSpeed - totalAcceleration * 0.1 < -10){
                angularSpeed -= totalAcceleration * 0.1;
            }else if(angularSpeed - totalAcceleration * 0.1 > -10){
                angularSpeed -= angularAcceleration * 0.1;
            }
        }

        #angularSpeed += totalAcceleration * 0.1;

        var wheelSpeed_ms = me.wheelSpeedNode.getValue();
        var wheelAngularSpeed = wheelSpeed_ms / me.wheel_radius;

        var targetAngularSpeed = math.abs(wheelAngularSpeed) * me.gear * direction;

        #print("WheelAngularSpeed x gear " ~ wheelAngularSpeed * me.gear);

        if((direction == 1 and angularSpeed >= 0) or (direction == -1 and angularSpeed < 0)){
            if(math.abs(angularSpeed) < math.abs(targetAngularSpeed)) angularSpeed = targetAngularSpeed;
        }

        #print("AngularSpeed " ~ angularSpeed);


        #//rps = angularSpeed / 6.2831853;
        rpm = angularSpeed * 9.5492966; #//rps * 60

        #//Prevent the rpm goes too small
        if(math.abs(rpm) < 100){
            rpm = 100 * direction;
        }


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

        if (followme.powerState == "precharge") return;
        if (followme.powerState != "ready" or me.voltage <= 50){
            me.stopEngine();
            mainSwitchStarted = 0;
            print("No Power");
            me.errorMessage = "NO POWER";
            #//To be improved
            smartInstruments.smartInstruments.showWarningMessage(me.errorMessage);
            return 0;
        }else{
            me.errorMessage = nil;
        }

        if (!me.runningState) {
            me.runningState = 1;
            me.engineNode.isStarted.setValue(1);
        }
        var pedal = throttle;
        throttle = pedal * mode;
        #print("throttle:" ~throttle);

        if(tyreModel != nil){
            #//Hand the raw pedal, drive mode, gearing and motor ratings to the FDM, which
            #//applies the 2D pedal map, mode power limit and torque rate limiter at 120 Hz.
            #//All of it is sent on every update because FlightGear resets the FDM on reposition.
            tyreModel.motorOn.setValue(1);
            tyreModel.throttle.setValue(pedal);
            if(tyreModel.driveMode != nil) tyreModel.driveMode.setValue(mode);
            tyreModel.direction.setValue(direction);
            tyreModel.gear.setValue(me.gear);
            tyreModel.maxTorque.setValue(me.maxTorque);
            tyreModel.maxPower.setValue(me.ratedPower * 1000);
        }

        me.cmdTorque = throttle * me.maxTorque;
        #//me.cmdTorque = actualMaxTorque;
        me.cmdPower = math.abs(me.rpm * me.cmdTorque / 9549);
        if(me.cmdPower >= me.ratedPower){
          me.cmdPower = me.ratedPower;
        }

        #//var cmdAngularAcceleration = me.cmdTorque / me.rotor_moi; #rad/s^2
        var angularAcceleration = me.cmdTorque / me.rotor_moi; #rad/s^2
        me.rpm = me.rpm_calculate(angularAcceleration);
        #//MAGIC
        if(direction * me.rpm > 0) me.torque = ((9549 * me.cmdPower) / me.rpm);
        else if(direction * me.rpm < 0) me.torque = ((9549 * me.cmdPower) / math.abs(me.rpm)) * direction;
        if (tyreModel == nil) me.activePower_kW = math.abs(me.rpm * me.torque / 9549);

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
        if (!followme.requestDrivePower()) return 0;
        if (me.engineTimer == nil) me.engineTimer = maketimer(0.1, func me.update_engine());
        if (me.engineTimer.isRunning) return 1;
        me.engineTimer.simulatedTime = 1;
        me.rpm = 100 * me.getDirection();
        followme.playAudio("starter.wav");
        me.engineTimer.start();
        return 1;
    },

    stopEngine: func(){
        followme.updateElectrical();
        followme.setPowerState("off");
        if (me.engineTimer != nil) me.engineTimer.stop();
        me.rpm = 0;
        me.torque = 0;
        me.outputForce = 0;
        outputForce(0);
        if(tyreModel != nil){
            tyreModel.throttle.setValue(0);
            tyreModel.motorOn.setValue(0);
        }
        me.activePower_kW = 0;
        me.runningState = 0;
        me.engineNode.isStarted.setValue(0);
        followme.advancePowerSupply(0);
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
followme.circuit_1.addUnitToSeries(0, followme.Cable.new(5, 0.008));

if(tyreModel != nil){
    #//A rebuilt FDM (after a reposition) must not come back with the motor on while the engine is off
    setlistener("/sim/signals/fdm-initialized", func(n){
        if(n.getBoolValue()) tyreModel.motorOn.setValue(engine_1.isRunning());
    });
}

var outputForce = func(force){
    #//With the tyre model the FDM applies the drive torque itself, through the tyres
    if(tyreModel != nil) return;

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
        props.getNode("/",1).setValue("/fdm/jsbsim/external_reactions/BR/magnitude", 0);
    }
}

props.getNode("systems/welcome-message", 1).setValue(3);
var mainSwitchStarted = 0;
var startEngine = func(my_engine){
    if(!getprop("/services/service-truck/connect") and !getprop("/controls/is-recharging")){
        smartInstruments.smartInstruments.startUp();
        var signal = my_engine.startEngine();
        if(signal){
            mainSwitchStarted = 1;
            print("Engine started");
            if(followme.safety.isEnabled) followme.safety.init();
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

    }else{
        #screen.log.write("Disconnect the charge cable before starting.", 0, 0.584, 1);
        setprop("/sim/sound/voices/pilot", "Disconnect the charge cable before starting.");
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

addcommand("enableLGear", func() {
    engine_1.setGear(150);
    engine_1.isInLGear.setValue(1);
    print("Engine: L Gear Enabled");
});
addcommand("disableLGear", func() {
    engine_1.setGear(9.73);
    engine_1.isInLGear.setValue(0);
    print("Engine: L Gear disabled");
});
