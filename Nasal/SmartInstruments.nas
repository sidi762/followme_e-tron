var SmartInstruments = {
    new: func(placement) {
        var m = {
            parents:[SmartInstruments],
            instrumentCanvas: canvas.new({
              "name": "smartInstruments",   # The name is optional but allow for easier identification
              "size": [1024, 1024], # Size of the underlying texture (should be a power of 2, required) [Resolution]
              "view": [1509, 736],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                                    # which will be stretched the size of the texture, required)
              "mipmapping": 0       # Enable mipmapping (optional)
            }),
        };

        m.information = followme.vehicleInformation;
        m.startupSoundIsEnabled = 0;
        m.startupSound = nil;#//The startup sound
        m.startupSoundPath = nil;#//Path to the startup sound
        m.group = m.instrumentCanvas.createGroup();#//Main group
        m.signGroup = m.instrumentCanvas.createGroup();#//sign group
        m.welcomeGroup = m.instrumentCanvas.createGroup();
        m.mapGroup = m.instrumentCanvas.createGroup(); #//map group
        m.instrumentCanvas.addPlacement({"node": placement});
        #Sign svg
        canvas.parsesvg(
                m.signGroup,
                "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard.svg",
        );
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
                                    .setTranslation(530, 140)      # The origin is in the top left corner
                                    .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                                    .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                                    .setFontSize(50)        # Set fontsize and optionally character aspect ratio
                                    .setColor(1,0,0)             # Text color
                                    .setText("WARNING MESSAGE");
        #//speedometer
        m.speedometer = m.group.createChild("text", "optional-id-for element")
                               .setTranslation(1205, 380)      # The origin is in the top left corner
                               .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("--");

        #//power
        m.power = m.group.createChild("text", "optional-id-for element")
                         .setTranslation(295, 380)      # The origin is in the top left corner
                         .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                         .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                         .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                         .setColor(1,1,1)             # Text color
                         .setText("--");
        #//Battery remaining
        m.batteryRemainingDisplay = m.group.createChild("text", "optional-id-for element")
                         .setTranslation(312, 542)      # The origin is in the top left corner
                         .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                         .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                         .setFontSize(30)        # Set fontsize and optionally character aspect ratio
                         .setColor(0.58,0.894,1)             # Text color
                         .setText("--");

        #//Drive Mode
        m.driveMode = m.group.createChild("text", "optional-id-for element")
                             .setTranslation(780, 628)      # The origin is in the top left corner
                             .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                             .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                             .setFontSize(40)        # Set fontsize and optionally character aspect ratio
                             .setColor(1,1,1)             # Text color
                             .setText("Performance");
        #//Gear
        m.gearDisplay = m.group.createChild("text", "optional-id-for element")
                               .setTranslation(940, 620)      # The origin is in the top left corner
                               .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                               .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                               .setFontSize(70)        # Set fontsize and optionally character aspect ratio
                               .setColor(1,1,1)             # Text color
                               .setText("D");
        #//Temperature
        m.tempDisplay = m.group.createChild("text", "optional-id-for element")
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
        me.batteryRemainingDisplay.updateText(me.information.systems.electrical.getMainBatteryRemainingPercentage);
        if(me.information.systems.electrical.getMainBatteryRemainingPercentageFloat <= 20.0) me.batteryRemainingDisplay.setColor(1,0,0);
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

        #//Warning MESSAGE
        if(me.showingWarningMessage){
            if(math.mod(me.loopCount, 10) == 0){
                me.warningText.show();
            }else{
                me.warningText.hide();
            }
        }
    },

    updateTimer:nil,
    init: func(){
        if(me.updateTimer == nil) me.updateTimer = maketimer(0.1, func me.update());
        me.group.hide();
        me.welcomeGroup.hide();
        me.initialized = 1;
    },
    startUp:func(){
        me.welcomeGroup.show();
        var startScreenTimer = maketimer(1, func me.startSequence());
        startScreenTimer.singleShot = 1;
        startScreenTimer.start();
    },
    startSequence: func(){
        me.group.show();
        me.speedometer.enableUpdate();
        me.power.enableUpdate();
        me.batteryRemainingDisplay.enableUpdate();
        me.driveMode.enableUpdate();
        me.gearDisplay.enableUpdate();
        me.tempDisplay.enableUpdate();
        me.timeDisplay.enableUpdate();
        me.warningText.enableUpdate();

        if(me.startupSound and me.startupSoundIsEnabled) followme.playAudio(me.startupSound, 1, me.startupSoundPath);

        var timer2 = maketimer(2, func(){
            me.welcomeGroup.hide();
        });
        timer2.singleShot = 1;
        timer2.start();

        if(!me.initialized) me.init();
        me.updateTimer.start();
    },
    shutDown:func(){
        if(me.updateTimer != nil) me.updateTimer.stop();
        me.group.hide();
        me.welcomeGroup.hide();
    },
    showWarningMessage:func(msg){
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
