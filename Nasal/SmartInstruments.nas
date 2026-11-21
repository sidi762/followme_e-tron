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

var artDir = "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/";
var menu = ["assist", "tyres", "flow", "compass", "range", "total", "sinceStart", "trip1", "trip2", "media", "navigation"];
var art = {
    assist: "1.0_on", tyres: "1.1", flow: "1.3", compass: "1.4", radar: "1.5",
    range: "2.1", total: "2.2", sinceStart: "2.3", trip1: "2.4", trip2: "2.5",
    media: "3", navigation: "4", aeb: "_AEB", charge: "_charge",
    standby: "_start", selfTest: "_self_test", summary: "_summary",
};

var panelText = func(group, x, y, height, align="center-center", font="ExoRegular-ymMe.ttf") {
    return group.createChild("text").setTranslation(x, y).setAlignment(align)
                .setFont(font).setFontSize(height).setColor(1, 1, 1);
};
var panelImage = func(group, file) {
    return group.createChild("image").setFile(artDir ~ file).setSize(1509, 736);
};

var SmartInstruments = {
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
        m.bearing = panelText(m.details.compass, 754, 304, 40);
        m.cardinals = [];
        foreach (var letter; ["N","E","S","W"]) {
            var label = panelText(m.details.compass, 0, 0, 24).setText(letter);
            if (letter == "N") label.setColor(1, 0.35, 0.3);
            append(m.cardinals, label);
        }
        m.assistState = panelText(m.details.assist, 754, 340, 36);
        m.radarState = panelText(m.details.radar, 754, 483, 25);

        m.km = 0;
        m.kWh = 0;
        m.seconds = 0;
        m.counters = {};
        foreach (var name; ["total","sinceStart","trip1","trip2","journey"]) m.resetCounter(name);
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
        setlistener(m.information.systems.safety.aebActivated, func {
            if (m.phase == "driving") m.update();
        });
        return m;
    },
    startupSoundIsEnabled: 0, startupSound: nil, showingWarningMessage: 0,
    lastTime: nil, lastKW: 0, lastSpeed: 0, keyDown: nil,
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

    # All four counters share one integration of ground speed and HV pack power.
    # The journey summary keeps its ignition baseline even if a driver resets a counter.
    resetCounter: func(name) {
        me.counters[name] = {km: me.km, kWh: me.kWh, seconds: me.seconds};
    },
    sampleTrip: func() {
        var now = getprop("/fdm/jsbsim/simulation/sim-time-sec");
        if (now == nil) return;
        if (me.lastTime != nil) {
            var dt = math.max(0, now-me.lastTime);
            me.km += me.lastSpeed * dt / 3600;
            me.kWh += me.lastKW * dt / 3600;
            me.seconds += dt;
        }
        me.lastTime = nil;
        if (engine.engine_1.isRunning()) {
            me.lastTime = now;
            me.lastSpeed = math.abs(me.information.getSpeedKMH());
            me.lastKW = followme.circuit_1.current * followme.cSource.electromotiveForce / 1000;
        }
    },
    consumption: func(name) {
        var c = me.counters[name];
        var km = me.km - c.km;
        return km >= 0.1 ? 100 * (me.kWh - c.kWh) / km : nil;
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
        if (me.phase == "driving" and me.information.systems.safety.aebActivated.getBoolValue()) return "aeb";
        if (me.information.electrical.isRecharging.getBoolValue()) return "charge";
        foreach (var door; me.doors) if (door.getpos() > 0) return "doors";
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
        if (me.phase == "driving" or me.phase == "selfTest") me.sampleTrip();
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
            var c = me.counters.journey;
            var km = me.km-c.km;
            var seconds = me.seconds-c.seconds;
            var avg = me.consumption("journey");
            me.summaryRows[0].setText(sprintf("%.1f km", km));
            me.summaryRows[1].setText(sprintf("%d:%02d:%02d", int(seconds/3600),
                                               math.mod(int(seconds/60), 60), math.mod(int(seconds), 60)));
            me.summaryRows[2].setText(sprintf("%.1f km/h", seconds > 0 ? 3600*km/seconds : 0));
            me.summaryRows[3].setText((avg == nil ? "--" : sprintf("%.1f", avg)) ~ " kWh/100km");
        } elsif (page == "range") {
            # The first acceleration from a standstill is a poor range sample.
            var estimate = "--";
            if (me.km >= 1 and me.kWh > 0)
                estimate = sprintf("%.0f", followme.cSource.getRemainingInkWh() * me.km / me.kWh);
            me.rangeKm.setText(estimate);
            me.rangePercent.setText(sprintf("%.0f", followme.cSource.getRemainingPercentageFloat()));
        } elsif (contains(me.counters, page)) {
            var avg = me.consumption(page);
            me.consumptionValue.setText((avg == nil ? "--" : sprintf("%.1f", avg)) ~ " kWh/100km");
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
            var radar = followme.parkingRadar;
            var label = "OFF";
            if (radar.isRunning) label = radar.warningTimer.isRunning ? "OBSTACLE" : "ON";
            me.radarState.setText(label);
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

        me.tripDisplay.setText(sprintf("TRIP 1   %.1f km", me.km-me.counters.trip1.km));
        me.distanceDisplay.setText(sprintf("TOTAL   %.1f km", me.km));
    },
    updateLamps: func() {
        # These two lamps only light during the ignition test.
        me.foglightSign.hide();
        me.escOffSign.hide();
        var safety = followme.safety;
        me.airbagSign.setVisible(!safety.isOn or safety.frontAirbagProp.getBoolValue()
                                              or safety.sideAirbagProp.getBoolValue());
        me.handBrakeSign.setVisible(followme.brakeController.handBrakeIsOn());
        me.autoholdSign.setVisible(me.information.systems.isAutoholdWorking.getBoolValue());
        var lightMode = me.information.lighting.headlight.getValue();
        me.positionLightSign.setVisible(lightMode == 1 or lightMode == 2);
        me.headlightSign.setVisible(lightMode == 2);
        me.highbeamSign.setVisible(me.information.lighting.highBeam.getBoolValue());
        me.readySign.setVisible(engine.engine_1.isRunning());
        me.autopilotSign.setVisible(autopilot.road_check_timer.isRunning);
        me.cruiseSign.setVisible(autospeed.active);
    },
    selfTest: func(){
        # Visibility is cached per Canvas wrapper. Use the same ones as the live display.
        foreach (var sign; [me.airbagSign, me.handBrakeSign, me.autoholdSign,
                            me.positionLightSign, me.headlightSign, me.highbeamSign,
                            me.foglightSign, me.escOffSign, me.readySign,
                            me.autopilotSign, me.cruiseSign]) {
            sign.show();
        }
    },

    startUp: func() {
        me.phaseTimer.stop();
        me.lampTestTimer.stop();
        me.resetCounter("sinceStart");
        me.resetCounter("journey");
        me.lastTime = nil;
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
        me.lastTime = nil;
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
