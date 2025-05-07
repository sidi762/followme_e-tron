###############################################################################
# Configuration Dialog Implementation
# Manages the vehicle configuration settings dialog
###############################################################################

io.include("gui/dialogs/base/widget.nas");

var ConfigDialogClass = {
    new: func() {
        var m = { 
            parents: [ConfigDialogClass],
            _name: "Vehicle Config",
            _title: "Vehicle Config",
            _listeners: [],
            _window: nil,
            _canvas: nil,
            _widgets: {},
            _sections: {}
        };
        return m;
    },

    close: func() {
        print("ConfigDialog: Closing window");
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
        
        # Remove the plate listener if it exists
        if (me._plateListener != nil) {
            removelistener(me._plateListener);
            me._plateListener = nil;
        }
    },

    _onClose: func() {
        print("ConfigDialog: Closing window");
        me.removeListeners();
        foreach(var widget; keys(me._widgets)) {
            if (me._widgets[widget] != nil) {
                me._widgets[widget].deinit();
                me._widgets[widget] = nil;
            }
        }
        me._window = nil;
        
        # Play repair sound on close as in the XML version
        followme.playAudio("repair.wav");
    },

    open: func() {        
        me._window = canvas.Window.new([400, 800], "dialog");
        me._window.setTitle(me._title);
        me._window.setPosition(100, 100);
        
        # Set up listener for window closure
        me._window.addEventListener("del", func configDialog._onClose());
        
        me._canvas = me._window.createCanvas();
        me._canvas.set("background", "#2a2a2a"); # Darker background for better contrast
        
        me._group = me._canvas.createGroup();
        me._group.setTranslation(10, 10);
        
        # Initialize the plate selector
        followme.plateSelector.updateList();
        
        # Set up plate name listener
        var nameNode = props.getNode("systems/plate/name", 1);
        var fileNode = props.getNode("systems/plate/file", 1);
        var rearNameNode = props.getNode("systems/rear_plate/name", 1);
        var rearFileNode = props.getNode("systems/rear_plate/file", 1);
        
        me._plateListener = setlistener(nameNode, func() {
            if (nameNode.getValue() != "NONE") {
                fileNode.setValue("texture/" ~ nameNode.getValue() ~ ".png");
                rearFileNode.setValue("plate/texture/" ~ nameNode.getValue() ~ ".png");
            } else {
                fileNode.setValue(nameNode.getValue());
                rearFileNode.setValue("plate/texture/" ~ "e-tron.png");
            }
        });
        
        me._createUI();
    },

    _createUI: func() {
        var mainWidget = UIWidget.new(me, me._group, "main");
        var yPos = 0;
        var availableWidth = 380;

        # Title - create a centered title directly
        mainWidget.createCenteredLabel(availableWidth / 2, yPos + 10, "Vehicle Config", 18);
        yPos += 25;

        mainWidget.createSeparator(0, yPos, availableWidth);
        yPos += 15;

        # Create sections
        yPos = me._createConfigurationSection(mainWidget, yPos, availableWidth);
        yPos = me._createSteeringSection(mainWidget, yPos, availableWidth);
        yPos = me._createInstrumentsSection(mainWidget, yPos, availableWidth);
        yPos = me._createSafetySection(mainWidget, yPos, availableWidth);
        yPos = me._createTireSection(mainWidget, yPos, availableWidth);
        yPos = me._createPlateSection(mainWidget, yPos, availableWidth);
        yPos = me._createLiverySection(mainWidget, yPos, availableWidth);
        yPos = me._createMiscSection(mainWidget, yPos, availableWidth);

        me._widgets.main = mainWidget;
        mainWidget.init();
    },
    
    # Helper function to find index of an item in an array
    _findIndex: func(arr, item) {
        for (var i = 0; i < size(arr); i += 1) {
            if (arr[i] == item) {
                return i;
            }
        }
        return -1; # Not found
    },

    _createConfigurationSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Configuration", 16);
        yPos += 20;
        
        widget.createLabel(5, yPos, "Interior Style:", 16);
        yPos += 15;
        
        # Interior style dropdown - using dropdown widget
        var interiorStyles = [
            "404Design (Default)", "404Design 2.0", "404Design 2022", 
            "404Design 2023", "Luxury", "Luxury 2.0", "Race", 
            "Sport (Legacy)", "Followme Original"
        ];
        
        # Find current index to set as default
        var currentStyle = getprop("/systems/interior/type") or interiorStyles[0];
        var defaultIdx = 0;
        for (var i = 0; i < size(interiorStyles); i += 1) {
            if (interiorStyles[i] == currentStyle) {
                defaultIdx = i;
                break;
            }
        }
        
        widget.createDropdown(5, yPos, 350, interiorStyles, "/systems/interior/type", defaultIdx);
        yPos += 42;
        
        return yPos;
    },

    _createSteeringSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Steering Wheel Travel Settings:", 16);
        yPos += 20;

        widget.createButton(5, yPos, 120, 30, "Normal", 
            func followme.setSteeringTravelToNormal());
        widget.createButton(135, yPos, 120, 30, "Long", 
            func followme.setSteeringTravelToMax());
        yPos += 35;

        widget.createButton(5, yPos, 120, 30, "1:1", 
            func followme.setSteeringTravelToMin());
        yPos += 40;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createInstrumentsSection: func(widget, yPos, width) {
        # Speedometer type
        widget.createLabel(5, yPos, "Speedometer type:", 16);
        yPos += 15;
        
        var speedTypes = ["None", "Type_A", "Type_M", "Type_B", "Type_BT", "Concept", "Original"];
        
        # Find current index
        var currentSpeed = getprop("/systems/speedometer/type") or speedTypes[0];
        var speedIdx = 0;
        for (var i = 0; i < size(speedTypes); i += 1) {
            if (speedTypes[i] == currentSpeed) {
                speedIdx = i;
                break;
            }
        }
        
        widget.createDropdown(5, yPos, 250, speedTypes, "/systems/speedometer/type", speedIdx);
        yPos += 43;
        
        # Battery gauge type
        widget.createLabel(5, yPos, "Battery gauge type:", 16);
        yPos += 15;
        
        var batteryTypes = ["None", "Type_A", "Type_M", "Type_BT", "Concept", "Original"];
        
        # Find current index
        var currentBattery = getprop("/systems/battery-gauge/type") or batteryTypes[0];
        var batteryIdx = 0;
        for (var i = 0; i < size(batteryTypes); i += 1) {
            if (batteryTypes[i] == currentBattery) {
                batteryIdx = i;
                break;
            }
        }
        
        widget.createDropdown(5, yPos, 250, batteryTypes, "/systems/battery-gauge/type", batteryIdx);
        yPos += 35;
        
        return yPos;
    },

    _createSafetySection: func(widget, yPos, width) {
        # Safety buttons
        widget.createButton(5, yPos, 180, 30, "Toggle Parking Radar", 
            func followme.parkingRadar.toggle());
        widget.createButton(200, yPos, 180, 30, "(Re)Initialize Safety", 
            func followme.safety.init());
        yPos += 35;

        widget.createButton(5, yPos, 180, 30, "Disable Safety", 
            func followme.safety.stop());
        widget.createButton(200, yPos, 180, 30, "Toggle AEB", 
            func followme.safety.toggleAEB());
        yPos += 40;
        
        widget.createLabel(5, yPos, "To repair Airbag, reinitialize safety system", 12);
        yPos += 10;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createTireSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Magic Bush Tyre:", 16);
        yPos += 15;

        widget.createButton(5, yPos, 180, 30, "Enable", 
            func followme.reduceRollingFriction());
        widget.createButton(200, yPos, 180, 30, "Disable", 
            func followme.resumeRollingFriction());
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createPlateSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Plate:", 16);
        yPos += 15;
        
        # Get the available plates from the selector's new standard path
        var availablePlates = [];
        # The instance in plate.nas is named "Plate-Selector"
        var platesNode = props.getNode("/TextureSelector/Plate-Selector/items"); 
        if (platesNode != nil) {
            foreach(var child; platesNode.getChildren()) {
                append(availablePlates, child.getName());
            }
        }
        
        if (size(availablePlates) == 0) {
            # If no plates are available, add NONE as default
            append(availablePlates, "NONE");
        }

        # Find current plate index
        var currentPlate = getprop("/systems/plate/name") or "NONE";
        var plateIdx = 0;
        for (var i = 0; i < size(availablePlates); i += 1) {
            if (availablePlates[i] == currentPlate) {
                plateIdx = i;
                break;
            }
        }
        
        widget.createDropdown(5, yPos, 350, availablePlates, "/systems/plate/name", plateIdx);
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 15;

        return yPos;
    },

    _createLiverySection: func(widget, yPos, width) {
        widget.createButton(5, yPos, 180, 30, "Select Livery", 
            func liveries.liverySelector.dialog.open());
        widget.createButton(200, yPos, 180, 30, "Select Message", 
            func liveries.displaySelector.dialog.open());
        yPos += 35;

        widget.createSeparator(0, yPos, width);
        yPos += 20;

        return yPos;
    },

    _createMiscSection: func(widget, yPos, width) {
        widget.createLabel(5, yPos, "Miscellaneous:", 16);
        yPos += 25;

        widget.createCheckbox(5, yPos, "Enable Co-driver Model", 
            "/systems/codriver-enable");
        yPos += 30;
        
        widget.createCheckbox(5, yPos, "Enable Smart Screen", 
            "/systems/screen-enable");
        yPos += 30;
        
        widget.createCheckbox(5, yPos, "Enable Switches", 
            "sim/multiplay/generic/int[15]");
        yPos += 30;
        
        widget.createCheckbox(5, yPos, "Enable Decorations", 
            "systems/decorations-enable");
        yPos += 30;

        return yPos;
    }
};

# Create global dialog instance
var configDialog = ConfigDialogClass.new();
