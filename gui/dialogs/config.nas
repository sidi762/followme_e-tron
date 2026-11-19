#Font Mapper
var font_mapper = func(family, weight) {
    return "Orbitron/Orbitron-Bold.ttf";
};

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
        
        m._battery = followme.cSource;
        m._energy = props.getNode("/systems/electrical/e-tron/battery-kWh");

        m._cFrameV = m._group.getElementById(m._name~"_Frame_Vis");
        m._cLevel = m._group.getElementById(m._name~"_Charge_Level");
        m._cDataLevel = m._group.getElementById(m._name~"_Data_Level");
        m._cDataAbs = m._group.getElementById(m._name~"_Data_Abs");

        m._left = m._cLevel.get("coord[0]");
        m._width = m._cLevel.get("coord[2]") - m._left;
        m.setListeners(m);
        return m;
    },

    setListeners: func(instance) {
        append(me._listeners, setlistener(me._energy, func() {instance._onChargeLevelChange();}, 1, 0));

        me._cFrameV.addEventListener("drag", func(e) {instance._onChargeInputChange(e);});
        me._cLevel.addEventListener("drag", func(e) {instance._onChargeInputChange(e);});
        me._cFrameV.addEventListener("wheel", func(e) {instance._onChargeInputChange(e);});
        me._cLevel.addEventListener("wheel", func(e) {instance._onChargeInputChange(e);});
    },

    deinit: func() {
        me.removeListeners();
    },

    _onChargeLevelChange: func() {
        var percent = me._battery.getRemainingPercentageFloat();
        me._cDataLevel.setText(sprintf("%.0f %%", percent));
        me._cDataAbs.setText(sprintf("%.1f kWh", me._battery.getRemainingInkWh()));
        me._cLevel.set("coord[2]", me._left + me._width * percent / 100);
    },

    _onChargeInputChange: func(e) {
        var delta = e.type == "wheel" ? e.deltaY : e.deltaX;
        me._battery.setRemainingFraction(me._battery.getRemainingPercentageFloat() / 100 + delta / me._width);
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
        if (me._window == nil) me.open();
        else me.close();
    },

    close: func() {
        if (me._window != nil) me._window.del();
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
        me._window = nil;

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

        canvas.parsesvg(me._group, "Aircraft/followme_e-tron/gui/dialogs/config_.svg", {"font-mapper": font_mapper});

        me._widget.Front = BatteryWidget.new(me, me._group, "Front");
    }
};

var batteryPayload = BatteryPayloadClass.new();

gui.menuBind("fuel-and-payload", "dialogs.batteryPayload.toggle();");
