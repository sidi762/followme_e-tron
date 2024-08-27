####    Follow Me EV Wiper  ####
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

var wiper = {
    WIPER_MODE: {
        STOP: 0,
        FAST: 1,
        MID: 2,
        SLOW: 3,
    },
    mode: 0,
    controller: nil,
    pattern: [1, 1],
    switchNode: nil,
    
    new: func(wiperNode){
        var m = {parents:[wiper]};
        me.switchNode = props.globals.getNode(wiperNode~"/switch", 1);
        me.controller = aircraft.light.new(wiperNode, [1, 1], me.switchNode);
        me.controller.stateN = me.controller.node.initNode("state", 0, "DOUBLE");
        props.getNode(wiperNode,1).setValue("/switch", 0);
        return m;
    },
    Stop: func(){
        me.switchNode.setValue(0);
        mode = me.WIPER_MODE.STOP;
    },
    Fast: func(){
        me.controller.pattern = [0.5, 0.5];
        me.switchNode.setValue(1);
        me.mode = me.WIPER_MODE.FAST;
    },
    Mid: func(){
        me.controller.pattern = [0.7, 0.7];
        me.switchNode.setValue(1);
        me.mode = me.WIPER_MODE.MID;
    },
    Slow: func(){
        me.controller.pattern = [0.7, 2];
        me.switchNode.setValue(1);
        me.mode = me.WIPER_MODE.SLOW;
    },
    cycleMode: func(){
        if(me.mode == me.WIPER_MODE.STOP){
            me.Slow();
        }else if(me.mode == me.WIPER_MODE.SLOW){
            me.Mid();
        }else if(me.mode == me.WIPER_MODE.MID){
            me.Fast();
        }else if(me.mode == me.WIPER_MODE.FAST){
            me.Stop();
        }
    },

};