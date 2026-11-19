#Font Mapper
var font_mapper = func(family, weight) {
    return "Orbitron/Orbitron-Bold.ttf";
};

var clamp = func(value, min=0.0, max=0.0) {
    if(value < min) {value = min;}
    if(value > max) {value = max;}
    return value;
}

var SvgWidget = {
    new: func(dialog, canvasGroup, name) {
        var m = {parents:[SvgWidget]};
        m._class = "SvgWidget";
        m._dialog = dialog;
        m._listeners = [];
        m._name = name;
        m._group = canvasGroup;
        return m;
    },

    removeListeners: func() {
        foreach(l; me._listeners) {
            removelistener(l);
        }
        me._listeners = [];
    },

    setListeners: func(instance) {},

    init: func(instance=me) {},

    deinit: func() {
        me.removeListeners();
    }
};

var BatteryWidget = {
    new: func(dialog, canvasGroup, name) {
        var m = {parents:[BatteryWidget, SvgWidget.new(dialog, canvasGroup, name)]};
        m._class = "BatteryWidget";
        m._name = name;
        
        m._nLevelPct = props.getNode("/systems/electrical/e-tron/battery-remaining-percent");
        m._fraction = followme.circuit_1.parallelConnection[0].units[0].getRemainingPercentageFloat();
        m._capacity = 80; #80 kWh (per pack)

        m._cFrame = m._group.getElementById(m._name~"_Frame");
        m._cFrameV = m._group.getElementById(m._name~"_Frame_Vis");
        m._cLevel = m._group.getElementById(m._name~"_Charge_Level");
        m._cDataLevel = m._group.getElementById(m._name~"_Data_Level");
        m._cDataAbs = m._group.getElementById(m._name~"_Data_Abs");

        m._cDataLevel.setText(sprintf("%3d", m._fraction)~" %");
        m._cDataAbs.setText(sprintf("%3.1f", m._fraction*m._capacity*0.01)~" kWh");

        m._left = m._cFrame.get("coord[0]");
        m._right = m._cFrame.get("coord[2]");
        m._width = m._right - m._left;
        return m;
    },

    setListeners: func(instance) {
        append(me._listeners, setlistener(me._nLevelPct, func() {me._onChargeLevelChange();}, 1, 0));

        me._cFrameV.addEventListener("drag", func(e) {me._onChargeInputChange(e);});
        me._cLevel.addEventListener("drag", func(e) {me._onChargeInputChange(e);});
        me._cFrameV.addEventListener("wheel", func(e) {me._onChargeInputChange(e);});
        me._cLevel.addEventListener("wheel", func(e) {me._onChargeInputChange(e);});
    },

    init: func(instance=me) {
        me.setListeners(instance);
    },

    deinit: func() {
        me.removeListeners();
    },

    _onChargeLevelChange: func() {
        me._fraction = followme.circuit_1.parallelConnection[0].units[0].getRemainingPercentageFloat();
        
        me._cDataLevel.setText(sprintf("%3d", me._fraction)~" %");
        me._cDataAbs.setText(sprintf("%3.1f", me._fraction*m._capacity*0.01)~" kWh");

        me._cLevel.set("coord[2]", me._left + (me._width * me._fraction));
    },

    _onChargeInputChange: func(e) {
        var newFraction = 0;
        if(e.type == "wheel") {
            newFraction = me._fraction + (e.deltaY/me._width);
        } else {
            newFraction = me._fraction + (e.deltaX/me._width);
        }
        newFraction = clamp(newFraction, 0.0, 1.0);
        followme.circuit_1.parallelConnection[0].units[0].remaining = newFraction * me._capacity;
    }
};

var BatteryPayloadClass = {
    new: func() {
        var m = {parents:[BatteryPayloadClass]};
        m._nRoot = props.globals.initNode("/e-tron/dialog/config");

        m._name = "Battery and Systems";
        m._title = "Battery and Systems Settings";

        m._listeners = [];
        m._window = nil;
        m._canvas = nil;

        m._isOpen = 0;
        m._isNotInitialized = 1;

        m._widget = {
            Front: nil,
            Rear: nil,
            Pilot: nil,
            Copilot: nil,
            Baggage: nil,
            weight: nil,
        };

        return m;
    },

    toggle: func() {
        if(me._window != nil) {
            if (me._window._isOpen) {
                me.close();
            } else {
                me.open();
            }
        } else {
            me.open();
        }
    },

    close: func() {
        me._window.del();
        me._window = nil;
    },

    removeListeners: func() {
        foreach(l; me._listeners) {
            removelistener(l);
        }
        me._listeners = [];
    },

    setListeners: func(instance) {},

    _onClose: func() {
        me.removeListeners();
        me._window.del();

        foreach(widget; keys(me._widget)) {
            if(me._widget[widget] != nil) {
                me._widget[widget].deinit();
                me._widget[widget] = nil;
            }
        }
    },

    open: func() {
        if(getprop("/gear/gear[1]/wow") == 1) {
            me.openBAP();
        } else {
            screen.log.write("Battery and payload dialog not available in air!");
        }
    },

    openBAP: func() {
        me._window = canvas.Window.new([1024, 512], "dialog");
        me._window.setTitle("Followme EV Config");
        me._window.setPosition(100, 100);

        # Set up listener for window closure
        me._window.addEventListener("del", func batteryPayload._onClose());

        # Set up window decorations
        me._window.set("decoration-border", "25 1 1");
        me._window.set("shadow-inset", 7); # Calculated as int((1 - math.cos(45 * D2R)) * 9 + 0.5)
        me._window.set("shadow-radius", 5);

        var canvas_deco = me._window.getCanvasDecoration();
        canvas_deco.addEventListener("mousedown", func me._window.raise());
        canvas_deco.set("blend-source-rgb", "src-alpha");
        canvas_deco.set("blend-destination-rgb", "one-minus-src-alpha");
        canvas_deco.set("blend-source-alpha", "one");
        canvas_deco.set("blend-destination-alpha", "one");

        # Create main canvas
        me._canvas = me._window.createCanvas();
        me._canvas.set("background", "#c5c5c5ff");

        me._group = me._canvas.createGroup();

        canvas.parsesvg(me._group, "Aircraft/followme_e-tron/gui/dialogs/config.svg", {"font-mapper": font_mapper});

        me._widget.Front = BatteryWidget.new(me, me._group, "Front");
    }
};

var batteryPayload = BatteryPayloadClass.new();

gui.menuBind("fuel-and-payload", "dialogs.batteryPayload.toggle();");
