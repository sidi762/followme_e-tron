
#Font Mapper
var font_mapper = func(family, weight) {
	return "Orbitron/Orbitron-Bold.ttf";
};



var clamp = func(value,min=0.0,max=0.0){
	if(value < min) {value = min;}
	if(value > max) {value = max;}
	return value;
}

var MyWindow = {
  # Constructor
  #
  # @param size ([width, height])
  new: func(size, type = nil, id = nil)
  {
    var ghost = canvas._newWindowGhost(id);
    var m = {
      parents: [MyWindow, canvas.PropertyElement, ghost],
      _node: props.wrapNode(ghost._node_ghost)
    };

    m.setInt("size[0]", size[0]);
    m.setInt("size[1]", size[1]);

    # TODO better default position
    m.move(0,0);

    # arg = [child, listener_node, mode, is_child_event]
    setlistener(m._node, func m._propCallback(arg[0], arg[2]), 0, 2);
    if( type )
      m.set("type", type);

    m._isOpen = 1;
    return m;
  },
  # Destructor
  del: func
  {
    me._node.remove();
    me._node = nil;

    if( me["_canvas"] != nil )
    {
      me._canvas.del();
      me._canvas = nil;
    }
     me._isOpen = 0;
  },
  # Create the canvas to be used for this Window
  #
  # @return The new canvas
  createCanvas: func()
  {
    var size = [
      me.get("size[0]"),
      me.get("size[1]")
    ];

    me._canvas = canvas.new({
      size: [2 * size[0], 2 * size[1]],
      view: size,
      placement: {
        type: "window",
        id: me.get("id")
      }
    });

    me._canvas.addEventListener("mousedown", func me.raise());
    return me._canvas;
  },
  # Set an existing canvas to be used for this Window
  setCanvas: func(canvas_)
  {
    if( !isa(canvas_, canvas.Canvas) )
      return debug.warn("Not a canvas.Canvas");

    canvas_.addPlacement({type: "window", index: me._node.getIndex()});
    me['_canvas'] = canvas_;
  },
  # Get the displayed canvas
  getCanvas: func()
  {
    return me['_canvas'];
  },
  getCanvasDecoration: func()
  {
    return canvas.wrapCanvas(me._getCanvasDecoration());
  },
  setPosition: func(x, y)
  {
    me.setInt("tf/t[0]", x);
    me.setInt("tf/t[1]", y);
  },
  move: func(x, y)
  {
    me.setInt("tf/t[0]", me.get("tf/t[0]", 10) + x);
    me.setInt("tf/t[1]", me.get("tf/t[1]", 30) + y);
  },
  # Raise to top of window stack
  raise: func()
  {
    # on writing the z-index the window always is moved to the top of all other
    # windows with the same z-index.
    me.setInt("z-index", me.get("z-index", 0));
  },
# private:
  _propCallback: func(child, mode)
  {
    if( !me._node.equals(child.getParent()) )
      return;
    var name = child.getName();

    # support for CSS like position: absolute; with right and/or bottom margin
    if( name == "right" )
      me._handlePositionAbsolute(child, mode, name, 0);
    else if( name == "bottom" )
      me._handlePositionAbsolute(child, mode, name, 1);

    # update decoration on type change
    else if( name == "type" )
    {
      if( mode == 0 )
        settimer(func me._updateDecoration(), 0);
    }
  },
  _handlePositionAbsolute: func(child, mode, name, index)
  {
    # mode
    #   -1 child removed
    #    0 value changed
    #    1 child added

    if( mode == 0 )
      me._updatePos(index, name);
    else if( mode == 1 )
      me["_listener_" ~ name] = [
        setlistener
        (
          "/sim/gui/canvas/size[" ~ index ~ "]",
          func me._updatePos(index, name)
        ),
        setlistener
        (
          me._node.getNode("size[" ~ index ~ "]"),
          func me._updatePos(index, name)
        )
      ];
    else if( mode == -1 )
      for(var i = 0; i < 2; i += 1)
        removelistener(me["_listener_" ~ name][i]);
  },
  _updatePos: func(index, name)
  {
    me.setInt
    (
      "tf/t[" ~ index ~ "]",
      getprop("/sim/gui/canvas/size[" ~ index ~ "]")
      - me.get(name)
      - me.get("size[" ~ index ~ "]")
    );
  },
  _onClose : func(){
	me.del();
  },
  _updateDecoration: func()
  {
    var border_radius = 9;
    me.set("decoration-border", "25 1 1");
    me.set("shadow-inset", int((1 - math.cos(45 * D2R)) * border_radius + 0.5));
    me.set("shadow-radius", 5);
    me.setBool("update", 1);

    var canvas_deco = me.getCanvasDecoration();
    canvas_deco.addEventListener("mousedown", func me.raise());
    canvas_deco.set("blend-source-rgb", "src-alpha");
    canvas_deco.set("blend-destination-rgb", "one-minus-src-alpha");
    canvas_deco.set("blend-source-alpha", "one");
    canvas_deco.set("blend-destination-alpha", "one");

    var group_deco = canvas_deco.getGroup("decoration");
    var title_bar = group_deco.createChild("group", "title_bar");
    title_bar
      .rect( 0, 0,
             me.get("size[0]"),
             me.get("size[1]"), #25,
             {"border-top-radius": border_radius} )
      .setColorFill(0.25,0.24,0.22)
      .setStrokeLineWidth(0);

    var style_dir = "gui/styles/AmbianceClassic/decoration/";

    # close icon
    var x = 10;
    var y = 3;
    var w = 19;
    var h = 19;
    var ico = title_bar.createChild("image", "icon-close")
                       .set("file", style_dir ~ "close_focused_normal.png")
                       .setTranslation(x,y);
    ico.addEventListener("click", func me._onClose());
    ico.addEventListener("mouseover", func ico.set("file", style_dir ~ "close_focused_prelight.png"));
    ico.addEventListener("mousedown", func ico.set("file", style_dir ~ "close_focused_pressed.png"));
    ico.addEventListener("mouseout",  func ico.set("file", style_dir ~ "close_focused_normal.png"));

    # title
    me._title = title_bar.createChild("text", "title")
                         .set("alignment", "left-center")
                         .set("character-size", 14)
                         .set("font", "Orbitron/Orbitron-Bold.ttf")
                         .setTranslation( int(x + 1.5 * w + 0.5),
                                          int(y + 0.5 * h + 0.5) );

    var title = me.get("title", "Canvas Dialog");
    me._node.getNode("title", 1).alias(me._title._node.getPath() ~ "/text");
    me.set("title", title);

    title_bar.addEventListener("drag", func(e) {
      if( !ico.equals(e.target) )
        me.move(e.deltaX, e.deltaY);
    });
  }
};

