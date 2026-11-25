####    Follow Me EV Lights   ####
####    Sidi Liang    ####

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


var warningLight = aircraft.light.new("/sim/model/lights/warning", [0.5, 0.5], "/controls/lighting/warning" );

# The dial has OFF, AUTO, position and dipped detents. Existing lighting users
# (including the keyboard and multiplayer lamps) still read the effective 0/1/2.
var headlightSelector = props.globals.initNode("/controls/lighting/headlight-selector", 0, "INT");
var headlightLevel = props.globals.initNode("/controls/lighting/headlight-level", 0, "INT");
var panelBrightness = props.globals.initNode("/controls/lighting/instrument-brightness", 1);

# Higher thumbwheel numbers aim the dipped beams lower; the cluster dimmer is independent.
var adjustHeadlightLevel = func(step, wrap = 0) {
	var level = headlightLevel.getIntValue() + step;
	headlightLevel.setIntValue(wrap ? math.mod(level + 4, 4) : math.clamp(level, 0, 3));
	gui.popupTip("Headlamp level " ~ headlightLevel.getIntValue());
};
var adjustPanelBrightness = func(step) {
	panelBrightness.setDoubleValue(math.clamp(panelBrightness.getDoubleValue() + 0.1 * step, 0.3, 1));
};

var sunAngle = props.globals.getNode("/sim/time/sun-angle-rad", 1);
var effectiveHeadlights = func {
	var detent = headlightSelector.getValue();
	if (detent == 1) return sunAngle.getDoubleValue() >= 1.50 ? 2 : 0;
	return detent > 1 ? detent - 1 : 0;
};
var applyHeadlights = func {
	var level = effectiveHeadlights();
	if (vInfo.lighting.headlight.getValue() != level)
		vInfo.lighting.headlight.setIntValue(level);
};
var stepHeadlightSelector = func(direction, wrap = 0) {
	var next = headlightSelector.getValue() + direction;
	headlightSelector.setIntValue(wrap ? math.mod(next + 4, 4) : math.clamp(next, 0, 3));
};
setlistener(headlightSelector, applyHeadlights);
setlistener(sunAngle, func { if (headlightSelector.getValue() == 1) applyHeadlights(); });
setlistener(vInfo.lighting.headlight, func(n) {
	var level = n.getIntValue();
	if (level != effectiveHeadlights())
		headlightSelector.setIntValue(level == 0 ? 0 : level + 1);
}, 1);

# Fog switches retain their positions if the auxiliary bus loses power.
var frontFogPowered = poweredAuxSwitch("/controls/lighting/front-fog");
var rearFogPowered = poweredAuxSwitch("/controls/lighting/rear-fog");

var Indicator = {

    #     Usage:                                        #
    #  var leftIndicator = Indicator.new("left");       #
    #  var rightIndicator = Indicator.new("right");     #
    #                                                   #

    type: "",
    new: func(type) { 
        var newIndicator = { parents:[Indicator] };
        newIndicator.type = type;  
        newIndicator.powered = poweredAuxSwitch("/controls/lighting/indicator-" ~ type);
        newIndicator.lamp = props.globals.getNode("/sim/model/lights/indicator-" ~ type ~ "/state", 1);
        return newIndicator;
    },
    state: 0,
    switchOn: func(){
        props.getNode("/", 1).setValue("/controls/lighting/indicator-"~me.type, 1);
        me.state = 1;
    },
    switchOff: func(){
        props.getNode("/", 1).setValue("/controls/lighting/indicator-"~me.type, 0);
        me.state = 0;
    },
    isOn: func(){
        return me.state;
    },
    isOff: func(){
        return !me.state;
    },
};

