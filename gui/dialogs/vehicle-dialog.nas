###############################################################################
# Vehicle Dialog Implementation
# Manages the vehicle configuration and control dialog
###############################################################################

# io.include("gui/dialogs/base/window.nas");
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
        var main_widget = UIWidget.new(me, me._group, "main");
        var y_pos = 0;
        var available_width = 380;

        # Title - create a centered title directly
        main_widget.createCenteredLabel(available_width / 2, y_pos + 10, "Vehicle Options", 18);
        y_pos += 25;

        main_widget.createSeparator(0, y_pos, available_width);
        y_pos += 15;

        # Create sections
        y_pos = me._createVehicleModesSection(main_widget, y_pos, available_width);
        y_pos = me._createSteeringSection(main_widget, y_pos, available_width);
        y_pos = me._createBrakingSection(main_widget, y_pos, available_width);
        y_pos = me._createWelcomeSection(main_widget, y_pos, available_width);
        y_pos = me._createDriftingSection(main_widget, y_pos, available_width);
        y_pos = me._createConfigSection(main_widget, y_pos, available_width);
        y_pos = me._createRescueSection(main_widget, y_pos, available_width);
        y_pos = me._createEngineSection(main_widget, y_pos, available_width);
        y_pos = me._createMiscSection(main_widget, y_pos, available_width);

        me._widgets.main = main_widget;
        main_widget.init();
    },

    _createVehicleModesSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Vehicle Modes:", 16);
        y_pos += 15;

        # Performance/Comfort Mode
        widget.createButton(5, y_pos, 180, 30, "Enable Performance Mode", 
            func setprop("/controls/mode", 1));
        widget.createButton(200, y_pos, 180, 30, "Enable Comfort Mode", 
            func setprop("/controls/mode", 0.65));
        y_pos += 40;

        # Low Power Mode
        widget.createButton(5, y_pos, 180, 30, "Enable Low Power Mode", 
            func setprop("/controls/mode", 0.4));
        y_pos += 38;

        widget.createSeparator(5, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createSteeringSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Realistic Steering (*Experimental):", 16);
        y_pos += 15;

        widget.createButton(5, y_pos, 180, 30, "Enable", 
            func followme.enableAdvancedSteering());
        widget.createButton(200, y_pos, 180, 30, "Disable", 
            func followme.disableAdvancedSteering());
        y_pos += 50;

        # Tips
        widget.createLabel(5, y_pos, "Tips: When this is enabled, it is STRONGLY", 12);
        y_pos += 15;
        widget.createLabel(5, y_pos, "recommended to set the max travel to Normal", 12);
        y_pos += 15;
        widget.createLabel(5, y_pos, "in Configuration dialog (default is Long).", 12);
        y_pos += 15;
        widget.createLabel(5, y_pos, "By enabling Realistic Steering, the drifting sound", 12);
        y_pos += 15;
        widget.createLabel(5, y_pos, "effect will be enabled automatically.", 12);
        y_pos += 15;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createBrakingSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Keyboard braking intensity:", 16);
        y_pos += 10;

        widget.createSlider(0, y_pos, 260, 
            "/systems/BrakeController/keyboardBrakeIntensity", 0.1, 1, 0.8);
        y_pos += 35;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createWelcomeSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Welcome message/Startup Sound:", 16);
        y_pos += 15;

        widget.createButton(5, y_pos, 180, 30, "Set Startup Sound", 
            func smartInstruments.setStartupSound_dlg.open());
        widget.createButton(200, y_pos, 180, 30, "Disable welcome message", 
            func setprop("systems/welcome-message", 0));
        y_pos += 35;

        widget.createButton(5, y_pos, 116, 30, "Enable Chinese", 
            func setprop("systems/welcome-message", 1));
        widget.createButton(133.9, y_pos, 116, 30, "Enable English", 
            func setprop("systems/welcome-message", 2));
        widget.createButton(262.8, y_pos, 116, 30, "Enable Special", 
            func setprop("systems/welcome-message", 3));
        y_pos += 35;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createDriftingSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Drifting Sound Effect:", 16);
        y_pos += 15;

        widget.createButton(5, y_pos, 180, 30, "Enable", 
            func setprop("systems/drifting-sound", 1));
        widget.createButton(200, y_pos, 180, 30, "Disable", 
            func setprop("systems/drifting-sound", 0));
        y_pos += 35;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createConfigSection: func(widget, y_pos, width) {
        widget.createButton((width - 300) / 2, y_pos, 300, 30, "Vehicle Configuration", 
            func followme.configDialog.open());
        y_pos += 35;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createRescueSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Rescue:", 16);
        y_pos += 15;

        widget.createButton(5, y_pos, 180, 30, "Flip Vehicle", func {
            setprop("/orientation/roll-deg", 0);
            setprop("velocities/groundspeed-kt", 0);
        });
        widget.createButton(200, y_pos, 180, 30, "Quick Recharge", 
            func followme.circuit_1.parallelConnection[0].units[0].resetRemainingToFull());
        y_pos += 35;

        widget.createButton(5, y_pos, 180, 30, "Reset/Disable Airbag", 
            func followme.safety.reset());
        widget.createButton(200, y_pos, 180, 30, "Reset Here", 
            func followme.resetOnPosition());
        y_pos += 40;

        widget.createLabel(5, y_pos, "Resetting Airbag stops the entire safety system!", 12);
        y_pos += 10;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createEngineSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Engine Controls:", 16);
        y_pos += 15;

        widget.createButton(5, y_pos, 180, 30, "Start Engine", 
            func engine.startEngine(engine.engine_1));
        widget.createButton(200, y_pos, 180, 30, "Stop Engine", 
            func engine.stopEngine(engine.engine_1));
        y_pos += 35;

        widget.createSeparator(0, y_pos, width);
        y_pos += 15;

        return y_pos;
    },

    _createMiscSection: func(widget, y_pos, width) {
        widget.createLabel(5, y_pos, "Miscellaneous:", 16);
        y_pos += 15;

        widget.createCheckbox(5, y_pos, "Enable ALS procedural lights", 
            "/systems/enable_als_lights");
        y_pos += 28;

        widget.createLabel(5, y_pos, "(for older FG versions without Compositor support)", 12);
        y_pos += 20;

        return y_pos;
    }
};

# Create global dialog instance
var vehicleDialog = VehicleDialogClass.new();
