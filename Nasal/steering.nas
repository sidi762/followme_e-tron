#//Followme EV steering system by Liang Sidi
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
        #// print("cached:",found,"\n");
        return found;
    }
    #// print("Calculated:", value);
    return me._save(value);
}

var Steering = {
    #// Provides functionality for for both direct and advanced steering modes
    #// of the followme EV. The realistic mode includes a timer-driven main
    #// loop for continuous control utilizing the Pacejka tire model for
    #// realistic centerring of the steering wheel.

    #// Usage (in set.xml for key bindings):
    #// <key n="97">
    #//  <name>a</name>
    #//  <desc>rudder-left</desc>
    #//  <repeatable>false</repeatable>
    #//      <binding>
    #//          <command>nasal</command>
    #//          <script>followme.steeringAssistance.inputLeft();</script>
    #//      </binding>
    #//      <mod-up>
    #//          <binding>
    #//              <command>nasal</command>
    #//              <script>followme.steeringAssistance.neutral();</script>
    #//          </binding>
    #//      </mod-up>
    #//  </key>

    new: func() {
        var steering = { parents:[Steering] };
        props.getNode("/controls/steering_wheel/steering_limit-deg", 1).setValue(steering.steeringLimit * R2D);
        steering.debugNodeB.setValue(20);
        steering.debugNodeC.setValue(2.1);
        steering.debugNodeD.setValue(16000);
        steering.debugNodeE.setValue(0.97);
        steering.debugNodeFactor.setValue(0.02);
        print("Steering system initialized!");
        return steering;
    },

    mode: 0, #// 0: direct; 1: realistic (formerly advanced)
    debugMode: 0, #// Debug mode flag

    rudderNode: props.getNode("/controls/flight/rudder"),

    input: 0, #// -1: left, 1:right, 0: none
    command: 0, #// Steering command, range from -1 to 1
    commandNode: props.getNode("/controls/flight/rudder", 1),
    velocityNode: props.getNode("sim/multiplay/generic/float[15]", 1),
    slipAngleNode: props.getNode("/fdm/jsbsim/gear/unit/slip-angle-deg", 1),
    debugNodeB: props.getNode("/debug/steering/B", 1),
    debugNodeC: props.getNode("/debug/steering/C", 1),
    debugNodeD: props.getNode("/debug/steering/D", 1),
    debugNodeE: props.getNode("/debug/steering/E", 1),
    debugNodeFactor: props.getNode("/debug/steering/factor", 1),
    steeringAngle: 0, #// in rad

    #// Calculations for steeringLimit:
    #// 2.5 * 3.1415926 = 7.8539815 (Normal)
    #// 5 * 3.1415926 = 15.707963 (Long)
    #// 3.1415926 / 4 = 0.78359815 (1:1)
    #//Defaults to Long as it looks the best under Direct mode
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
        #// Magic. Don't touch.
        var speed = me.velocityNode.getValue();
        var ret = 0.1 * me.powPointOne.lookup(sprintf("%.1f", math.abs(rad)));
        ret -= 0.022 * me.powPointThree.lookup(sprintf("%.1f", math.abs(speed)));
        #ret = math.min(ret, 0);
        ret *= 1.1;
        ret = math.max(ret, 0.011);
        return ret;
    },

    neutralStep: func(rad){
        # Approximation Constants for Missing Geometry Parameters
        var casterAngle = 0.1; # in radians, use a value between 0.05 and 0.2 for typical vehicles
        var tireStiffness = 3000; # in N/rad, adjust based on tire properties
        var tireWidth = 0.225; # in meters, approximate value for tire width
        # Constants for the tire model (empirical parameters)
        var B = 20;
        var C = 2.1;
        var D = 16000;
        var E = 0.97;
        #var B = me.debugNodeB.getValue();
        #var C = me.debugNodeC.getValue();
        #var D = me.debugNodeD.getValue();
        #var E = me.debugNodeE.getValue();

        # Vehicle Speed
        var speed = me.velocityNode.getValue(); # in kts
        speed *= 0.514444; # Convert knots to meters per second (1 knot ≈ 0.514444 m/s)

        # Tire Properties
        var tireSlipAngle = 0;
        if(speed > 1.5){
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

        #var factor = me.debugNodeFactor.getValue();
        var factor = 0.02;
        # Calculate steering change based on self-centering force and tire stiffness
        var steeringChange = (Fsc / tireStiffness) * factor; # adjust the factor to control the self-centering strength

        # Apply the change to the steering angle
        return steeringChange;
    },

    mainLoop: func(){
        #// Main loop for realistic mode, triggered by the timer.
        var steeringAngle = me.steeringAngle;
        if(me.input == 0){
            if(math.abs(steeringAngle) <= 0.01){
                steeringAngle = 0;
                me.command = steeringAngle / me.steeringLimit; #//The steering wheel could rotate for two circles and a half
                me.commandNode.setValue(me.command);
            }
            if(steeringAngle == 0){
                me.stopTimer(); #// Stop the timer when not needed
                return 0;
            }
            else if(steeringAngle >= 0.01)
                steeringAngle -= math.min(me.neutralStep(steeringAngle), steeringAngle);
            else if(me.steeringAngle <= -0.01)
                steeringAngle += math.min(me.neutralStep(steeringAngle), -steeringAngle);
        }
        else if(me.input == 1 and steeringAngle < me.steeringLimit){
            if(steeringAngle < 0){
                steeringAngle += me.neutralStep(steeringAngle);
                steeringAngle += math.min(0.15, -steeringAngle);
            }
            else
                steeringAngle += me.steeringStep(steeringAngle);
        }
        else if(me.input == -1 and steeringAngle > (-me.steeringLimit)){
            if(steeringAngle > 0){
                steeringAngle -= me.neutralStep(steeringAngle);
                steeringAngle -= math.min(0.15, steeringAngle);
            }
            else
                steeringAngle -= me.steeringStep(steeringAngle);
        }

        me.command = steeringAngle / me.steeringLimit; #// The steering wheel could rotate for two circles and a half
        #me.steeringAngleDeg = me.steeringAngle * R2D;
        me.commandNode.setValue(me.command);
        me.steeringAngle = steeringAngle;
        if(me.debugMode){
            print("Steering system command:" ~ me.command);
            print("Steering system angle rad:" ~ me.steeringAngle);
            print("Steering system angle degrees:" ~ me.steeringAngleDeg);
        }
    },

    inputLeft: func(){
        me.input = -1;
        if(!me.mode){
            #// Direct Mode
            me.command = -0.5;
            me.rudderNode.setValue(me.command);
        }else if(me.mode and !me.timerStarted){
            #// Start timer for realistic mode if not done yet
            me.startTimer();
        }
    },
    inputRight: func(){
        me.input = 1;
        if(!me.mode){
            #// Direct Mode
            me.command = 0.5;
            me.rudderNode.setValue(me.command);
        }else if(me.mode and !me.timerStarted){
            #// Start timer for realistic mode if not done yet
            me.startTimer();
        }
    },
    neutral: func(){
        me.input = 0;
        if(!me.mode){
            #// Direct Mode
            me.command = 0;
            me.rudderNode.setValue(me.command);
        }else if(me.mode and !me.timerStarted){
            #// Start timer for realistic mode if not done yet
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
var flForceNode = props.getNode("/fdm/jsbsim/external_reactions/FL");
var frForceNode = props.getNode("/fdm/jsbsim/external_reactions/FR");
var calculateFWForce = func(input){
    var rad = input * 45 * D2R;
    var x = math.cos(rad);
    var y = math.sin(rad);
    flForceNode.setValue("x", x);
    flForceNode.setValue("y", y);
    frForceNode.setValue("x", x);
    frForceNode.setValue("y", y);
}

var steeringAssistance = Steering.new();
#//For front wheel drive(and four wheel drive)
var frontWheelListener = setlistener("/controls/flight/rudder", func(n){ # create listener
    calculateFWForce(n.getValue());
});

#// FGCommands for setting the steering system
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
