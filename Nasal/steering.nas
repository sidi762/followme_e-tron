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
        return steering;
    },

    mode: 0, #//0: direct; 1: advanced

    debugMode: 0,

    input: 0, #//-1: left, 1:right, 0: none
    command: 0, #//Steering command, range from -1 to 1
    commandNode: props.getNode("/controls/flight/rudder", 1),
    steeringAngle: 0, #//in rad
    #steeringAngleDeg: 0, #//in degrees

    #//steeringLimit: 7.8539815, #// 2.5 * 3.1415926 = 7.8539815 5 * 3.1415926 = 15.707963 3.1415926 / 4 = 0.78359815
    steeringLimit: 15.707963,


    powPointThree: memoize.new( func(value){
        return math.pow(value, 0.3);
    }),

    powPointOne: memoize.new( func(value){
        return math.pow(value, 0.1);
    }),

    steeringStep:func(rad){
        return 0.1 * me.powPointOne.lookup(sprintf("%.1f", math.abs(rad))) + 0.04;
    },
    neutralStep: func(rad){
        var speed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
        return 0.03 * me.powPointThree.lookup(sprintf("%.1f", math.abs(speed))) * math.abs(rad);
    },

    mainLoop: func(){
        if(me.input == 0)
        {
            if(math.abs(me.steeringAngle) <=0.2)
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
            else if(me.steeringAngle >= 0.05)
                me.steeringAngle -= me.neutralStep(me.steeringAngle);
            else if(me.steeringAngle <= -0.05)
                me.steeringAngle += me.neutralStep(me.steeringAngle);
        }
        else if(me.input == 1 and me.steeringAngle < me.steeringLimit)
        {
            if(me.steeringAngle < 0)
            {
                me.steeringAngle += me.neutralStep(me.steeringAngle);
                me.steeringAngle += 0.35 * me.input;
            }
            else
                me.steeringAngle += me.steeringStep(me.steeringAngle);
        }
        else if(me.input == -1 and me.steeringAngle > (-me.steeringLimit))
        {
            if(me.steeringAngle > 0)
            {
                me.steeringAngle -= me.neutralStep(me.steeringAngle);
                me.steeringAngle -= 0.35;
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