var COLOR = {};
COLOR["Red"] 			= "rgb(244,28,33)";
COLOR["Black"] 			= "#000000";


var SvgWidget = {
	new: func(dialog,canvasGroup,name){
		var m = {parents:[SvgWidget]};
		m._class = "SvgWidget";
		m._dialog 	= dialog;
		m._listeners 	= [];
		m._name 	= name;
		m._group	= canvasGroup;
		return m;
	},
	removeListeners  :func(){
		foreach(l;me._listeners){
			removelistener(l);
		}
		me._listeners = [];
	},
	setListeners : func(instance) {
		
	},
	init : func(instance=me){
		
	},
	deinit : func(){
		me.removeListeners();	
	},
	
};

var BatteryWidget = {
	new: func(dialog,canvasGroup,name){
		var m = {parents:[BatteryWidget,SvgWidget.new(dialog,canvasGroup,name)]};
		m._class = "BatteryWidget";
		m._name		= name;
		
		#//if(m._name=="Front"){
		#//	m._nLevelPct 	= props.globals.initNode("/systems/electrical/battery-charge-percent-front",0.0,"DOUBLE");
		#//}else{
		#//	m._nLevelPct 	= props.globals.initNode("/systems/electrical/battery-charge-percent-back",0.0,"DOUBLE");
		#//}
		m._nLevelPct 	= props.getNode("/systems/electrical/e-tron/battery-remaining-percent");
        
        
		m._fraction	= followme.circuit_1.parallelConnection[0].units[0].getRemainingPercentageFloat();
		m._capacity	= 80; #80 kWh (per pack)
			
		m._cFrame 	= m._group.getElementById(m._name~"_Frame");
		m._cFrameV 	= m._group.getElementById(m._name~"_Frame_Vis");
		m._cLevel 	= m._group.getElementById(m._name~"_Charge_Level");
		m._cDataLevel 	= m._group.getElementById(m._name~"_Data_Level");
		m._cDataAbs 	= m._group.getElementById(m._name~"_Data_Abs");
				
		m._cDataLevel.setText(sprintf("%3d",m._fraction)~" %");
		m._cDataAbs.setText(sprintf("%3.1f",m._fraction*m._capacity*0.01)~" kWh");
		
		m._left		= m._cFrame.get("coord[0]");
		m._right	= m._cFrame.get("coord[2]");
		m._width	= m._right - m._left;
		return m;
	},
	setListeners : func(instance) {
		append(me._listeners, setlistener(me._nLevelPct,func(){me._onChargeLevelChange();},1,0) );
		
		me._cFrameV.addEventListener("drag",func(e){me._onChargeInputChange(e);});
		me._cLevel.addEventListener("drag",func(e){me._onChargeInputChange(e);});
		me._cFrameV.addEventListener("wheel",func(e){me._onChargeInputChange(e);});
		me._cLevel.addEventListener("wheel",func(e){me._onChargeInputChange(e);});
	},
	init : func(instance=me){
		me.setListeners(instance);
	},
	deinit : func(){
		me.removeListeners();	
	},
	_onChargeLevelChange : func(){
		me._fraction	= followme.circuit_1.parallelConnection[0].units[0].getRemainingPercentageFloat();
        
		me._cDataLevel.setText(sprintf("%3d",me._fraction)~" %");
		me._cDataAbs.setText(sprintf("%3.1f",me._fraction*me._capacity*0.01)~" kWh");
		
		me._cLevel.set("coord[2]", me._left + (me._width * me._fraction));
			
	},
	_onChargeInputChange : func(e){
		var newFraction = 0;
		if(e.type == "wheel"){
			newFraction = me._fraction + (e.deltaY/me._width);
		}else{
			newFraction = me._fraction + (e.deltaX/me._width);
		}
		newFraction = clamp(newFraction,0.0,1.0);
		followme.circuit_1.parallelConnection[0].units[0].remaining = newFraction * m._capacity;
		
	},
};


