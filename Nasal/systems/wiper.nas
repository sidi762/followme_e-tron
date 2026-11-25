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

# Nasal owns the stalk contacts; JSBSim runs the crank until it parks.
var wiper = {
	WIPER_MODE: { STOP: 0, FAST: 1, MID: 2, SLOW: 3 },

	new: func(path, rear = 0) {
		var m = {parents: [wiper], rear: rear, mode: 0};
		m.node = props.globals.getNode(path, 1);
		m.modeNode = m.node.initNode("mode", 0, "INT");
		m.switchNode = m.node.initNode("switch", 0, "BOOL");
		m.rateNode = m.node.getNode("sweeps-per-sec", 1);
		m.pauseNode = m.node.getNode("pause-sec", 1);
		poweredAuxSwitch(path ~ "/switch");
		setlistener(m.modeNode, func(n) { m.setMode(n.getIntValue()); }, 1);
		# A direct write to the original on/off switch still operates the motor.
		setlistener(m.switchNode, func(n) {
			if (n.getBoolValue() != (m.mode != 0)) m.setMode(n.getBoolValue() ? 3 : 0);
		});
		return m;
	},

	setMode: func(mode) {
		if (mode < 0 or mode > 3) mode = 0;
		if (me.rear and mode == 1) mode = 2;
		me.mode = mode;
		if (me.modeNode.getIntValue() != mode) me.modeNode.setIntValue(mode);
		# OFF keeps the selected motor speed for the rest of an unfinished sweep.
		if (mode or !me.rateNode.getDoubleValue())
			me.rateNode.setDoubleValue(me.rear ? 1 / 1.6 : (mode == 1 ? 1 : 1 / 1.4));
		me.pauseNode.setDoubleValue(mode == 3 ? (me.rear ? 3 : 2) : 0);
		me.switchNode.setBoolValue(mode != 0);
	},

	Stop: func { me.setMode(0); },
	Fast: func { me.setMode(1); },
	Mid: func { me.setMode(2); },
	Slow: func { me.setMode(3); },
	cycleMode: func {
		var next = [3, 0, me.rear ? 0 : 1, 2];
		me.setMode(next[me.mode]);
	},
	toggleMode: func { me.cycleMode(); },
};
