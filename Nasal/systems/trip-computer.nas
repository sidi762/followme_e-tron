# SPDX-License-Identifier: GPL-2.0-or-later
# Smart instrument trip calculations for Sidi Liang's Follow Me EV.

# The smart dashboard uses one odometer for all trips. Each counter keeps a copy
# of the lifetime readings at its last reset. These field names also appear in aircraft-data.
var TripComputer = {
	persistentCounters: ["total", "trip1", "trip2"],
	lastSampleTime: nil, lastSpeedKmh: 0, lastPackKW: 0,

	meterSnapshot: func() {
		return {km: me.km, kWh: me.kWh, seconds: me.seconds};
	},
	resetCounter: func(name) {
		me.counters[name] = me.meterSnapshot();
	},
	resetIgnitionCounters: func() {
		# The driver can reset sinceStart during a trip. The shutdown summary uses journey.
		me.resetCounter("sinceStart");
		me.resetCounter("journey");
		me.lastSampleTime = nil;
	},
	counterDistanceKm: func(name) {
		return me.km - me.counters[name].km;
	},
	consumption: func(name) {
		var distanceKm = me.counterDistanceKm(name);
		if (distanceKm < 0.1) return nil;
		var usedKWh = me.kWh - me.counters[name].kWh;
		return 100 * usedKWh / distanceKm;
	},
	estimatedRangeKm: func(remainingKWh) {
		# Wait for a kilometre of history before extrapolating from the first acceleration.
		if (me.km < 1 or me.kWh <= 0) return nil;
		return remainingKWh * me.km / me.kWh;
	},

	sampleTrip: func() {
		var now = getprop("/fdm/jsbsim/simulation/sim-time-sec");
		if (now == nil) return;
		# The previous speed and pack power apply to the interval that just ended.
		if (me.lastSampleTime != nil) {
			var elapsedSec = math.max(0, now - me.lastSampleTime);
			me.km += me.lastSpeedKmh * elapsedSec / 3600;
			me.kWh += me.lastPackKW * elapsedSec / 3600;
			me.seconds += elapsedSec;
		}
		if (engine.engine_1.isRunning()) {
			me.lastSampleTime = now;
			me.lastSpeedKmh = math.abs(me.information.getSpeedKMH());
			me.lastPackKW = followme.circuit_1.current * followme.cSource.electromotiveForce / 1000;
		} else {
			me.lastSampleTime = nil;
		}
	},

	# FlightGear loads the history before the aircraft scripts run. Older records may omit seconds.
	readMeter: func(node) {
		var km = num(node.getValue("km"));
		var kWh = num(node.getValue("kWh"));
		var seconds = num(node.getValue("seconds")) or 0;
		if (km != nil and kWh != nil and km >= 0 and kWh >= 0 and seconds >= 0)
			return {km: km, kWh: kWh, seconds: seconds};
		return {km: 0, kWh: 0, seconds: 0};
	},
	initHistory: func() {
		me.history = props.getNode("/instrumentation/smart-dashboard/history", 1);
		var lifetime = me.readMeter(me.history);
		me.km = lifetime.km;
		me.kWh = lifetime.kWh;
		me.seconds = lifetime.seconds;
		me.counters = {};
		foreach (var name; me.persistentCounters) {
			var baseline = me.readMeter(me.history.getNode(name, 1));
			if (baseline.km > me.km or baseline.kWh > me.kWh or baseline.seconds > me.seconds)
				me.resetCounter(name);
			else
				me.counters[name] = baseline;
		}
		me.resetIgnitionCounters();
		aircraft.data.add(me.history);
	},
	writeHistory: func() {
		me.history.setValues(me.meterSnapshot());
		foreach (var name; me.persistentCounters)
			me.history.getNode(name, 1).setValues(me.counters[name]);
	},
};

