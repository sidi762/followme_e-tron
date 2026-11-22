io.include("base/settings-dialog.nas");

var configDialog = {
	parents: [SettingsDialog],
	_dialogName: "config-dialog",
	_id: "followme-vehicle-config",
	_title: "Vehicle Configuration",

	_onClose: func { followme.playAudio("repair.wav"); },

	_build: func {
		var w = me._width;
		var half = int((w - 6) / 2);
		var right = w - half;
		var third = int((w - 12) / 3);
		var y = me._heading(0, "Interior style");
		me._dropdown(y, w, "/systems/interior/type", ["404Design (Default)", "404Design 2.0",
			"404Design 2022", "404Design 2023", "Luxury", "Luxury 2.0", "Race", "Sport (Legacy)", "Followme Original"]);

		y = me._heading(y + 37, "Steering wheel travel");
		var normal = me._button(0, y, third, "Normal", func followme.setSteeringTravelToNormal());
		var longTravel = me._button(third + 6, y, third, "Long", func followme.setSteeringTravelToMax());
		var direct = me._button(0, y + 29, third, "1:1", func followme.setSteeringTravelToMin());
		me._watch("/controls/steering_wheel/steering_limit-deg", func(v) {
			normal(v != nil and math.abs(v - 450) < 1);
			longTravel(v != nil and math.abs(v - 900) < 1);
			direct(v != nil and math.abs(v - 45) < 1);
		});

		y = me._heading(y + 65, "Speedometer");
		me._dropdown(y, math.min(250, w), "/systems/speedometer/type",
			["None", "Type_A", "Type_M", "Type_B", "Type_BT", "Concept", "Original"]);
		y = me._heading(y + 37, "Battery gauge");
		me._dropdown(y, math.min(250, w), "/systems/battery-gauge/type",
			["None", "Type_A", "Type_M", "Type_BT", "Concept", "Original"]);

		y += 38;
		me._button(0, y, half, "Toggle Parking Radar", func followme.toggleParkingRadar());
		me._button(right, y, half, "Initialize Safety", func followme.safety.init());
		me._button(0, y + 29, half, "Disable Safety", func followme.safety.stop());
		me._button(right, y + 29, half, "Toggle AEB", func followme.safety.toggleAEB());
		me._text(me._body, 0, y + 65, "Initialize safety to repair the airbags.", 12, me._secondary);

		y = me._heading(y + 83, "Magic Bush Tyre");
		me._button(0, y, half, "Enable", func followme.reduceRollingFriction());
		me._button(right, y, half, "Disable", func followme.resumeRollingFriction());

		y = me._heading(y + 37, "License plate");
		followme.plateSelector.updateList();
		me._dropdown(y, w, "/systems/plate/name", followme.plateSelector.items);
		me._watch("/systems/plate/name", func(name) {
			var file = name == "NONE" ? "NONE" : "texture/" ~ name ~ ".png";
			setprop("/systems/plate/file", file);
			setprop("/systems/rear_plate/file", name == "NONE" ? "plate/texture/e-tron.png" : "plate/" ~ file);
		}, 0);

		y += 38;
		me._button(0, y, half, "Select Livery…", func liveries.liverySelector.dialog.open());
		me._button(right, y, half, "Select Message…", func liveries.displaySelector.dialog.open());
		# Only the tyre model's FDM carries the occupants' weight. The co-driver
		# below adds /systems/occupants/codriver-kg on the rear right seat.
		if (props.getNode("/fdm/jsbsim/occupants/driver_lbs") != nil) {
			y = me._heading(y + 37, "Driver weight");
			var quarter = int((w - 18) / 4);
			var weights = [50, 60, 75, 90];
			forindex (var i; weights)
				me._choice(i * (quarter + 6), y, quarter, weights[i] ~ " kg", "/systems/occupants/driver-kg", weights[i]);
		}
		y = me._heading(y + 37, "Miscellaneous");
		me._checkbox(y, "Enable co-driver model", "/systems/codriver-enable");
		me._checkbox(y + 27, "Enable smart screen", "/systems/screen-enable");
		me._checkbox(y + 54, "Enable switches", "/systems/instruments/enable_switches");
		me._checkbox(y + 81, "Enable decorations", "/systems/decorations-enable");
		return y + 106;
	},
};
