###############################################################################
# Vehicle Dialog Implementation
# Manages the vehicle configuration and control dialog
###############################################################################

io.include("gui/dialogs/base/window.nas");
io.include("gui/dialogs/base/widget.nas");

var VehicleDialogClass = {
    new: func() {
        var m = { 
            parents: [VehicleDialogClass],
            _name: "Vehicle Options",
            _title: "Vehicle Options",
            _listeners: [],
            _window: nil,
            _canvas: nil,
            _widgets: {},
            _sections: {}
        };
        return m;
    },

    close: func() {
        print("VehicleDialog: Closing window");
        if (me._window != nil) {
            me._window.del();
            me._window = nil;
        }
    },

    removeListeners: func() {
        foreach(var l; me._listeners) {
            removelistener(l);
        }
        me._listeners = [];
    },

    _onClose: func() {
        print("VehicleDialog: Closing window");
        me.removeListeners();
        foreach(var widget; keys(me._widgets)) {
            if (me._widgets[widget] != nil) {
                me._widgets[widget].deinit();
                me._widgets[widget] = nil;
            }
        }
        me._window = nil;
    },

    open: func() {        
        me._window = canvas.Window.new([400, 825], "dialog");
        me._window.setTitle(me._title);
        me._window.setPosition(100, 100);
        
        # Set up listener for window closure
        me._window.addEventListener("del", func vehicleDialog._onClose());
        
        me._canvas = me._window.createCanvas();
        me._canvas.set("background", "#2a2a2a"); # Darker background for better contrast
        
        me._group = me._canvas.createGroup();
        me._group.setTranslation(10, 10);
        
        me._createUI();
    },

    _createUI: func() {
        var mainWidget = UIWidget.new(me, me._group, "main");
        var yPos = 0;
        var availableWidth = 380;

        # Title - create a centered title directly
        mainWidget.createCenteredLabel(availableWidth / 2, yPos + 10, "Vehicle Options", 18);
        yPos += 25;

        mainWidget.createSeparator(0, yPos, availableWidth);
        yPos += 15;

        # Create sections
        yPos = me._createVehicleModesSection(mainWidget, yPos, availableWidth);
        yPos = me._createSteeringSection(mainWidget, yPos, availableWidth);
        yPos = me._createBrakingSection(mainWidget, yPos, availableWidth);
        yPos = me._createWelcomeSection(mainWidget, yPos, availableWidth);
        yPos = me._createDriftingSection(mainWidget, yPos, availableWidth);
        yPos = me._createConfigSection(mainWidget, yPos, availableWidth);
        yPos = me._createRescueSection(mainWidget, yPos, availableWidth);
        yPos = me._createEngineSection(mainWidget, yPos, availableWidth);
        yPos = me._createMiscSection(mainWidget, yPos, availableWidth);

        me._widgets.main = mainWidget;
        mainWidget.init();
    },

    _createVehicleModesSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Vehicle Modes:", 16);
        yPos += 15;

        # Performance/Comfort Mode
        widget.createButton(5, yPos, 180, 30, "Enable Performance Mode", 
            func setprop("/controls/mode", 1));
        widget.createButton(200, yPos, 180, 30, "Enable Comfort Mode", 
            func setprop("/controls/mode", 0.65));
        yPos += 40;

        # Low Power Mode
        widget.createButton(5, yPos, 180, 30, "Enable Low Power Mode", 
            func setprop("/controls/mode", 0.4));
        yPos += 38;

        widget.createSeparator(5, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createSteeringSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Realistic Steering (*Experimental):", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Enable", 
            func followme.enableAdvancedSteering());
        widget.createButton(200, yPos, 180, 30, "Disable", 
            func followme.disableAdvancedSteering());
        yPos += 50;

        # Tips
        widget.createLabel(5, yPos, "Tips: When this is enabled, it is STRONGLY", 12);
        yPos += 15;
        widget.createLabel(5, yPos, "recommended to set the max travel to Normal", 12);
        yPos += 15;
        widget.createLabel(5, yPos, "in Configuration dialog (default is Long).", 12);
        yPos += 15;
        widget.createLabel(5, yPos, "By enabling Realistic Steering, the drifting sound", 12);
        yPos += 15;
        widget.createLabel(5, yPos, "effect will be enabled automatically.", 12);
        yPos += 15;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createBrakingSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Keyboard braking intensity:", 16);
        yPos += 10;

        widget.createSlider(0, yPos, 260, 
            "/systems/BrakeController/keyboardBrakeIntensity", 0.1, 1, 0.8);
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createWelcomeSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Welcome message/Startup Sound:", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Set Startup Sound", 
            func smartInstruments.setStartupSound_dlg.open());
        widget.createButton(200, yPos, 180, 30, "Disable welcome message", 
            func setprop("systems/welcome-message", 0));
        yPos += 35;

        widget.createButton(5, yPos, 116, 30, "Enable Chinese", 
            func setprop("systems/welcome-message", 1));
        widget.createButton(133.9, yPos, 116, 30, "Enable English", 
            func setprop("systems/welcome-message", 2));
        widget.createButton(262.8, yPos, 116, 30, "Enable Special", 
            func setprop("systems/welcome-message", 3));
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createDriftingSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Drifting Sound Effect:", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Enable", 
            func setprop("systems/drifting-sound", 1));
        widget.createButton(200, yPos, 180, 30, "Disable", 
            func setprop("systems/drifting-sound", 0));
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createConfigSection: func(widget, yPos, width) {
        widget.createButton((width - 300) / 2, yPos, 300, 30, "Vehicle Configuration", 
            func followme.configDialog.open());
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createRescueSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Rescue:", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Flip Vehicle", func {
            setprop("/orientation/roll-deg", 0);
            setprop("velocities/groundspeed-kt", 0);
        });
        widget.createButton(200, yPos, 180, 30, "Quick Recharge", 
            func followme.circuit_1.parallelConnection[0].units[0].resetRemainingToFull());
        yPos += 35;

        widget.createButton(5, yPos, 180, 30, "Reset/Disable Airbag", 
            func followme.safety.reset());
        widget.createButton(200, yPos, 180, 30, "Reset Here", 
            func followme.resetOnPosition());
        yPos += 40;

        widget.createLabel(5, yPos, "Resetting Airbag stops the entire safety system!", 12);
        yPos += 10;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createEngineSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Engine Controls:", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Start Engine", 
            func engine.startEngine(engine.engine_1));
        widget.createButton(200, yPos, 180, 30, "Stop Engine", 
            func engine.stopEngine(engine.engine_1));
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createMiscSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Miscellaneous:", 16);
        yPos += 15;

        widget.createCheckbox(5, yPos, "Enable ALS procedural lights", 
            "/systems/enable_als_lights");
        yPos += 28;

        widget.createLabel(5, yPos, "(for older FG versions without Compositor support)", 12);
        yPos += 20;

        return yPos;
    }
};

# Create global dialog instance
var vehicleDialog = VehicleDialogClass.new();
