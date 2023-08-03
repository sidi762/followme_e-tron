#//Followme EV steering system by Sidi Liang
#//Contact: sidi.liang@gmail.com

var cache = {
    new: func return { parents:[cache] };
};

var memoize = { callback:nil };

memoize.new = func(code) {
    return { parents:[memoize], callback:code, cache:cache.new() };
}

memoize._save = func(value) me.cache[value] = me.callback(value);
memoize.lookup = func(value) {
    var found = me.cache[value];
    if (found) {
        #//print("cached:",found,"\n");
        return found;
    }
    #//print("Calculated:", value);
    return me._save(value);
}

var Steering = {

    new: func() {
        print("Steering system initialized!");
        var steering = { parents:[Steering] };
        props.getNode("/controls/steering_wheel/steering_limit-deg", 1).setValue(steering.steeringLimit * R2D);
        steering.debugNodeB.setValue(15);
        steering.debugNodeC.setValue(2);
        steering.debugNodeD.setValue(14000);
        steering.debugNodeE.setValue(0.97);
        steering.debugNodeFactor.setValue(0.012);
        return steering;
    },

    mode: 0, #//0: direct; 1: advanced

    debugMode: 0,

    input: 0, #//-1: left, 1:right, 0: none
    command: 0, #//Steering command, range from -1 to 1
    commandNode: props.getNode("/controls/flight/rudder", 1),
    velocityNode: props.getNode("sim/multiplay/generic/float[15]", 1),
    slipAngleNode: props.getNode("/fdm/jsbsim/gear/unit/slip-angle-deg", 1),
    debugNodeB: props.getNode("/debug/steering/B", 1),
    debugNodeC: props.getNode("/debug/steering/C", 1),
    debugNodeD: props.getNode("/debug/steering/D", 1),
    debugNodeE: props.getNode("/debug/steering/E", 1),
    debugNodeFactor: props.getNode("/debug/steering/factor", 1),
    steeringAngle: 0, #//in rad
    #steeringAngleDeg: 0, #//in degrees

    #//steeringLimit: 7.8539815, #// 2.5 * 3.1415926 = 7.8539815 5 * 3.1415926 = 15.707963 3.1415926 / 4 = 0.78359815
    steeringLimit: 15.707963,


    powPointThree: memoize.new( func(value){
        return math.pow(value, 0.3);
    }),

    powPointTwo: memoize.new( func(value){
        return math.pow(value, 0.2);
    }),

    powPointOne: memoize.new( func(value){
        return math.pow(value, 0.1);
    }),

    steeringStep:func(rad){
        var speed = me.velocityNode.getValue();
        var ret = 0.1 * me.powPointOne.lookup(sprintf("%.1f", math.abs(rad)));
        ret -= 0.023 * me.powPointThree.lookup(sprintf("%.1f", math.abs(speed)));
        ret += 0.015;
        return ret;
    },
    # neutralStep: func(rad){
    #    var speed = me.velocityNode.getValue();
    #    return 0.02 * me.powPointThree.lookup(sprintf("%.1f", math.abs(speed))) * math.abs(rad);
    #},
    neutralStep: func(rad){
        # Approximation Constants for Missing Geometry Parameters
        var casterAngle = 0.1; # in radians, use a value between 0.05 and 0.2 for typical vehicles
        var tireStiffness = 3000; # in N/rad, adjust based on tire properties
        var tireWidth = 0.225; # in meters, approximate value for tire width
        # Constants for the tire model (empirical parameters)
        #var B = 15.0;
        #var C = 2;
        #var D = 14000;
        #var E = 0.97;
        var B = me.debugNodeB.getValue();
        var C = me.debugNodeC.getValue();
        var D = me.debugNodeD.getValue();
        var E = me.debugNodeE.getValue();

        # Vehicle Speed
        var speed = me.velocityNode.getValue(); # in kts
        speed *= 0.514444; # Convert knots to meters per second (1 knot ≈ 0.514444 m/s)

        # Tire Properties
        var tireSlipAngle = 0;
        if(speed > 0.1){
            tireSlipAngle = math.abs(me.slipAngleNode.getValue()) * D2R; # use the absolute value of the slip angle in radians
        }

        var BTimesKappa = B * tireSlipAngle;
        var tmpTerm = C * math.atan(BTimesKappa - E * (BTimesKappa - math.atan(BTimesKappa)));

        # Pacejka tire model lateral force calculation
        var Fy = D * math.sin(tmpTerm);

        # Pacejka tire model self-aligning torque calculation
        var Mz = math.abs(D * C * tireSlipAngle * math.cos(tmpTerm));

        # Self-centering force calculation
        var Fsc = Mz / 0.3; # 0.3 is approx. for steering wheel radius

        var factor = me.debugNodeFactor.getValue();
        # Calculate steering change based on self-centering force and tire stiffness
        var steeringChange = (Fsc / tireStiffness) * factor; # adjust the factor to control the self-centering strength

        # Apply the change to the steering angle
        return steeringChange;
    },

    mainLoop: func(){
        if(me.input == 0)
        {
            if(math.abs(me.steeringAngle) <= 0.01)
            {
                me.steeringAngle = 0;
                me.command = me.steeringAngle / me.steeringLimit; #//The steering wheel could rotate for two circles and a half
                me.commandNode.setValue(me.command);
                #me.steeringAngleDeg = me.steeringAngle * R2D;
                #props.getNode("/",1).setValue("/controls/steering_wheel", me.steeringAngleDeg);
            }
            if(me.steeringAngle == 0)
            {
                me.stopTimer();
                return 0;
            }
            else if(me.steeringAngle >= 0.01)
                me.steeringAngle -= math.min(me.neutralStep(me.steeringAngle), me.steeringAngle);
            else if(me.steeringAngle <= -0.01)
                me.steeringAngle += math.min(me.neutralStep(me.steeringAngle), -me.steeringAngle);
        }
        else if(me.input == 1 and me.steeringAngle < me.steeringLimit)
        {
            if(me.steeringAngle < 0)
            {
                me.steeringAngle += me.neutralStep(me.steeringAngle);
                me.steeringAngle += 0.2;
            }
            else
                me.steeringAngle += me.steeringStep(me.steeringAngle);
        }
        else if(me.input == -1 and me.steeringAngle > (-me.steeringLimit))
        {
            if(me.steeringAngle > 0)
            {
                me.steeringAngle -= me.neutralStep(me.steeringAngle);
                me.steeringAngle -= 0.2;
            }
            else
                me.steeringAngle -= me.steeringStep(me.steeringAngle);
        }

        me.command = me.steeringAngle / me.steeringLimit; #//The steering wheel could rotate for two circles and a half
        #me.steeringAngleDeg = me.steeringAngle * R2D;
        me.commandNode.setValue(me.command);
        #props.getNode("/",1).setValue("/controls/steering_wheel", me.steeringAngleDeg);
        if(me.debugMode)
        {
            print("Steering system command:" ~ me.command);
            print("Steering system angle rad:" ~ me.steeringAngle);
            print("Steering system angle degrees:" ~ me.steeringAngleDeg);
        }
    },

    inputLeft: func(){
        me.input = -1;
        if(!me.mode){
            me.command = -0.5;
            props.getNode("/",1).setValue("/controls/flight/rudder", me.command);
            #me.steeringAngleDeg = me.steeringLimit * me.command * R2D;
            #props.getNode("/",1).setValue("/controls/steering_wheel", me.steeringAngleDeg);
        }else if(me.mode and !me.timerStarted){
            me.startTimer();
        }
    },
    inputRight: func(){
        me.input = 1;
        if(!me.mode){
            me.command = 0.5;
            props.getNode("/",1).setValue("/controls/flight/rudder", me.command);
            #me.steeringAngleDeg = me.steeringLimit * me.command * R2D;
            #props.getNode("/",1).setValue("/controls/steering_wheel", me.steeringAngleDeg);
        }else if(me.mode and !me.timerStarted){
            me.startTimer();
        }
    },
    neutral: func(){
        me.input = 0;
        if(!me.mode){
            me.command = 0;
            props.getNode("/",1).setValue("/controls/flight/rudder", me.command);
            #me.steeringAngleDeg = me.steeringLimit * me.command * R2D;
            #props.getNode("/",1).setValue("/controls/steering_wheel", me.steeringAngleDeg);
        }else if(me.mode and !me.timerStarted){
            me.startTimer();
        }
    },

    steeringTimer: nil,
    timerCreated: 0,
    timerStarted: 0,
    startTimer: func(){
        if(!me.timerCreated){
            me.steeringTimer = maketimer(0.01, func me.mainLoop());
            me.timerCreated = 1;
            me.steeringTimer.simulatedTime = 1;
            if(me.debugMode) print("Steering system timer created!");
        }
        me.steeringTimer.start();
        me.timerStarted = 1;
        if(me.debugMode) print("Steering system timer started!");
    },
    stopTimer: func(){
        me.steeringTimer.stop();
        me.timerStarted = 0;
        if(me.debugMode) print("Steering system timer stopped!");
    },
};