var IndicatorController = {
    #   Usage:
    #       mode:see IND_MODES
    #       getMode(): Get currrent mode
    #       setMode(mode): Set mode, return 0 if fail
    #                      args can be 0, 1, 2, or better, use IND_MODES

    IND_MODES: {   # Indicator modes
        OFF: 0,
        RIGHT_WITHOUT_LED: 1,
        LEFT_WITHOUT_LED: 2,
        BOTH_WITHOUT_LED: 3,
        RIGHT_WITH_LED: 4,
        LEFT_WITH_LED: 5,
        BOTH_WITH_LED: 6 # WIP
    },

    new: func() {
        var m = { parents: [IndicatorController] };
        var left = m.leftIndicator;
        var right = m.rightIndicator;
        var relay = props.globals.getNode("/sim/model/lights/indicator-relay", 1);
        # 0 is silent at startup. +1 and -1 select the two recorded contacts.
        relay.setIntValue(0);
        var setPhase = func(phase) {
            left.lamp.setBoolValue(phase == 1 and left.powered.getBoolValue());
            right.lamp.setBoolValue(phase == 1 and right.powered.getBoolValue());
            relay.setIntValue(phase);
        };
        # Successive clicks in indicatorFlashing.wav are 0.4 seconds apart.
        var timer = maketimer(0.4, func { setPhase(-relay.getValue()); });
        timer.simulatedTime = 1;
        var refresh = func {
            var phase = relay.getValue();
            if (left.powered.getBoolValue() or right.powered.getBoolValue()) {
                if (!timer.isRunning) {
                    phase = 1;
                    timer.start();
                }
            } elsif (timer.isRunning) {
                timer.stop();
                phase = -1;
            }
            setPhase(phase);
        };
        setlistener(left.powered, refresh, 0, 0);
        setlistener(right.powered, refresh, 1, 0);

        m.stalkPosition = vInfo.lighting.indicator.getNode("stalk-position-norm", 1);
        m.stalkPosition.setDoubleValue(0);
        setlistener(m.stalkPosition, func(node) {
            var pos = node.getValue();
            m.leftIndicatorSwitchNode.setDoubleValue(math.max(0, pos));
            m.rightIndicatorSwitchNode.setDoubleValue(math.max(0, -pos));
            # The contacts close at the detents and open as the stalk leaves them.
            var modes = m.IND_MODES;
            if (pos == 1) m.setMode(modes.LEFT_WITH_LED);
            elsif (pos == -1) m.setMode(modes.RIGHT_WITH_LED);
            elsif (m.mode == modes.LEFT_WITH_LED or m.mode == modes.RIGHT_WITH_LED)
                m.setMode(modes.OFF);
        }, 1, 0);
        return m;
    },

    leftIndicator: Indicator.new("left"),
    rightIndicator: Indicator.new("right"),

    leftIndicatorSwitchNode: vInfo.lighting.indicator.leftSwitch,
    rightIndicatorSwitchNode: vInfo.lighting.indicator.rightSwitch,

    mode:0,

    falseLight: 0,

    ledMessage: props.getNode("/sim/model/livery/texture",1),
    ledMessageName: props.getNode("/sim/model/livery/name",1),

    savedMessage:{
        texture: "",
        name: "",
    },

    textureRight: {
        texture:"Messages/right.png",
        name: "Right",
    },
    textureLeft: {
        texture:"Messages/left.png",
        name: "Left",
    },

    saveLedMessage: func(){
        me.savedMessage.texture = me.ledMessage.getValue();
        me.savedMessage.name = me.ledMessageName.getValue();
    },
    getSavedMessage: func(){
        return me.savedMessage;
    },
    clearSavedMessage: func(){
        me.savedMessage.texture = "";
        me.savedMessage.name = "";
    },
    setLedMessage: func(content){
        me.ledMessage.setValue(content.texture or " ");
        me.ledMessageName.setValue(content.name or " ");
    },
    resumeLedMessage: func(){
        if(me.getSavedMessage().name != ""){
            me.setLedMessage(me.getSavedMessage());
            me.clearSavedMessage();
        }
    },

    getMode: func(){
        return me.mode;
    },
    setMode: func(targetMode){
        if(targetMode == me.IND_MODES.OFF and me.falseLight){
            targetMode = me.IND_MODES.BOTH_WITHOUT_LED;
        }
        if(targetMode == me.IND_MODES.OFF){
            me.resumeLedMessage();
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOff();
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.RIGHT_WITHOUT_LED){
            me.resumeLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOff();
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.LEFT_WITHOUT_LED){
            me.resumeLedMessage();
            me.leftIndicator.switchOn();
            me.rightIndicator.switchOff();
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.BOTH_WITHOUT_LED){
            me.resumeLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOn();
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.RIGHT_WITH_LED){
            me.resumeLedMessage();
            me.saveLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOff();
            me.setLedMessage(me.textureRight);
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.LEFT_WITH_LED){
            me.resumeLedMessage();
            me.saveLedMessage();
            me.leftIndicator.switchOn();
            me.rightIndicator.switchOff();
            me.setLedMessage(me.textureLeft);
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.BOTH_WITH_LED){
            # WIP
            me.mode = targetMode;
        }else{
            die("Invalid mode");
        }
    },

    stalkTarget: 0, # +1 left, 0 neutral, -1 right
    stalkTravelSec: 0.24, # center to detent, estimated from IndicatorEnd.wav

    toggleStalk: func(side) {
        me.stalkTarget = me.stalkTarget == side ? 0 : side;
        if (isInternalView()) playAudio(file: "IndicatorEnd.wav", queue: "instant");
        var distance = math.abs(me.stalkTarget - me.stalkPosition.getValue());
        interpolate(me.stalkPosition, me.stalkTarget, distance * me.stalkTravelSec);
    },
    right_indicator_toggle: func {
        me.toggleStalk(-1);
        return 0;
    },
    left_indicator_toggle: func {
        me.toggleStalk(1);
    },

    falseLightOn: func(){
        if(isInternalView()) playAudio("electric_handbrake.wav");
        me.falseLight = 1;
        #//origin: 1,2,4,5
        if(me.mode == me.IND_MODES.RIGHT_WITHOUT_LED or
           me.mode == me.IND_MODES.LEFT_WITHOUT_LED  or 
           me.mode == me.IND_MODES.RIGHT_WITH_LED    or 
           me.mode == me.IND_MODES.LEFT_WITH_LED){
           print("falseLight mode on");
        }else{
            me.setMode(me.IND_MODES.BOTH_WITHOUT_LED);
            print("falseLight turned on");
        }

    },
    falseLightOff: func(){
        if(isInternalView()) playAudio("electric_handbrake.wav");
        me.falseLight = 0;
        #//origin: 1,2,4,5
        if(me.mode == me.IND_MODES.RIGHT_WITHOUT_LED or
           me.mode == me.IND_MODES.LEFT_WITHOUT_LED  or 
           me.mode == me.IND_MODES.RIGHT_WITH_LED    or 
           me.mode == me.IND_MODES.LEFT_WITH_LED){
           print("falseLight mode off");
        }else{
            me.setMode(0);
            print("falseLight turned off");
        }
    },
    false_light_toggle: func(){
        if(me.falseLight == 0){
            me.falseLightOn();
        }else if(me.falseLight == 1){
            me.falseLightOff();
        }
    },
};

#var Led = {
#
#    new: func() { return { parents:[Led] },
#    node: props.getNode("/sim/model/livery/texture",1),
#    blankTexture: "Messages/blanco.png",
#    currentMessage: "",
#    messageHistory : [],
#
#    display: func(content){
#        me.node.setValue(content);
#    },
#
#
#};
