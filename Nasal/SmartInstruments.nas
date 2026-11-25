#// Smart Instruments by Sidi Liang for follow me EV
#// Contact: sidi.liang@gmail.com

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

io.include("systems/trip-computer.nas");

var artDir = "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/";
var menu = ["assist", "tyres", "flow", "compass", "range", "total", "sinceStart", "trip1", "trip2", "media", "navigation"];
var art = {
    assist: "1.0_on", tyres: "1.1", flow: "1.3", compass: "1.4", radar: "1.5",
    range: "2.1", total: "2.2", sinceStart: "2.3", trip1: "2.4", trip2: "2.5",
    media: "3", navigation: "4", aeb: "_AEB", charge: "_charge",
    standby: "_start", selfTest: "_self_test", summary: "_summary",
};

var formatConsumption = func(kWhPer100Km) {
	return (kWhPer100Km == nil ? "--" : sprintf("%.1f", kWhPer100Km)) ~ " kWh/100km";
};

var panelText = func(group, x, y, height, align="center-center", font="ExoRegular-ymMe.ttf") {
    return group.createChild("text").setTranslation(x, y).setAlignment(align)
                .setFont(font).setFontSize(height).setColor(1, 1, 1);
};
var panelImage = func(group, file) {
    return group.createChild("image").setFile(artDir ~ file).setSize(1509, 736);
};

var RadarBumperDisplay = {
	new: func(group, drawing, sensor, end, sides, textX) {
		var m = {parents: [RadarBumperDisplay], sensor: sensor, sectors: []};
		m.distanceText = panelText(group, textX, 294, 30, "left-center");
		foreach (var side; sides) {
			var bands = [];
			foreach (var level; ["near", "mid", "far"])
				append(bands, drawing.getElementById(end ~ "-" ~ side ~ "-" ~ level));
			append(m.sectors, bands);
		}
		return m;
	},
	bandForDistance: func(distance) {
		var radar = me.sensor;
		if (!radar.isRunning or distance == nil or distance > radar.maxRange) return -1;
		# The red band starts at the same distance as the continuous parking tone.
		if (distance <= radar.continuousDistance) return 0;
		if (distance <= (radar.continuousDistance + radar.maxRange) / 2) return 1;
		return 2;
	},
	update: func() {
		var radar = me.sensor;
		var nearestBand = me.bandForDistance(radar.radarOutput);
		me.distanceText.setText(nearestBand < 0 ? "--" : sprintf("%.1f m", radar.radarOutput));
		me.distanceText.set("fill", nearestBand < 0 ? "#93a8bf" : me.sectors[1][nearestBand].get("fill"));
		forindex (var side; me.sectors) {
			var level = me.bandForDistance(radar.sectorRanges[side]);
			forindex (var band; me.sectors[side])
				me.sectors[side][band].setVisible(band == level);
		}
	},
};

