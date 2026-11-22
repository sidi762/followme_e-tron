io.include("base/settings-dialog.nas");

var vehicleDialog = {
	parents: [SettingsDialog],
	_dialogName: "vehicle-dialog",
	_id: "followme-vehicle-options",
	_title: "Vehicle Options",

	_onClose: func {
		me._steerTimer.stop();
		me._steerTimer = me._syncSteering = nil;
	},

	_brakeSlider: func(y) {
		var path = "/systems/BrakeController/keyboardBrakeIntensity";
		var w = me._width - 112;
		var g = me._body.createChild("group", "brake-slider").setTranslation(0, y);
		g.createChild("path").rect(0, 0, w, 25).set("fill", me._bg);
		g.createChild("path").rect(7, 10, w - 14, 4, {"border-radius": 2}).set("fill", "#c8cad0");
		var filled = g.createChild("path").set("fill", me._blue);
		var knob = g.createChild("path").circle(7, 0, 12).set("fill", "#ffffff")
			.set("stroke", "#969aa3").set("stroke-width", 1);
		var label = me._text(me._body, w + 6, y + 12, "", 14, me._ink);
		var write = func(v) setprop(path, math.clamp(math.round(v * 100) / 100, 0.1, 1));
		var scrub = func(e) {
			var px = g.canvasToLocal([e.clientX, e.clientY])[0];
			write(0.1 + 0.9 * (px - 7) / (w - 14));
			e.stopPropagation();
		};
		me._register(g, y, nil, func(show) knob.set("stroke", show ? "#007aff" : "#969aa3"),
			func(step) write(getprop(path) + 0.01 * step));
		g.addEventListener("mousedown", scrub);
		g.addEventListener("drag", scrub);
		me._watch(path, func(v) {
			var length = math.round((w - 14) * math.clamp((v - 0.1) / 0.9, 0, 1));
			filled.reset().rect(7, 10, length, 4, {"border-radius": 2});
			knob.setTranslation(7 + length, 0);
			label.setText(sprintf("%.0f%%", 100 * v));
		});
		me._button(me._width - 60, y, 60, "Default", func write(0.8));
	},

	# Rows are deliberately kept in the same order and columns as the vehicle menu.
	_build: func {
		var w = me._width;
		var half = int((w - 6) / 2);
		var right = w - half;
		var third = int((w - 12) / 3);
		var mode = "/controls/mode";
		var welcome = "/systems/welcome-message";
		var drift = "/systems/drifting-sound";
		var y = me._heading(0, "Drive mode");
		me._choice(0, y, half, "Performance", mode, 1);
		me._choice(right, y, half, "Comfort", mode, 0.65);
		me._choice(0, y + 29, half, "Low Power", mode, 0.4);

		if (props.getNode("/fdm/jsbsim/abs/par/enabled") != nil) {
			y = me._heading(y + 65, "Braking & stability");
			me._checkbox(y, "Enable ABS", "/fdm/jsbsim/abs/par/enabled");
			me._checkbox(y + 27, "Enable traction control (TC)", "/fdm/jsbsim/tc/par/enabled");
			me._checkbox(y + 54, "Enable stability control (ESC)", "/fdm/jsbsim/esc/par/enabled");
			y += 25;
		}

		y = me._heading(y + 65, "Realistic steering");
		var on = me._button(0, y, half, "Enable", func { followme.enableAdvancedSteering(); vehicleDialog._syncSteering(); });
		var off = me._button(right, y, half, "Disable", func { followme.disableAdvancedSteering(); vehicleDialog._syncSteering(); });
		var last = nil;
		me._syncSteering = func {
			var v = followme.steeringAssistance.mode;
			if (v == last) return;
			last = v;
			on(v == 1); off(v == 0);
		};
		me._syncSteering();
		var dialog = me;
		me._steerTimer = maketimer(0.25, func dialog._syncSteering());
		me._steerTimer.start();
		me._text(me._body, 0, y + 36, "Experimental. Set steering travel to Normal.", 12, me._secondary);

		y = me._heading(y + 54, "Keyboard braking intensity");
		me._brakeSlider(y);
		y = me._heading(y + 36, "Welcome message & startup sound");
		me._button(0, y, half, "Set Startup Sound…", func smartInstruments.setStartupSound_dlg.open());
		me._choice(right, y, half, "Message Off", welcome, 0);
		me._choice(0, y + 29, third, "Chinese", welcome, 1);
		me._choice(third + 6, y + 29, third, "English", welcome, 2);
		me._choice(2 * (third + 6), y + 29, w - 2 * (third + 6), "Special", welcome, 3);

		y = me._heading(y + 65, "Drift sound");
		me._choice(0, y, half, "Enable", drift, 1);
		me._choice(right, y, half, "Disable", drift, 0);
		var configWidth = math.min(270, w);
		me._button(int((w - configWidth) / 2), y + 35, configWidth, "Vehicle Configuration…", func dialogs.configDialog.open());

		y = me._heading(y + 71, "Rescue");
		me._button(0, y, half, "Flip Vehicle", func {
			setprop("/orientation/roll-deg", 0);
			setprop("/velocities/groundspeed-kt", 0);
		});
		me._button(right, y, half, "Quick Recharge", func followme.quickRecharge());
		me._button(0, y + 29, half, "Reset Airbag", func followme.safety.reset());
		me._button(right, y + 29, half, "Reset Here", func followme.resetOnPosition());
		me._text(me._body, 0, y + 65, "Airbag reset disables the safety system.", 12, me._secondary);

		y = me._heading(y + 83, "Engine");
		var running = me._text(me._body, w, y - 12, "", 12, me._secondary, 0, "right-center");
		me._watch("/controls/engines/engine/started", func(v) running.setText(v == 1 ? "Running" : "Stopped"));
		me._button(0, y, half, "Start Engine", func engine.startEngine(engine.engine_1));
		me._button(right, y, half, "Stop Engine", func engine.stopEngine(engine.engine_1));
		y = me._heading(y + 36, "Miscellaneous");
		var path = "/systems/enable_als_lights";
		me._checkbox(y, "Enable ALS procedural lights", path);
		me._text(me._body, 0, y + 35, "For older versions without Compositor.", 12, me._secondary);
		return y + 43;
	},
};
