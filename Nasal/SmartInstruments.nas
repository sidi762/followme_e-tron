var smartInstruments = canvas.new({
  "name": "smartInstruments",   # The name is optional but allow for easier identification
  "size": [1024, 1024], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [1509, 736],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 0       # Enable mipmapping (optional)
});
smartInstruments.addPlacement({"node": "instrumentScreen"});

var group = smartInstruments.createGroup();

canvas.parsesvg(
        group,
        "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard1.svg",
);

#Background
var path = "Aircraft/followme_e-tron/Models/Interior/Instruments/Smart/dashboard1.png";
# create an image child for the texture
var backgroundImage = group.createChild("image")
    .setFile(path)
    .setTranslation(0, 0)
    .setSize(1509, 736);

# Create a text element and set some values(Self test)
var selfTestText = group.createChild("text", "optional-id-for element")
                .setTranslation(530, 140)      # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(50)        # Set fontsize and optionally character aspect ratio
                .setColor(1,0,0)             # Text color
                .setText("SELF TEST NORMAL")
                .show();

selfTestText.hide();


#//speedometer
var speedometer = group.createChild("text", "optional-id-for element")
                .setTranslation(1205, 380)      # The origin is in the top left corner
                .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("--");
speedometer.show();
speedometer.enableUpdate();

#//power
var power = group.createChild("text", "optional-id-for element")
                .setTranslation(295, 380)      # The origin is in the top left corner
                .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("trueno-font/Trueno-wml2.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(148)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("--");
power.show();
power.enableUpdate();

#//Drive Mode
var driveMode = group.createChild("text", "optional-id-for element")
                .setTranslation(780, 628)      # The origin is in the top left corner
                .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(40)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("Performance");
driveMode.show();
driveMode.enableUpdate();

#//Gear
var gearDisplay = group.createChild("text", "optional-id-for element")
                .setTranslation(940, 620)      # The origin is in the top left corner
                .setAlignment("center-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(70)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("D");
gearDisplay.show();
gearDisplay.enableUpdate();

#//Temperature
var tempDisplay = group.createChild("text", "optional-id-for element")
                .setTranslation(420, 220)      # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(30)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("30 °C");
tempDisplay.show();
tempDisplay.enableUpdate();

#//Time
var timeDisplay = group.createChild("text", "optional-id-for element")
                .setTranslation(1055, 215)      # The origin is in the top left corner
                .setAlignment("right-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("ExoRegular-ymMe.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(40)        # Set fontsize and optionally character aspect ratio
                .setColor(1,1,1)             # Text color
                .setText("9:41");
timeDisplay.show();
timeDisplay.enableUpdate();
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

var instrumentUpdate = func(){
    var currentSpeed = props.getNode("/", 1).getValue("sim/multiplay/generic/float[15]");
    var currentSpeedKMH = sprintf("%i", currentSpeed*1.852);
    speedometer.updateText(currentSpeedKMH);
    if(autospeed.active == 1){
        speedometer.setColor(0.34, 0.63, 1);
    }else{
        speedometer.setColor(1, 1, 1);
    }
    power.updateText(sprintf("%i", engine.engine_1.activePower_kW));
    if(engine.engine_1.direction == 1){
        gearDisplay.updateText("D");
    }else if(engine.engine_1.direction == -1){
        gearDisplay.updateText("R");
    }
    if(engine.engine_1.mode == 1){
        driveMode.updateText("Performance");
    }else if(engine.engine_1.mode == 0.65){
        driveMode.updateText("Comfort");
    }else if(engine.engine_1.mode == 0.4){
        driveMode.updateText("Low Power");
    }

    var tempC = props.getNode("/", 1).getValue("environment/temperature-degc");
    tempDisplay.updateText(sprintf("%0.1f", tempC)~" °C");
    var hour = props.getNode("/", 1).getValue("sim/time/real/hour");
    var minute = props.getNode("/", 1).getValue("sim/time/real/minute");
    if(minute < 10) minute = "0"~minute;
    timeDisplay.updateText(hour~":"~minute);
    #runtimeTextAdjust(timeDisplay);
}

var updateTimer = maketimer(0.1, func instrumentUpdate());
updateTimer.start();


var window = canvas.Window.new([756,368],"dialog");
window.setCanvas(smartInstruments);