var SmartInstruments = {
	parents: [TripComputer],
    new: func(placement) {
        var m = {parents: [SmartInstruments]};
        m.instrumentCanvas = canvas.new({name: "smartInstruments", size: [8192, 4096], view: [1509, 736], mipmapping: 0});
        m.instrumentCanvas.addPlacement({node: placement});
        m.information = followme.vInfo;
        m.backgroundImage = panelImage(m.instrumentCanvas.createGroup(), "dashboard0.png");
        m.infoImage = panelImage(m.instrumentCanvas.createGroup(), "dashboard_start.png");
        m.gaugeGroup = m.instrumentCanvas.createGroup();
        var digits = "trueno-font/Trueno-wml2.ttf";
        m.speedometer = panelText(m.gaugeGroup, 1205, 380, 148,"center-center", digits);
        m.power = panelText(m.gaugeGroup, 295, 380, 148,"center-center", digits);
        m.batteryRemainingDisplay = panelText(m.gaugeGroup, 312, 542, 30);
        m.driveMode = panelText(m.gaugeGroup, 780, 628, 40);
        m.gearDisplay = panelText(m.gaugeGroup, 940, 620, 70);
        m.tempDisplay = panelText(m.gaugeGroup, 420, 220, 30,"left-center");
        m.timeDisplay = panelText(m.gaugeGroup, 1055, 215, 40,"right-center");
        m.tripDisplay = panelText(m.gaugeGroup, 510, 630, 25,"right-center");
        m.distanceDisplay = panelText(m.gaugeGroup, 1020, 630, 25,"left-center");

        m.signGroup = m.instrumentCanvas.createGroup();
        canvas.parsesvg(m.signGroup, artDir ~ "dashboard.svg");
        m.airbagSign = m.signGroup.getElementById("airbag_sign");
        m.handBrakeSign = m.signGroup.getElementById("handbrake_sign");
        m.autoholdSign = m.signGroup.getElementById("autohold_sign");
        m.headlightSign = m.signGroup.getElementById("headlight_sign");
        m.positionLightSign = m.signGroup.getElementById("positionlight_sign");
        m.highbeamSign = m.signGroup.getElementById("highbeam_sign");
        m.foglightSign = m.signGroup.getElementById("foglight_sign");
        m.escOffSign = m.signGroup.getElementById("escoff_sign");
        m.escSign = m.signGroup.getElementById("esc_sign");
        m.readySign = m.signGroup.getElementById("ready_sign");
        m.autopilotSign = m.signGroup.getElementById("zidongshengtian_sign");
        m.cruiseSign = m.signGroup.getElementById("cruise_sign");


        m.warningText = panelText(m.instrumentCanvas.createGroup(), 755, 102, 36).setColor(1, 0.22, 0.12);
        m.doors = [followme.frontleft_door, followme.frontright_door, followme.rearleft_door,
                   followme.rearright_door, followme.charging_cap];
        m.details = {};
        foreach (var name; ["doors","charge","summary","range","consumption","flow","compass","assist","radar"]) {
            m.details[name] = m.instrumentCanvas.createGroup();
            m.details[name].hide();
        }
        m.doorIcons = [];
        foreach (var name; ["FL","FR","RL","RR"])
            append(m.doorIcons, panelImage(m.details.doors, "doors/dashboard_Door_" ~ name ~ ".png"));
        m.capLabel = panelText(m.details.doors, 754, 545, 24).setText("CHARGE PORT");
        m.chargeStatus = panelText(m.details.charge, 754, 548, 30);
        m.summaryRows = [];
        foreach (var y; [305, 368, 432, 497])
            append(m.summaryRows, panelText(m.details.summary, 952, y, 30, "right-center"));
        m.summaryRows[3].setFontSize(24);
        m.rangeKm = panelText(m.details.range, 801, 347, 46,"right-center");
        m.rangePercent = panelText(m.details.range, 801, 478, 46,"right-center");
        m.consumptionValue = panelText(m.details.consumption, 754, 364, 35);
        var barOrigin = m.details.consumption.createChild("group").setTranslation(596, 418);
        m.barFill = barOrigin.createChild("path").rect(0, 0, 317, 43).setColorFill(0.54, 0.86, 1, 0.74);
        m.consumptionPointer = m.details.consumption.createChild("path")
            .moveTo(-8, 0).lineTo(8, 0).lineTo(0, 16).close().setColorFill(0.7, 0.95, 1);
        m.flowArrows = m.details.flow.createChild("image").setFile(artDir ~ "energy-flow-arrows.png")
                               .setTranslation(663, 316).setSize(196, 120);
        m.flowPower = panelText(m.details.flow, 754, 504, 29);
		# Half the degree sign's advance in Exo at size 36 keeps the three digits centered.
		m.bearing = panelText(m.details.compass, 754 + 5.45, 297, 36);
		m.cardinals = [];
		foreach (var letter; ["N", "E", "S", "W"]) {
			var marker = m.details.compass.createChild("group");
			if (letter == "N")
				marker.createChild("path").circle(16, 0, 0).setColorFill(0.83, 0.08, 0.11);
			panelText(marker, 0, 0, 24).setText(letter);
			append(m.cardinals, marker);
		}
        m.assistState = panelText(m.details.assist, 754, 340, 36);
		var radarDrawing = m.details.radar.createChild("group");
		canvas.parsesvg(radarDrawing, artDir ~ "parking-radar.svg");
		var assist = followme.parkingAssist;
		m.frontRadarDisplay = RadarBumperDisplay.new(m.details.radar, radarDrawing, assist.front,
		                                             "front", ["left", "center", "right"], 652);
		# Sensor-left at the rear bumper is vehicle-right on the top-down diagram.
		m.rearRadarDisplay = RadarBumperDisplay.new(m.details.radar, radarDrawing, assist.rear,
		                                            "rear", ["right", "center", "left"], 858);

        m.initHistory();
		setlistener("/sim/signals/save", func { m.saveHistory(); });
        m.infoImageIndex = vecindex(menu,"range");
        m.phase = "standby";
        m.displayPage = nil;
        m.phaseTimer = maketimer(1, func m.finishPhase());
        m.phaseTimer.singleShot = 1;
        m.lampTestTimer = maketimer(0.5, func m.updateLamps());
        m.lampTestTimer.singleShot = 1;
        m.updateTimer = maketimer(0.1, func m.update());
        m.update();
        m.updateTimer.start();
		setlistener("/systems/isParkingRadarActive", func { m.update(); }, 0, 0);
        # A pedal press acknowledges only the current intervention's dashboard prompt.
        setlistener(m.information.systems.safety.aebActivated, func(n) {
            m.showAebPrompt = n.getBoolValue() and !followme.brakeController.applyingFeetBrake;
            if (m.phase == "driving") m.update();
        }, 1, 0);
        setlistener(followme.brakeController.pedalPressed, func(n) {
            if (n.getBoolValue() and m.showAebPrompt) {
                m.showAebPrompt = 0;
                if (m.phase == "driving") m.update();
            }
        }, 0, 0);
        return m;
    },
    startupSoundIsEnabled: 0, startupSound: nil, showingWarningMessage: 0,
    keyDown: nil, showAebPrompt: 0,
    enableStartupSound: func(){
        me.startupSoundIsEnabled = 1;
    },
    disableStartupSound: func(){
        me.startupSoundIsEnabled = 0;
    },
    setStartupSound: func(startupSoundPath){
        me.startupSoundPath = io.dirname(startupSoundPath);
        me.startupSound = io.basename(startupSoundPath);
    },

	# The live update and the pre-save signal use the same sampling window.
	sampleActiveTrip: func() {
		if (me.phase == "driving" or me.phase == "selfTest") me.sampleTrip();
	},
	saveHistory: func() {
		me.sampleActiveTrip();
		me.writeHistory();
	},

    cyclePage: func(delta) {
        if (me.displayPage == menu[me.infoImageIndex]) {
            me.infoImageIndex = math.mod(me.infoImageIndex + delta + size(menu), size(menu));
            me.update();
        }
        return me.infoImageIndex;
    },
    nextCenterScreen: func() { return me.cyclePage(1); },
    previousCenterScreen: func() { return me.cyclePage(-1); },
    pageKey: func(down) {
        if (down) {
            if (me.keyDown == nil) {
                me.keyDown = systime();
                me.keyPage = me.displayPage;
            }
        } elsif (me.keyDown != nil) {
            var held = systime() - me.keyDown;
            me.keyDown = nil;
            if (me.displayPage != me.keyPage or me.displayPage != menu[me.infoImageIndex]) return;
            if (held >= 1 and contains(me.counters, me.displayPage)) {
                me.resetCounter(me.displayPage);
                me.update();
            } else me.nextCenterScreen();
        }
    },
    selectPage: func() {
        if (!followme.auxBusPowered.getBoolValue()) return "off";
        if (me.phase == "selfTest") return "selfTest";
        if (me.phase == "driving" and me.showAebPrompt) return "aeb";
        if (me.information.electrical.isRecharging.getBoolValue()) return "charge";
        foreach (var door; me.doors) if (door.getpos() > 0) return "doors";
        if (followme.parkingAssist.isRunning) return "radar";
        return me.phase == "driving" ? menu[me.infoImageIndex] : me.phase;
    },
    showPage: func(page) {
        var driving = me.phase == "driving" and page != "off";
        me.backgroundImage.setVisible(driving);
        me.gaugeGroup.setVisible(driving);
        me.signGroup.setVisible(driving or page == "selfTest");
        if (me.displayPage == page) return;
        me.keyDown = nil;
        me.displayPage = page;
        me.infoImage.setVisible(page != "off");
        if (page != "off") {
            var file = page == "doors" ? "doors/dashboard_Door.png" : "dashboard" ~ art[page] ~ ".png";
            me.infoImage.setFile(artDir ~ file);
        }
        var detail = contains(me.counters, page) ? "consumption" : page;
        foreach (var name; keys(me.details)) me.details[name].setVisible(name == detail);
    },
    update: func() {
        me.sampleActiveTrip();
        var page = me.selectPage();
        me.showPage(page);
        if (me.phase == "driving" and page != "off") {
            me.updateGauges();
            if (!me.lampTestTimer.isRunning) me.updateLamps();
        }
        me.warningText.setVisible(me.phase == "driving" and page != "off" and me.showingWarningMessage
                                  and math.mod(int(systime()*2), 2) == 0);
        me.updatePage(page);
    },
    updatePage: func(page) {
        if (page == "doors") {
            for (var i=0; i<size(me.doorIcons); i+=1) me.doorIcons[i].setVisible(me.doors[i].getpos() > 0);
            me.capLabel.setVisible(followme.charging_cap.getpos() > 0);
        } elsif (page == "charge") {
            var pack = followme.cSource;
            var minutes = math.ceil((pack.electricalCapacity - pack.remaining) / followme.chargerPowerKW / 60);
            me.chargeStatus.setText(sprintf("%s   ·   %d min", pack.getRemainingPercentage(), minutes));
        } elsif (page == "summary") {
			var distanceKm = me.counterDistanceKm("journey");
			var durationSec = me.seconds - me.counters.journey.seconds;
			var averageSpeedKmh = durationSec > 0 ? 3600 * distanceKm / durationSec : 0;
			me.summaryRows[0].setText(sprintf("%.1f km", distanceKm));
			me.summaryRows[1].setText(sprintf("%d:%02d:%02d", int(durationSec / 3600),
			                                  math.mod(int(durationSec / 60), 60), math.mod(int(durationSec), 60)));
			me.summaryRows[2].setText(sprintf("%.1f km/h", averageSpeedKmh));
			me.summaryRows[3].setText(formatConsumption(me.consumption("journey")));
        } elsif (page == "range") {
			var pack = followme.cSource;
			var estimateKm = me.estimatedRangeKm(pack.getRemainingInkWh());
			me.rangeKm.setText(estimateKm == nil ? "--" : sprintf("%.0f", estimateKm));
			me.rangePercent.setText(sprintf("%.0f", pack.getRemainingPercentageFloat()));
        } elsif (contains(me.counters, page)) {
            var avg = me.consumption(page);
			me.consumptionValue.setText(formatConsumption(avg));
            me.consumptionPointer.setVisible(avg != nil);
            me.barFill.setVisible(avg != nil and avg > 0);
            if (avg != nil) {
                var fraction = math.clamp(avg/30, 0, 1);
                me.barFill.setScale(fraction, 1);
                me.consumptionPointer.setTranslation(595 + 318*fraction, 398);
            }
        } elsif (page == "flow") {
            var power = engine.engine_1.activePower_kW;
            me.flowArrows.setVisible(power >= 0.1);
            me.flowPower.setText(sprintf("%.1f kW", power));
        } elsif (page == "compass") {
            var heading = math.mod(me.information.getHeadingDEG()+360, 360);
            me.bearing.setText(sprintf("%03d°", math.mod(int(heading+0.5), 360)));
            for (var i=0; i<4; i+=1) {
                var angle = math.mod(i*90-heading+540, 360)-180;
                me.cardinals[i].setVisible(math.abs(angle) <= 59);
                if (math.abs(angle) <= 59)
                    me.cardinals[i].setTranslation(754+221*math.sin(angle*D2R), 555-221*math.cos(angle*D2R));
            }
        } elsif (page == "assist") {
            var speed = autospeed.active ? sprintf("%.0f km/h", autospeed.targetSpeed*1.852) : "";
            var label = autopilot.road_check_timer.isRunning ? "AUTO" : (autospeed.active ? "CRUISE" : "STANDBY");
            me.assistState.setText(label ~ (speed == "" ? "" : "   " ~ speed));
        } elsif (page == "radar") {
			me.frontRadarDisplay.update();
			me.rearRadarDisplay.update();
        }
    },
    updateGauges: func() {
        #//Speedometer
        var currentSpeedKMH = sprintf("%i", me.information.getSpeedKMH());
        me.speedometer.setText(currentSpeedKMH);
        if(autospeed.active == 1){
            me.speedometer.setColor(0.34, 0.63, 1);
        }else{
            me.speedometer.setColor(1, 1, 1);
        }
        #//Power
        me.power.setText(sprintf("%i", engine.engine_1.activePower_kW));
        #//Battery
        me.batteryRemainingDisplay.setText(me.information.electrical.batteryRemainingPercent.getValue());
        if(me.information.electrical.batteryRemainingPercentFloat.getValue() <= 20.0) me.batteryRemainingDisplay.setColor(1, 0, 0);
        else me.batteryRemainingDisplay.setColor(0.58, 0.894, 1);
        #//Gear
        if(engine.engine_1.direction == 1){
            me.gearDisplay.setText("D");
        }else if(engine.engine_1.direction == -1){
            me.gearDisplay.setText("R");
        }
        #//Mode
        if(engine.engine_1.mode == 1){
            me.driveMode.setText("Performance");
        }else if(engine.engine_1.mode == 0.65){
            me.driveMode.setText("Comfort");
        }else if(engine.engine_1.mode == 0.4){
            me.driveMode.setText("Low Power");
        }

        #//Temperature and Time
        var tempC = me.information.environment.temperature.getValue();
        me.tempDisplay.setText(sprintf("%0.1f", tempC)~" °C");
        var hour = me.information.getTimeHour();
        var minute = me.information.getTimeMinute();
        if(minute < 10) minute = "0"~minute;
        me.timeDisplay.setText(hour~":"~minute);

        me.tripDisplay.setText(sprintf("TRIP 1   %.1f km", me.counterDistanceKm("trip1")));
        me.distanceDisplay.setText(sprintf("TOTAL   %.1f km", me.km));
    },
    # Traction and stability control of the tyre model's FDM; nil with the standard FDM.
    tcEnabled: props.getNode("/fdm/jsbsim/tc/par/enabled"),
    escEnabled: props.getNode("/fdm/jsbsim/esc/par/enabled"),
    tcActive: props.getNode("/fdm/jsbsim/tc/active"),
    escActive: props.getNode("/fdm/jsbsim/esc/active"),
    escLastActive: -1,
    elapsedNode: props.getNode("/sim/time/elapsed-sec", 1),
    # The ESC lamp flashes while traction or stability control works, and for half a second after,
    # so that a short intervention still shows at the 10 Hz update (FMVSS 126 S5.3.8, Audi's K155).
    # ESC OFF stays lit while either is switched off (S5.5).
    updateStabilityLamps: func() {
        if (me.escEnabled == nil) {
            me.escSign.hide();
            me.escOffSign.hide();
            return;
        }
        var now = me.elapsedNode.getValue();
        if (me.tcActive.getBoolValue() or me.escActive.getBoolValue()) me.escLastActive = now;
        me.escSign.setVisible(now - me.escLastActive < 0.5 and math.mod(now, 0.4) < 0.2);
        me.escOffSign.setVisible(!me.tcEnabled.getBoolValue() or !me.escEnabled.getBoolValue());
    },
    updateLamps: func() {
        me.foglightSign.setVisible(followme.frontFogPowered.getBoolValue()
                                   or followme.rearFogPowered.getBoolValue());
        me.updateStabilityLamps();
        var safety = followme.safety;
        me.airbagSign.setVisible(!safety.isOn or safety.frontAirbagProp.getBoolValue()
                                              or safety.sideAirbagProp.getBoolValue());
        me.handBrakeSign.setVisible(followme.brakeController.parkingBrakeNode.getBoolValue());
        me.autoholdSign.setVisible(me.information.systems.isAutoholdWorking.getBoolValue());
        var lightMode = me.information.lighting.headlight.getValue();
        me.positionLightSign.setVisible(lightMode == 1 or lightMode == 2);
        me.headlightSign.setVisible(lightMode == 2);
        me.highbeamSign.setVisible(me.information.lighting.highBeam.getBoolValue());
		# Allow for the small groundspeed fluctuations at a standstill.
		me.readySign.setVisible(engine.engine_1.isRunning() and math.abs(me.information.getSpeedKMH()) <= 0.5);
        me.autopilotSign.setVisible(autopilot.road_check_timer.isRunning);
        me.cruiseSign.setVisible(autospeed.active);
    },
    selfTest: func(){
        # Visibility is cached per Canvas wrapper. Use the same ones as the live display.
        foreach (var sign; [me.airbagSign, me.handBrakeSign, me.autoholdSign,
                            me.positionLightSign, me.headlightSign, me.highbeamSign,
                            me.foglightSign, me.escOffSign, me.escSign, me.readySign,
                            me.autopilotSign, me.cruiseSign]) {
            sign.show();
        }
    },

    startUp: func() {
        me.phaseTimer.stop();
        me.lampTestTimer.stop();
        me.resetIgnitionCounters();
        me.phase = "selfTest";
        me.selfTest();
        me.update();
        me.phaseTimer.restart(1);
    },
    finishPhase: func() {
        if (me.phase == "selfTest") {
            me.phase = "driving";
            # Keep the lamp test visible for half a second over the live gauges.
            me.lampTestTimer.start();
            if (me.startupSound and me.startupSoundIsEnabled)
                followme.playAudio(me.startupSound, 1, me.startupSoundPath);
        } elsif (me.phase == "summary") me.phase = "off";
        me.update();
    },
    shutDown: func() {
        me.phaseTimer.stop();
        me.lampTestTimer.stop();
        me.sampleTrip();
        me.lastSampleTime = nil;
        me.phase = "summary";
        me.showingWarningMessage = 0;
        me.update();
        me.phaseTimer.restart(8);
    },
    showWarningMessage: func(msg) {
        me.warningText.setText(msg);
        me.showingWarningMessage = 1;
    },
    hideWarningMessage: func() { me.showingWarningMessage = 0; },
};

var smartInstruments = SmartInstruments.new("instrumentScreen");
var setStartupSound_dlg = gui.Dialog.new("/sim/gui/dialogs/smartinstruments/setStartupSound_dlg/dialog","Aircraft/followme_e-tron/gui/dialogs/load-startup-sound.xml");
