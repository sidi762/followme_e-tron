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

var SmartInstruments = {
    new: func(placement) {
        var m = {
            parents:[SmartInstruments],
            instrumentCanvas: canvas.new({
              "name": "smartInstruments",   # The name is optional but allow for easier identification
              "size": [8192, 4096], # Size of the underlying texture (should be a power of 2, required) [Resolution]
              "view": [1509, 736],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                                    # which will be stretched the size of the texture, required)
              "mipmapping": 0       # Enable mipmapping (optional)
            }),
        };

        m.information = followme.vInfo;
        m.startupSoundIsEnabled = 0;
        m.startupSound = nil;#//The startup sound
        m.startupSoundPath = nil;#//Path to the startup sound
        m.group = m.instrumentCanvas.createGroup();#//Main group
        m.signGroup = m.instrumentCanvas.createGroup();#//sign group
        m.welcomeGroup = m.instrumentCanvas.createGroup();
        m.gaugeGroup = m.instrumentCanvas.createGroup();#//gauge group
        m.iconGroup = m.instrumentCanvas.createGroup(); #//group for icons
        m.mapGroup = m.instrumentCanvas.createGroup(); #//map group
        m.instrumentCanvas.addPlacement({"node": placement});
        #Sign svg
        canvas.parsesvg(
                m.signGroup,
                "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard.svg",
        );
        m.airbagSign = m.signGroup.getElementById("airbag_sign");
        m.handBrakeSign = m.signGroup.getElementById("handbrake_sign");
        m.autoholdSign = m.signGroup.getElementById("autohold_sign");
        m.headlightSign = m.signGroup.getElementById("headlight_sign");
        m.positionLightSign = m.signGroup.getElementById("positionlight_sign");
        m.highbeamSign = m.signGroup.getElementById("highbeam_sign");
        m.foglightSign = m.signGroup.getElementById("foglight_sign");
        m.foglightSign.hide(); #// Not implemented yet

        m.signGroup.hide();
        #Background
        m.backgroundPath = "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard0.png";
        # create an image child for the texture
        m.backgroundImage = m.group.createChild("image")
                                   .setFile(m.backgroundPath)
                                   .setTranslation(0, 0)
                                   .setSize(1509, 736);
        #center info
        m.infoImagePath = ["Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard1.png",
                           "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard2.png",
                           "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard3.png",
                           "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard4.png"];
        m.infoImageIndex = 0;
        m.infoImage = m.group.createChild("image")
                             .setFile(m.infoImagePath[m.infoImageIndex])
                             .setTranslation(0, 0)
                             .setSize(1509, 736);
        m.chargingImage = m.group.createChild("image")
                        .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard_charge.png")
                        .setTranslation(0, 0)
                        .setSize(1509, 736)
                        .hide();
        m.doorsNotShutImage = m.group.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorFLIcon = m.iconGroup.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door_FL.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorFRIcon = m.iconGroup.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door_FR.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorRLIcon = m.iconGroup.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door_RL.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorRRIcon = m.iconGroup.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door_RR.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorRCIcon = m.iconGroup.createChild("image")
                             .setFile("Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/doors/dashboard_Door_RechargeCap.png")
                             .setTranslation(0, 0)
                             .setSize(1509, 736)
                             .hide();
        m.doorIcons = [m.doorFLIcon, m.doorFRIcon, m.doorRLIcon, m.doorRRIcon, m.doorRCIcon];
        # Create a text element and set some values(Self test)
        m.selfTestText = m.welcomeGroup.createChild("text", "optional-id-for element")
                               .setTranslation(530, 140)      # The origin is in the top left corner
                               .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(50)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,0,0)             # Text color
                               .setText("SELF TEST NORMAL")
                               .show();
        m.warningText = m.group.createChild("text", "optional-id-for element")
                                    .setTranslation(780, 140)      # The origin is in the top left corner
                                    .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                                    .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                                    .setFontSize(50)        # Set fontsize and optionally character aspect ratio
                                    .setColor(1,0,0)             # Text color
                                    .setText("WARNING MESSAGE")
                                    .hide();
        #//speedometer
        m.speedometer = m.gaugeGroup.createChild("text", "optional-id-for element")
                               .setTranslation(1205, 380)      # The origin is in the top left corner
                               .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("--");

        #//power
        m.power = m.gaugeGroup.createChild("text", "optional-id-for element")
                         .setTranslation(295, 380)      # The origin is in the top left corner
                         .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                         .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                         .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                         .setColor(1,1,1)             # Text color
                         .setText("--");
        #//Battery remaining
        m.batteryRemainingDisplay = m.gaugeGroup.createChild("text", "optional-id-for element")
                         .setTranslation(312, 542)      # The origin is in the top left corner
                         .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                         .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                         .setFontSize(30)        # Set fontsize and optionally character aspect ratio
                         .setColor(0.58,0.894,1)             # Text color
                         .setText("--");

        #//Drive Mode
        m.driveMode = m.gaugeGroup.createChild("text", "optional-id-for element")
                             .setTranslation(780, 628)      # The origin is in the top left corner
                             .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                             .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                             .setFontSize(40)        # Set fontsize and optionally character aspect ratio
                             .setColor(1,1,1)             # Text color
                             .setText("Performance");
        #//Gear
        m.gearDisplay = m.gaugeGroup.createChild("text", "optional-id-for element")
                               .setTranslation(940, 620)      # The origin is in the top left corner
                               .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(70)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("D");
        #//Temperature
        m.tempDisplay = m.gaugeGroup.createChild("text", "optional-id-for element")
                               .setTranslation(420, 220)      # The origin is in the top left corner
                               .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(30)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("30 °C");
        #//Time
        m.timeDisplay = m.group.createChild("text", "optional-id-for element")
                               .setTranslation(1055, 215)      # The origin is in the top left corner
                               .setAlignment("right-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(40)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("9:41");

        #//Map
        #//Map Structure is a mess, removed

        m.init();
        return m;
    },
    initialized: 0,
    loopCount:0,
    showingWarningMessage: 0,
    isCenterScreenInfoShown: 1,
    isDoorsNotShut: 0,
    doorsNotShut: [0,0,0,0,0],

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
    nextCenterScreen: func(){
        if(me.infoImageIndex < 3) me.infoImageIndex += 1;
        else if(me.infoImageIndex >= 3) me.infoImageIndex = 0;
        me.infoImage.setFile(me.infoImagePath[me.infoImageIndex]);
        return me.infoImageIndex;
    },
    previousCenterScreen: func(){
        if(me.infoImageIndex > 0) me.infoImageIndex -= 1;
        else if(me.infoImageIndex == 0) me.infoImageIndex = 3;
        me.infoImage.setFile(me.infoImagePath[me.infoImageIndex]);
        return me.infoImageIndex;
    },
    update: func(){
        #//Speedometer
        me.loopCount += 1;
        var currentSpeedKMH = sprintf("%i", me.information.getSpeedKMH());
        me.speedometer.updateText(currentSpeedKMH);
        if(autospeed.active == 1){
            me.speedometer.setColor(0.34, 0.63, 1);
        }else{
            me.speedometer.setColor(1, 1, 1);
        }
        #//Power
        me.power.updateText(sprintf("%i", engine.engine_1.activePower_kW));
        #//Battery
        me.batteryRemainingDisplay.updateText(me.information.electrical.batteryRemainingPercent.getValue());
        if(me.information.electrical.batteryRemainingPercentFloat.getValue() <= 20.0) me.batteryRemainingDisplay.setColor(1,0,0);
        else me.batteryRemainingDisplay.setColor(0.58,0.894,1);
        #//runtimeTextAdjust(me.batteryRemainingDisplay);
        #//Gear
        if(engine.engine_1.direction == 1){
            me.gearDisplay.updateText("D");
        }else if(engine.engine_1.direction == -1){
            me.gearDisplay.updateText("R");
        }
        #//Mode
        if(engine.engine_1.mode == 1){
            me.driveMode.updateText("Performance");
        }else if(engine.engine_1.mode == 0.65){
            me.driveMode.updateText("Comfort");
        }else if(engine.engine_1.mode == 0.4){
            me.driveMode.updateText("Low Power");
        }

        #//Temperature and Time
        var tempC = me.information.environment.temperature.getValue();
        me.tempDisplay.updateText(sprintf("%0.1f", tempC)~" °C");
        var hour = me.information.getTimeHour();
        var minute = me.information.getTimeMinute();
        if(minute < 10) minute = "0"~minute;
        me.timeDisplay.updateText(hour~":"~minute);

        #//Signs
        if(!followme.safety.isOn){
            settimer(func me.airbagSign.show(), 1);
        }else{
            settimer(func me.airbagSign.hide(), 1);
        }

        if(followme.brakeController.handBrakeIsOn()){
            me.handBrakeSign.show();
        }else{
            me.handBrakeSign.hide();
        }

        if(me.information.systems.isAutoholdWorking.getValue()){
            me.autoholdSign.show();
        }else{
            me.autoholdSign.hide();
        }

        if(me.information.lighting.headlight.getValue() == 1){
            me.positionLightSign.show();
        }else if(me.information.lighting.headlight.getValue() == 2){
            me.positionLightSign.show();
            me.headlightSign.show();
        }else if(me.information.lighting.headlight.getValue() == 0){
            me.positionLightSign.hide();
            me.headlightSign.hide();
        }

        if(me.information.lighting.highBeam.getValue()){
            me.highbeamSign.show();
        }else{
            me.highbeamSign.hide();
        }

        #//Check for doors
        doors = [followme.frontleft_door, followme.frontright_door, followme.rearleft_door, followme.rearright_door, followme.charging_cap];
        me.isDoorsNotShut = 0;
        for(var i = 0; i <= 4; i += 1){
            if(doors[i].getpos()){
                me.isDoorsNotShut = 1;
                me.doorsNotShut[i] = 1;
            }else{
                me.doorIcons[i].hide();
                me.doorsNotShut[i] = 0;
            }
        }
        if(me.isDoorsNotShut){
            me.infoImage.hide();
            me.isCenterScreenInfoShown = 0;
            me.doorsNotShutImage.show();
            for(var i = 0; i <= 4; i += 1){
                if(me.doorsNotShut[i]) me.doorIcons[i].show();
            }
        }else{
            me.doorsNotShutImage.hide();
            if(!me.isCenterScreenInfoShown) me.infoImage.show();
        }


        #//Charging page
        #//Needs refactoring
        # if(me.information.electrical.isRecharging.getValue()){
        #     me.infoImage.hide();
        #     me.doorsNotShutImage.hide();
        #     me.isCenterScreenInfoShown = 0;
        #     me.chargingImage.show();
        # }else{
        #     me.chargingImage.hide();
        #     if(!me.isCenterScreenInfoShown) me.infoImage.show();
        # }

        #//Warning MESSAGE
        if(me.showingWarningMessage){
            if(math.mod(me.loopCount, 10) < 5){
                me.warningText.show();
            }else{
                me.warningText.hide();
            }
        }else{
            me.warningText.hide();
        }
    },

    updateTimer:nil,
    init: func(){
        if(me.updateTimer == nil) me.updateTimer = maketimer(0.1, func me.update());
        me.group.hide();
        me.gaugeGroup.hide();
        me.infoImage.hide();
        me.welcomeGroup.hide();
        me.initialized = 1;
    },
    selfTest: func(){
        me.airbagSign.show();
        me.handBrakeSign.show();
        me.autoholdSign.show();
        me.headlightSign.show();
        me.positionLightSign.show();
        me.highbeamSign.show();
    },
    startUp:func(){
        # if(!me.showingWarningMessage) me.welcomeGroup.show();
        me.selfTest();
        me.group.show();
        me.signGroup.show();
        var startScreenTimer = maketimer(1, func me.startSequence());
        startScreenTimer.singleShot = 1;
        startScreenTimer.start();
    },
    startSequence: func(){
        me.group.show();
        me.iconGroup.show();
        me.gaugeGroup.show();
        me.infoImage.show();
        me.speedometer.enableUpdate();
        me.power.enableUpdate();
        me.batteryRemainingDisplay.enableUpdate();
        me.driveMode.enableUpdate();
        me.gearDisplay.enableUpdate();
        me.tempDisplay.enableUpdate();
        me.timeDisplay.enableUpdate();

        if(me.startupSound and me.startupSoundIsEnabled) followme.playAudio(me.startupSound, 1, me.startupSoundPath);

        # var selfTestTimer = maketimer(2, func(){
        #     me.welcomeGroup.hide();
        # });
        # selfTestTimer.singleShot = 1;
        # selfTestTimer.start();

        if(!me.initialized) me.init();
        settimer(func me.updateTimer.start(), 0.5);
    },
    shutDown:func(){
        if(me.updateTimer != nil) me.updateTimer.stop();
        me.group.hide();
        me.welcomeGroup.hide();
        me.iconGroup.hide();
        me.signGroup.hide();
        me.infoImage.hide();
        me.gaugeGroup.hide();
    },
    showWarningMessage:func(msg){
        me.warningText.enableUpdate();
        me.warningText.updateText(msg);
        me.showingWarningMessage = 1;
    },
    hideWarningMessage:func(){
        me.showingWarningMessage = 0;
    }

};

var smartInstruments = SmartInstruments.new("instrumentScreen");



#props.getNode("/dev/smart/size", 1).setValue(30);
#props.getNode("/dev/smart/x", 1).setValue(520);
#props.getNode("/dev/smart/y", 1).setValue(220);

var runtimeTextAdjust = func(text){
    var x = props.getNode("/dev/smart/x", 1).getValue();
    var y = props.getNode("/dev/smart/y", 1).getValue();
    text.setTranslation(x, y);
    var siz = props.getNode("/dev/smart/size", 1).getValue();
    text.setFontSize(siz);
}


var setStartupSound_dlg = gui.Dialog.new("/sim/gui/dialogs/smartinstruments/setStartupSound_dlg/dialog","Aircraft/followme_e-tron/gui/dialogs/load-startup-sound.xml");



#var window = canvas.Window.new([756,368],"dialog");
#window.setCanvas(smartInstruments.instrumentCanvas);
