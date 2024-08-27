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

var Indicator = {

    #     Usage:                                        #
    #  var leftIndicator = Indicator.new("left");       #
    #  var rightIndicator = Indicator.new("right");     #
    #                                                   #

    type: "",
    new: func(type) { 
        var newIndicator = { parents:[Indicator] };
        newIndicator.type = type;  
        newIndicator.fgLight = aircraft.light.new("/sim/model/lights/indicator-"~type, [0.5, 0.5], "/controls/lighting/indicator-"~type);
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

    new: func() { return { parents:[IndicatorController]}; },

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
        if(targetMode == me.IND_MODES.OFF){
            me.resumeLedMessage();
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOff();
            me.mode = targetMode;
            if(me.falseLight == 1){
                me.setMode(me.IND_MODES.BOTH_WITHOUT_LED);
            }
        }else if(targetMode == me.IND_MODES.RIGHT_WITHOUT_LED){
            me.resumeLedMessage();
            me.rightIndicator.switchOn();
            me.leftIndicator.switchOff();
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.LEFT_WITHOUT_LED){
            me.resumeLedMessage();
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOn();
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
            me.rightIndicator.switchOff();
            me.leftIndicator.switchOn();
            me.setLedMessage(me.textureLeft);
            me.mode = targetMode;
        }else if(targetMode == me.IND_MODES.BOTH_WITH_LED){
            # WIP
            me.mode = targetMode;
        }else{
            die("Invalid mode");
        }
    },

    right_indicator_toggle: func(){
        if(isInternalView()) playAudio('IndicatorEnd.wav');

        if(me.getMode() != me.IND_MODES.RIGHT_WITH_LED){
            me.setMode(me.IND_MODES.RIGHT_WITH_LED);
            me.rightIndicatorSwitchNode.setValue(1);
            me.leftIndicatorSwitchNode.setValue(0);
            return 0;
        }else if(me.getMode() == me.IND_MODES.RIGHT_WITH_LED){
            me.setMode(me.IND_MODES.OFF);
            me.rightIndicatorSwitchNode.setValue(0);
            return 0;
        }else{
            return -1;
        }
    },
    left_indicator_toggle: func(){
        if(isInternalView()) playAudio('IndicatorEnd.wav');
        if(me.getMode() != me.IND_MODES.LEFT_WITH_LED){
            me.setMode(me.IND_MODES.LEFT_WITH_LED);
            me.leftIndicatorSwitchNode.setValue(1);
            me.rightIndicatorSwitchNode.setValue(0);
        }else if(me.getMode() == me.IND_MODES.LEFT_WITH_LED){
            me.setMode(me.IND_MODES.OFF);
            me.leftIndicatorSwitchNode.setValue(0);
        }
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