#//Force calculation for front wheel drive(and four wheel drive)
var flForce = props.getNode("/fdm/jsbsim/external_reactions/FL");
var frForce = props.getNode("/fdm/jsbsim/external_reactions/FR");
var calculateFWForce = func(input){
    var rad = input * 45 * D2R;
    var x = math.cos(rad);
    var y = math.sin(rad);
    flForce.setValue("x", x);
    flForce.setValue("y", y);
    frForce.setValue("x", x);
    frForce.setValue("y", y);
}

var steeringAssistance = Steering.new();
var frontWheelListener = setlistener("/controls/flight/rudder", func(n){ # create listener
    calculateFWForce(n.getValue());
});

addcommand("enableAdvancedSteering", func() {
    steeringAssistance.mode = 1;
    print("Advanced Steering Enabled");
});
addcommand("disableAdvancedSteering", func() {
    steeringAssistance.mode = 0;
    print("Advanced Steering Disabled");
});
addcommand("setSteeringTravelToMin", func() {
    steeringAssistance.steeringLimit = 0.78359815;
    props.getNode("/controls/steering_wheel/steering_limit-deg", 1).setValue(steeringAssistance.steeringLimit * R2D);
    print("Steering Travel Set To 1 : 1");
});
addcommand("setSteeringTravelToNormal", func() {
    steeringAssistance.steeringLimit = 7.8539815;
    props.getNode("/controls/steering_wheel/steering_limit-deg", 1).setValue(steeringAssistance.steeringLimit * R2D);
    print("Steering Travel Set To Normal");
});
addcommand("setSteeringTravelToMax", func() {
    steeringAssistance.steeringLimit = 15.707963;
    props.getNode("/controls/steering_wheel/steering_limit-deg", 1).setValue(steeringAssistance.steeringLimit * R2D);
    print("Steering Travel Set To Max");
});