var BatteryPayloadClass = {
	new : func(){
		var m = {parents:[BatteryPayloadClass]};
		m._nRoot 	= props.globals.initNode("/e-tron/dialog/config");
		
		m._name  = "Battery and Systems";
		m._title = "Battery and Systems Settings";
		
		
		m._listeners = [];
		m._dlg 		= nil;
		m._canvas 	= nil;
		
		m._isOpen = 0;
		m._isNotInitialized = 1;
		
		m._widget = {
			Front	 	: nil,
			Rear	 	: nil,
			Pilot	 	: nil,
			Copilot		: nil,
			Baggage	 	: nil,
			weight	 	: nil,
		};
		

		return m;
	},
	toggle : func(){
		if(me._dlg != nil){
			if (me._dlg._isOpen){
				me.close();
			}else{
				me.open();	
			}
		}else{
			me.open();
		}
	},
	close : func(){
		me._dlg.del();
		me._dlg = nil;
	},
	removeListeners  :func(){
		foreach(l;me._listeners){
			removelistener(l);
		}
		me._listeners = [];
	},
	setListeners : func(instance) {
	
		
	},
	_onClose : func(){
		me.removeListeners();
		me._dlg.del();
		
		foreach(widget;keys(me._widget)){
			if(me._widget[widget] != nil){
				me._widget[widget].deinit();
				me._widget[widget] = nil;
			}
		}
		
	},
	open : func(){
		if(getprop("/gear/gear[1]/wow") == 1){
			me.openBAP();
		}else{
			screen.log.write("Battery and payload dialog not available in air!");
		}
		
	},
	openBAP : func(){
		
		
		me._dlg = MyWindow.new([1024, 512], "dialog");
		me._dlg._onClose = func(){
			batteryPayload._onClose();
		}
		me._dlg.set("title", "Followme EV Config");
		me._dlg.move(100,100);
		
		
		me._canvas = me._dlg.createCanvas();
		me._canvas.set("background", "#c5c5c5ff");
		
		me._group = me._canvas.createGroup();

		canvas.parsesvg(me._group, "Aircraft/followme_e-tron/gui/dialogs/config.svg",{"font-mapper": font_mapper});
		
		
		me._widget.Front = BatteryWidget.new(me,me._group,"Front");


		
		
	},
	_onNotifyChange : func(n){

	},
	
};

var batteryPayload = BatteryPayloadClass.new();

gui.menuBind("fuel-and-payload", "dialogs.batteryPayload.toggle();");

